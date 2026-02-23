-- =========================================================
-- Security hardening migration for app data and storage.
-- Run as privileged role (e.g. project owner/service role).
-- Idempotent and safe to re-run.
-- =========================================================

BEGIN;

-- Helper: check current auth user role from public.users
CREATE OR REPLACE FUNCTION public.current_user_has_any_role(role_names text[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.id = auth.uid()
      AND (
        u.roles && role_names
        OR u.active_role = ANY(role_names)
      )
  );
$$;

REVOKE ALL ON FUNCTION public.current_user_has_any_role(text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_has_any_role(text[]) TO authenticated;

-- Safe public profile lookup (minimal fields only) for class/coach screens
CREATE OR REPLACE FUNCTION public.list_user_public_profiles(user_ids uuid[])
RETURNS TABLE(id uuid, full_name text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.id, u.full_name
  FROM public.users u
  WHERE user_ids IS NULL OR u.id = ANY(user_ids);
$$;

REVOKE ALL ON FUNCTION public.list_user_public_profiles(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_user_public_profiles(uuid[]) TO authenticated;

-- Helper: class enrollment lookup.
-- If enrollment table is not deployed yet, fallback to true for compatibility.
CREATE OR REPLACE FUNCTION public.user_enrolled_in_class(
  p_class_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exists boolean;
BEGIN
  IF p_class_id IS NULL OR p_user_id IS NULL THEN
    RETURN false;
  END IF;

  IF to_regclass('public.training_class_enrollments') IS NULL THEN
    RETURN true;
  END IF;

  EXECUTE
    'SELECT EXISTS (
       SELECT 1
       FROM public.training_class_enrollments e
       WHERE e.class_id = $1
         AND e.user_id = $2
     )'
  INTO v_exists
  USING p_class_id, p_user_id;

  RETURN COALESCE(v_exists, false);
END;
$$;

REVOKE ALL ON FUNCTION public.user_enrolled_in_class(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.user_enrolled_in_class(uuid, uuid) TO authenticated;

-- Helper: can this user manage an attendance session (coach owner/admin/staff).
CREATE OR REPLACE FUNCTION public.can_manage_attendance_session(
  p_session_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_coach_id uuid;
BEGIN
  IF p_session_id IS NULL OR p_user_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT s.coach_id
  INTO v_coach_id
  FROM public.attendance_sessions s
  WHERE s.id = p_session_id
  LIMIT 1;

  IF v_coach_id IS NULL THEN
    RETURN false;
  END IF;

  IF public.current_user_has_any_role(ARRAY['staff', 'admin']) THEN
    RETURN true;
  END IF;

  RETURN v_coach_id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.can_manage_attendance_session(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_attendance_session(uuid, uuid) TO authenticated;

-- Helper: can this user access/read an attendance session.
CREATE OR REPLACE FUNCTION public.can_access_attendance_session(
  p_session_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_session_id IS NULL OR p_user_id IS NULL THEN
    RETURN false;
  END IF;

  IF public.can_manage_attendance_session(p_session_id, p_user_id) THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.attendance_records ar
    WHERE ar.attendance_session_id = p_session_id
      AND ar.user_id = p_user_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.can_access_attendance_session(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_access_attendance_session(uuid, uuid) TO authenticated;

-- Helper: can this user submit attendance to a session.
CREATE OR REPLACE FUNCTION public.can_join_attendance_session(
  p_session_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_class_id uuid;
  v_coach_id uuid;
  v_is_active boolean;
  v_expires_at timestamptz;
BEGIN
  IF p_session_id IS NULL OR p_user_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT s.class_id, s.coach_id, s.is_active, s.expires_at
  INTO v_class_id, v_coach_id, v_is_active, v_expires_at
  FROM public.attendance_sessions s
  WHERE s.id = p_session_id
  LIMIT 1;

  IF v_class_id IS NULL THEN
    RETURN false;
  END IF;

  IF v_is_active IS DISTINCT FROM true THEN
    RETURN false;
  END IF;

  IF v_expires_at IS NOT NULL AND v_expires_at <= NOW() THEN
    RETURN false;
  END IF;

  IF public.current_user_has_any_role(ARRAY['staff', 'admin']) THEN
    RETURN true;
  END IF;

  IF v_coach_id = p_user_id THEN
    RETURN true;
  END IF;

  RETURN public.user_enrolled_in_class(v_class_id, p_user_id);
END;
$$;

REVOKE ALL ON FUNCTION public.can_join_attendance_session(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_join_attendance_session(uuid, uuid) TO authenticated;

-- Secure attendance scan flow to avoid broad table reads by members.
CREATE OR REPLACE FUNCTION public.mark_attendance_by_qr(
  p_qr_token text,
  p_status text DEFAULT 'present'
)
RETURNS TABLE(
  record_id uuid,
  attendance_session_id uuid,
  class_id uuid,
  coach_id uuid,
  user_id uuid,
  status text,
  scanned_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_session_id uuid;
  v_class_id uuid;
  v_coach_id uuid;
  v_status text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_qr_token IS NULL OR btrim(p_qr_token) = '' THEN
    RAISE EXCEPTION 'QR token is required';
  END IF;

  SELECT s.id, s.class_id, s.coach_id
  INTO v_session_id, v_class_id, v_coach_id
  FROM public.attendance_sessions s
  WHERE s.qr_token = p_qr_token
    AND s.is_active = true
    AND (s.expires_at IS NULL OR s.expires_at > NOW())
  ORDER BY s.created_at DESC
  LIMIT 1;

  IF v_session_id IS NULL THEN
    RAISE EXCEPTION 'QR tidak valid atau sudah kadaluarsa.';
  END IF;

  IF NOT (
    public.current_user_has_any_role(ARRAY['staff', 'admin'])
    OR v_coach_id = v_user_id
    OR public.user_enrolled_in_class(v_class_id, v_user_id)
  ) THEN
    RAISE EXCEPTION 'Anda belum terdaftar di kelas ini.';
  END IF;

  v_status := COALESCE(NULLIF(btrim(p_status), ''), 'present');

  INSERT INTO public.attendance_records (
    attendance_session_id,
    user_id,
    status,
    scanned_at
  )
  VALUES (
    v_session_id,
    v_user_id,
    v_status,
    NOW()
  )
  ON CONFLICT ON CONSTRAINT attendance_records_attendance_session_id_user_id_key
  DO UPDATE SET
    status = EXCLUDED.status,
    scanned_at = NOW()
  RETURNING
    attendance_records.id,
    attendance_records.attendance_session_id,
    v_class_id,
    v_coach_id,
    attendance_records.user_id,
    attendance_records.status,
    attendance_records.scanned_at
  INTO
    record_id,
    attendance_session_id,
    class_id,
    coach_id,
    user_id,
    status,
    scanned_at;

  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_attendance_by_qr(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_attendance_by_qr(text, text) TO authenticated;

-- Enable RLS on core tables.
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.training_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.score_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.kta_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.training_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.training_class_enrollments ENABLE ROW LEVEL SECURITY;

-- Base grants for authenticated role (RLS policies still apply).
DO $$
BEGIN
  GRANT USAGE ON SCHEMA public TO authenticated;

  IF to_regclass('public.users') IS NOT NULL THEN
    GRANT SELECT, INSERT ON public.users TO authenticated;
  END IF;

  IF to_regclass('public.training_sessions') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.training_sessions TO authenticated;
  END IF;

  IF to_regclass('public.score_details') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.score_details TO authenticated;
  END IF;

  IF to_regclass('public.payments') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.payments TO authenticated;
  END IF;

  IF to_regclass('public.kta_applications') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.kta_applications TO authenticated;
  END IF;

  IF to_regclass('public.notifications') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
  END IF;

  IF to_regclass('public.training_classes') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.training_classes TO authenticated;
  END IF;

  IF to_regclass('public.attendance_sessions') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.attendance_sessions TO authenticated;
  END IF;

  IF to_regclass('public.attendance_records') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.attendance_records TO authenticated;
  END IF;

  IF to_regclass('public.training_class_enrollments') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.training_class_enrollments TO authenticated;
  END IF;
END $$;

-- Drop any existing policies on targeted tables to prevent permissive leftovers.
DO $$
DECLARE
  p record;
BEGIN
  FOR p IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = ANY (ARRAY[
        'users',
        'training_sessions',
        'score_details',
        'payments',
        'kta_applications',
        'notifications',
        'training_classes',
        'attendance_sessions',
        'attendance_records',
        'training_class_enrollments'
      ])
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON %I.%I',
      p.policyname,
      p.schemaname,
      p.tablename
    );
  END LOOP;
END $$;

-- =============================
-- users
-- =============================
DO $$
BEGIN
  IF to_regclass('public.users') IS NULL THEN
    RETURN;
  END IF;

  CREATE POLICY users_select_self_or_admin
    ON public.users
    FOR SELECT
    TO authenticated
    USING (
      id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['admin'])
    );

  CREATE POLICY users_insert_self
    ON public.users
    FOR INSERT
    TO authenticated
    WITH CHECK (
      id = auth.uid()
      AND (active_role IS NULL OR active_role = 'non_member')
    );

  CREATE POLICY users_update_self_or_admin
    ON public.users
    FOR UPDATE
    TO authenticated
    USING (
      id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['admin'])
    )
    WITH CHECK (
      (id = auth.uid() OR public.current_user_has_any_role(ARRAY['admin']))
      AND (
        active_role IS NULL
        OR active_role = ANY(COALESCE(roles, ARRAY['non_member']::text[]))
      )
    );
END $$;

-- Restrict non-admin role escalation from client updates.
DO $$
BEGIN
  IF to_regclass('public.users') IS NULL THEN
    RETURN;
  END IF;

  REVOKE UPDATE ON public.users FROM authenticated;
  GRANT UPDATE (
    full_name,
    email,
    phone_number,
    birth_date,
    address,
    birth_place,
    active_role,
    kta_photo_url
  ) ON public.users TO authenticated;
END $$;

-- =============================
-- training_sessions
-- =============================
DO $$
BEGIN
  IF to_regclass('public.training_sessions') IS NULL THEN
    RETURN;
  END IF;

  CREATE POLICY training_sessions_select_owner_or_coach_admin
    ON public.training_sessions
    FOR SELECT
    TO authenticated
    USING (
      user_id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['coach', 'admin'])
    );

  CREATE POLICY training_sessions_insert_owner
    ON public.training_sessions
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

  CREATE POLICY training_sessions_update_owner_or_admin
    ON public.training_sessions
    FOR UPDATE
    TO authenticated
    USING (
      user_id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['admin'])
    )
    WITH CHECK (
      user_id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['admin'])
    );

  CREATE POLICY training_sessions_delete_owner_or_admin
    ON public.training_sessions
    FOR DELETE
    TO authenticated
    USING (
      user_id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['admin'])
    );
END $$;

-- =============================
-- score_details
-- =============================
DO $$
BEGIN
  IF to_regclass('public.score_details') IS NULL THEN
    RETURN;
  END IF;

  CREATE POLICY score_details_select_linked_session
    ON public.score_details
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM public.training_sessions ts
        WHERE ts.id = score_details.session_id
          AND (
            ts.user_id = auth.uid()
            OR public.current_user_has_any_role(ARRAY['coach', 'admin'])
          )
      )
    );

  CREATE POLICY score_details_insert_owner_session
    ON public.score_details
    FOR INSERT
    TO authenticated
    WITH CHECK (
      EXISTS (
        SELECT 1
        FROM public.training_sessions ts
        WHERE ts.id = score_details.session_id
          AND ts.user_id = auth.uid()
      )
    );

  CREATE POLICY score_details_delete_owner_or_admin
    ON public.score_details
    FOR DELETE
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM public.training_sessions ts
        WHERE ts.id = score_details.session_id
          AND (
            ts.user_id = auth.uid()
            OR public.current_user_has_any_role(ARRAY['admin'])
          )
      )
    );
END $$;

-- =============================
-- payments
-- =============================
DO $$
BEGIN
  IF to_regclass('public.payments') IS NULL THEN
    RETURN;
  END IF;

  CREATE POLICY payments_select_owner_or_staff_admin
    ON public.payments
    FOR SELECT
    TO authenticated
    USING (
      user_id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['staff', 'admin'])
    );

  CREATE POLICY payments_insert_owner
    ON public.payments
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

  CREATE POLICY payments_update_staff_admin
    ON public.payments
    FOR UPDATE
    TO authenticated
    USING (public.current_user_has_any_role(ARRAY['staff', 'admin']))
    WITH CHECK (public.current_user_has_any_role(ARRAY['staff', 'admin']));
END $$;

-- =============================
-- kta_applications
-- =============================
DO $$
BEGIN
  IF to_regclass('public.kta_applications') IS NULL THEN
    RETURN;
  END IF;

  CREATE POLICY kta_select_owner_or_staff_admin
    ON public.kta_applications
    FOR SELECT
    TO authenticated
    USING (
      user_id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['staff', 'admin'])
    );

  CREATE POLICY kta_insert_owner
    ON public.kta_applications
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

  CREATE POLICY kta_update_staff_admin
    ON public.kta_applications
    FOR UPDATE
    TO authenticated
    USING (public.current_user_has_any_role(ARRAY['staff', 'admin']))
    WITH CHECK (public.current_user_has_any_role(ARRAY['staff', 'admin']));
END $$;

-- =============================
-- notifications
-- =============================
DO $$
BEGIN
  IF to_regclass('public.notifications') IS NULL THEN
    RETURN;
  END IF;

  CREATE POLICY notifications_select_owner_or_global
    ON public.notifications
    FOR SELECT
    TO authenticated
    USING (
      user_id = auth.uid()
      OR user_id IS NULL
      OR public.current_user_has_any_role(ARRAY['staff', 'admin'])
    );
END $$;

-- =============================
-- training_classes
-- =============================
DO $$
BEGIN
  IF to_regclass('public.training_classes') IS NULL THEN
    RETURN;
  END IF;

  CREATE POLICY training_classes_select_authenticated
    ON public.training_classes
    FOR SELECT
    TO authenticated
    USING (true);

  CREATE POLICY training_classes_insert_coach_or_admin
    ON public.training_classes
    FOR INSERT
    TO authenticated
    WITH CHECK (
      public.current_user_has_any_role(ARRAY['admin'])
      OR (
        public.current_user_has_any_role(ARRAY['coach'])
        AND coach_id = auth.uid()
      )
    );

  CREATE POLICY training_classes_update_owner_or_admin
    ON public.training_classes
    FOR UPDATE
    TO authenticated
    USING (
      public.current_user_has_any_role(ARRAY['admin'])
      OR (
        public.current_user_has_any_role(ARRAY['coach'])
        AND coach_id = auth.uid()
      )
    )
    WITH CHECK (
      public.current_user_has_any_role(ARRAY['admin'])
      OR (
        public.current_user_has_any_role(ARRAY['coach'])
        AND coach_id = auth.uid()
      )
    );
END $$;

-- =============================
-- attendance_sessions
-- =============================
DO $$
BEGIN
  IF to_regclass('public.attendance_sessions') IS NULL THEN
    RETURN;
  END IF;

  CREATE POLICY attendance_sessions_select_scoped
    ON public.attendance_sessions
    FOR SELECT
    TO authenticated
    USING (
      public.current_user_has_any_role(ARRAY['staff', 'admin'])
      OR coach_id = auth.uid()
      OR EXISTS (
        SELECT 1
        FROM public.attendance_records ar
        WHERE ar.attendance_session_id = attendance_sessions.id
          AND ar.user_id = auth.uid()
      )
    );

  CREATE POLICY attendance_sessions_insert_coach_or_admin
    ON public.attendance_sessions
    FOR INSERT
    TO authenticated
    WITH CHECK (
      public.current_user_has_any_role(ARRAY['admin'])
      OR (
        public.current_user_has_any_role(ARRAY['coach'])
        AND coach_id = auth.uid()
      )
    );

  CREATE POLICY attendance_sessions_update_owner_or_admin
    ON public.attendance_sessions
    FOR UPDATE
    TO authenticated
    USING (
      public.current_user_has_any_role(ARRAY['admin'])
      OR coach_id = auth.uid()
    )
    WITH CHECK (
      public.current_user_has_any_role(ARRAY['admin'])
      OR coach_id = auth.uid()
    );
END $$;

-- =============================
-- attendance_records
-- =============================
DO $$
BEGIN
  IF to_regclass('public.attendance_records') IS NULL THEN
    RETURN;
  END IF;

  CREATE POLICY attendance_records_select_scoped
    ON public.attendance_records
    FOR SELECT
    TO authenticated
    USING (
      user_id = auth.uid()
      OR public.can_manage_attendance_session(
        attendance_records.attendance_session_id,
        auth.uid()
      )
    );

  CREATE POLICY attendance_records_insert_self
    ON public.attendance_records
    FOR INSERT
    TO authenticated
    WITH CHECK (
      user_id = auth.uid()
      AND public.can_join_attendance_session(
        attendance_records.attendance_session_id,
        auth.uid()
      )
    );

  CREATE POLICY attendance_records_update_self_or_admin
    ON public.attendance_records
    FOR UPDATE
    TO authenticated
    USING (
      user_id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['admin'])
    )
    WITH CHECK (
      user_id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['admin'])
    );
END $$;

-- =============================
-- training_class_enrollments (optional table)
-- =============================
DO $$
BEGIN
  IF to_regclass('public.training_class_enrollments') IS NULL THEN
    RETURN;
  END IF;

  CREATE POLICY enrollments_select_authenticated
    ON public.training_class_enrollments
    FOR SELECT
    TO authenticated
    USING (true);

  CREATE POLICY enrollments_insert_self
    ON public.training_class_enrollments
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

  CREATE POLICY enrollments_delete_self_or_admin
    ON public.training_class_enrollments
    FOR DELETE
    TO authenticated
    USING (
      user_id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['admin'])
    );
END $$;

-- =============================
-- Storage hardening
-- =============================
DO $$
DECLARE
  p record;
BEGIN
  BEGIN
    UPDATE storage.buckets
    SET public = false
    WHERE id IN ('kta_app', 'payment_proofs');
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'Skipping bucket privacy update: insufficient privilege on storage.buckets.';
  END;

  BEGIN
    EXECUTE 'ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY';
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'Skipping storage.objects hardening: must run as table owner (or storage admin role).';
      RETURN;
  END;

  FOR p IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON %I.%I',
      p.policyname,
      p.schemaname,
      p.tablename
    );
  END LOOP;

  EXECUTE $policy$
    CREATE POLICY storage_payment_select
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (
        bucket_id = 'payment_proofs'
        AND (
          public.current_user_has_any_role(ARRAY['staff', 'admin'])
          OR name LIKE ('payments/' || auth.uid()::text || '/%')
        )
      )
  $policy$;

  EXECUTE $policy$
    CREATE POLICY storage_payment_insert
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'payment_proofs'
        AND (
          public.current_user_has_any_role(ARRAY['staff', 'admin'])
          OR name LIKE ('payments/' || auth.uid()::text || '/%')
        )
      )
  $policy$;

  EXECUTE $policy$
    CREATE POLICY storage_payment_update
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (
        bucket_id = 'payment_proofs'
        AND (
          public.current_user_has_any_role(ARRAY['staff', 'admin'])
          OR name LIKE ('payments/' || auth.uid()::text || '/%')
        )
      )
      WITH CHECK (
        bucket_id = 'payment_proofs'
        AND (
          public.current_user_has_any_role(ARRAY['staff', 'admin'])
          OR name LIKE ('payments/' || auth.uid()::text || '/%')
        )
      )
  $policy$;

  EXECUTE $policy$
    CREATE POLICY storage_payment_delete
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'payment_proofs'
        AND (
          public.current_user_has_any_role(ARRAY['staff', 'admin'])
          OR name LIKE ('payments/' || auth.uid()::text || '/%')
        )
      )
  $policy$;

  EXECUTE $policy$
    CREATE POLICY storage_kta_select
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (
        bucket_id = 'kta_app'
        AND (
          public.current_user_has_any_role(ARRAY['staff', 'admin'])
          OR name LIKE ('kta/' || auth.uid()::text || '/%')
        )
      )
  $policy$;

  EXECUTE $policy$
    CREATE POLICY storage_kta_insert
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'kta_app'
        AND (
          public.current_user_has_any_role(ARRAY['staff', 'admin'])
          OR name LIKE ('kta/' || auth.uid()::text || '/%')
        )
      )
  $policy$;

  EXECUTE $policy$
    CREATE POLICY storage_kta_update
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (
        bucket_id = 'kta_app'
        AND (
          public.current_user_has_any_role(ARRAY['staff', 'admin'])
          OR name LIKE ('kta/' || auth.uid()::text || '/%')
        )
      )
      WITH CHECK (
        bucket_id = 'kta_app'
        AND (
          public.current_user_has_any_role(ARRAY['staff', 'admin'])
          OR name LIKE ('kta/' || auth.uid()::text || '/%')
        )
      )
  $policy$;

  EXECUTE $policy$
    CREATE POLICY storage_kta_delete
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'kta_app'
        AND (
          public.current_user_has_any_role(ARRAY['staff', 'admin'])
          OR name LIKE ('kta/' || auth.uid()::text || '/%')
        )
      )
  $policy$;
END $$;

COMMIT;
