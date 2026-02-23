-- =========================================================
-- KTA correction fields + approval sync to users
-- ---------------------------------------------------------
-- Goal:
-- 1) Simpan hasil koreksi OCR (member_number, valid_from, valid_until)
--    di kta_applications.
-- 2) Saat application di-approve, salin nilai tersebut ke users.
-- 3) Tetap idempotent dan aman dijalankan berulang.
-- =========================================================

BEGIN;

-- 1) Extend kta_applications with correction fields.
ALTER TABLE IF EXISTS public.kta_applications
  ADD COLUMN IF NOT EXISTS member_number VARCHAR(50),
  ADD COLUMN IF NOT EXISTS kta_valid_from DATE,
  ADD COLUMN IF NOT EXISTS kta_valid_until DATE;

-- Normalize empty member number to NULL.
UPDATE public.kta_applications
SET member_number = NULLIF(BTRIM(member_number), '')
WHERE member_number IS NOT NULL;

DO $$
BEGIN
  IF to_regclass('public.kta_applications') IS NULL THEN
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'kta_applications_member_number_format_check'
      AND conrelid = 'public.kta_applications'::regclass
  ) THEN
    ALTER TABLE public.kta_applications
      ADD CONSTRAINT kta_applications_member_number_format_check
      CHECK (
        member_number IS NULL
        OR member_number ~ '^[A-Za-z0-9-]{6,20}$'
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'kta_applications_validity_pair_check'
      AND conrelid = 'public.kta_applications'::regclass
  ) THEN
    ALTER TABLE public.kta_applications
      ADD CONSTRAINT kta_applications_validity_pair_check
      CHECK (
        (kta_valid_from IS NULL AND kta_valid_until IS NULL)
        OR (kta_valid_from IS NOT NULL AND kta_valid_until IS NOT NULL)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'kta_applications_validity_order_check'
      AND conrelid = 'public.kta_applications'::regclass
  ) THEN
    ALTER TABLE public.kta_applications
      ADD CONSTRAINT kta_applications_validity_order_check
      CHECK (
        kta_valid_from IS NULL
        OR kta_valid_until IS NULL
        OR kta_valid_from <= kta_valid_until
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'kta_applications_validity_one_year_check'
      AND conrelid = 'public.kta_applications'::regclass
  ) THEN
    ALTER TABLE public.kta_applications
      ADD CONSTRAINT kta_applications_validity_one_year_check
      CHECK (
        kta_valid_from IS NULL
        OR kta_valid_until IS NULL
        OR kta_valid_from = (kta_valid_until - INTERVAL '1 year')::date
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_kta_applications_member_number
  ON public.kta_applications(member_number);

CREATE INDEX IF NOT EXISTS idx_kta_applications_kta_valid_until
  ON public.kta_applications(kta_valid_until);

-- 2) Approval flow: copy correction fields to users on status=approved.
CREATE OR REPLACE FUNCTION public.handle_kta_approval()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_number TEXT;
  v_valid_from DATE;
  v_valid_until DATE;
BEGIN
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status <> 'approved') THEN
    v_member_number := NULLIF(BTRIM(NEW.member_number), '');
    v_valid_from := NEW.kta_valid_from;
    v_valid_until := NEW.kta_valid_until;

    -- If one date is missing, derive the pair.
    IF v_valid_until IS NOT NULL AND v_valid_from IS NULL THEN
      v_valid_from := (v_valid_until - INTERVAL '1 year')::date;
    ELSIF v_valid_from IS NOT NULL AND v_valid_until IS NULL THEN
      v_valid_until := (v_valid_from + INTERVAL '1 year')::date;
    END IF;

    UPDATE public.users u
    SET
      roles = CASE
        WHEN 'member' = ANY(COALESCE(u.roles, ARRAY[]::text[])) THEN COALESCE(u.roles, ARRAY['member']::text[])
        ELSE array_append(COALESCE(u.roles, ARRAY[]::text[]), 'member')
      END,
      active_role = CASE
        WHEN u.active_role IS NULL OR u.active_role = 'non_member' THEN 'member'
        ELSE u.active_role
      END,
      member_number = CASE
        WHEN v_member_number IS NULL THEN u.member_number
        WHEN EXISTS (
          SELECT 1
          FROM public.users other_u
          WHERE other_u.id <> u.id
            AND other_u.member_number = v_member_number
        ) THEN u.member_number
        ELSE v_member_number
      END,
      member_status = COALESCE(u.member_status, 'inactive'),
      kta_photo_url = COALESCE(NULLIF(NEW.kta_photo_url, ''), u.kta_photo_url),
      kta_issued_date = COALESCE(u.kta_issued_date, CURRENT_DATE),
      kta_valid_from = COALESCE(v_valid_from, u.kta_valid_from),
      kta_valid_until = COALESCE(v_valid_until, u.kta_valid_until),
      updated_at = NOW()
    WHERE u.id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS auto_grant_member_role ON public.kta_applications;
CREATE TRIGGER auto_grant_member_role
AFTER UPDATE ON public.kta_applications
FOR EACH ROW
WHEN (NEW.status = 'approved')
EXECUTE FUNCTION public.handle_kta_approval();

-- 3) Optional backfill for already approved applications.
WITH latest_approved AS (
  SELECT DISTINCT ON (ka.user_id)
    ka.user_id,
    NULLIF(BTRIM(ka.member_number), '') AS member_number,
    ka.kta_valid_from,
    ka.kta_valid_until,
    ka.kta_photo_url
  FROM public.kta_applications ka
  WHERE ka.status = 'approved'
  ORDER BY
    ka.user_id,
    COALESCE(ka.processed_at, ka.updated_at, ka.created_at) DESC
)
UPDATE public.users u
SET
  roles = CASE
    WHEN 'member' = ANY(COALESCE(u.roles, ARRAY[]::text[])) THEN COALESCE(u.roles, ARRAY['member']::text[])
    ELSE array_append(COALESCE(u.roles, ARRAY[]::text[]), 'member')
  END,
  active_role = CASE
    WHEN u.active_role IS NULL OR u.active_role = 'non_member' THEN 'member'
    ELSE u.active_role
  END,
  member_number = CASE
    WHEN la.member_number IS NULL THEN u.member_number
    WHEN EXISTS (
      SELECT 1
      FROM public.users other_u
      WHERE other_u.id <> u.id
        AND other_u.member_number = la.member_number
    ) THEN u.member_number
    ELSE la.member_number
  END,
  kta_photo_url = COALESCE(NULLIF(la.kta_photo_url, ''), u.kta_photo_url),
  kta_issued_date = COALESCE(u.kta_issued_date, CURRENT_DATE),
  kta_valid_from = COALESCE(la.kta_valid_from, u.kta_valid_from),
  kta_valid_until = COALESCE(la.kta_valid_until, u.kta_valid_until),
  member_status = COALESCE(u.member_status, 'inactive'),
  updated_at = NOW()
FROM latest_approved la
WHERE la.user_id = u.id;

COMMIT;
