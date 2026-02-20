-- =========================================================
-- Storage object policy lockdown for Supabase.
-- Requires owner privilege on storage.objects.
-- =========================================================

BEGIN;

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
      RAISE NOTICE 'Skipping bucket update: insufficient privilege on storage.buckets.';
  END;

  BEGIN
    EXECUTE 'ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY';
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'Skipping storage policy lockdown: must be owner of storage.objects.';
      RETURN;
  END;

  FOR p IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', p.policyname);
  END LOOP;

  EXECUTE $policy$
    CREATE POLICY storage_kta_select
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (
        bucket_id = 'kta_app'
        AND (
          name LIKE ('kta/' || auth.uid()::text || '/%')
          OR EXISTS (
            SELECT 1
            FROM public.users u
            WHERE u.id = auth.uid()
              AND (
                u.active_role IN ('staff', 'admin')
                OR COALESCE(u.roles, ARRAY[]::text[]) && ARRAY['staff', 'admin']::text[]
              )
          )
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
          name LIKE ('kta/' || auth.uid()::text || '/%')
          OR EXISTS (
            SELECT 1
            FROM public.users u
            WHERE u.id = auth.uid()
              AND (
                u.active_role IN ('staff', 'admin')
                OR COALESCE(u.roles, ARRAY[]::text[]) && ARRAY['staff', 'admin']::text[]
              )
          )
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
          name LIKE ('kta/' || auth.uid()::text || '/%')
          OR EXISTS (
            SELECT 1
            FROM public.users u
            WHERE u.id = auth.uid()
              AND (
                u.active_role IN ('staff', 'admin')
                OR COALESCE(u.roles, ARRAY[]::text[]) && ARRAY['staff', 'admin']::text[]
              )
          )
        )
      )
      WITH CHECK (
        bucket_id = 'kta_app'
        AND (
          name LIKE ('kta/' || auth.uid()::text || '/%')
          OR EXISTS (
            SELECT 1
            FROM public.users u
            WHERE u.id = auth.uid()
              AND (
                u.active_role IN ('staff', 'admin')
                OR COALESCE(u.roles, ARRAY[]::text[]) && ARRAY['staff', 'admin']::text[]
              )
          )
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
          name LIKE ('kta/' || auth.uid()::text || '/%')
          OR EXISTS (
            SELECT 1
            FROM public.users u
            WHERE u.id = auth.uid()
              AND (
                u.active_role IN ('staff', 'admin')
                OR COALESCE(u.roles, ARRAY[]::text[]) && ARRAY['staff', 'admin']::text[]
              )
          )
        )
      )
  $policy$;

  EXECUTE $policy$
    CREATE POLICY storage_payment_select
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (
        bucket_id = 'payment_proofs'
        AND (
          name LIKE ('payments/' || auth.uid()::text || '/%')
          OR EXISTS (
            SELECT 1
            FROM public.users u
            WHERE u.id = auth.uid()
              AND (
                u.active_role IN ('staff', 'admin')
                OR COALESCE(u.roles, ARRAY[]::text[]) && ARRAY['staff', 'admin']::text[]
              )
          )
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
          name LIKE ('payments/' || auth.uid()::text || '/%')
          OR EXISTS (
            SELECT 1
            FROM public.users u
            WHERE u.id = auth.uid()
              AND (
                u.active_role IN ('staff', 'admin')
                OR COALESCE(u.roles, ARRAY[]::text[]) && ARRAY['staff', 'admin']::text[]
              )
          )
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
          name LIKE ('payments/' || auth.uid()::text || '/%')
          OR EXISTS (
            SELECT 1
            FROM public.users u
            WHERE u.id = auth.uid()
              AND (
                u.active_role IN ('staff', 'admin')
                OR COALESCE(u.roles, ARRAY[]::text[]) && ARRAY['staff', 'admin']::text[]
              )
          )
        )
      )
      WITH CHECK (
        bucket_id = 'payment_proofs'
        AND (
          name LIKE ('payments/' || auth.uid()::text || '/%')
          OR EXISTS (
            SELECT 1
            FROM public.users u
            WHERE u.id = auth.uid()
              AND (
                u.active_role IN ('staff', 'admin')
                OR COALESCE(u.roles, ARRAY[]::text[]) && ARRAY['staff', 'admin']::text[]
              )
          )
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
          name LIKE ('payments/' || auth.uid()::text || '/%')
          OR EXISTS (
            SELECT 1
            FROM public.users u
            WHERE u.id = auth.uid()
              AND (
                u.active_role IN ('staff', 'admin')
                OR COALESCE(u.roles, ARRAY[]::text[]) && ARRAY['staff', 'admin']::text[]
              )
          )
        )
      )
  $policy$;
END $$;

COMMIT;
