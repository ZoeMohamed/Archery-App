-- =========================================================
-- Fix: preserve KTA validity dates from physical KTA data
-- ---------------------------------------------------------
-- Problem:
--   Existing update_member_status() may overwrite users.kta_valid_until
--   (for members with no verified monthly payment), causing approved KTA
--   correction dates to be lost.
--
-- Goal:
--   1) update_member_status() only updates member_status.
--   2) Backfill users.kta_valid_from/kta_valid_until/member_number from
--      latest approved kta_applications where missing.
--
-- Safe to re-run.
-- =========================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.update_member_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    target_user_id UUID;
    last_payment_date DATE;
    months_overdue INTEGER;
    new_member_status VARCHAR(20);
BEGIN
    IF TG_TABLE_NAME = 'payments' THEN
        target_user_id := NEW.user_id;
    ELSE
        target_user_id := NEW.id;
    END IF;

    IF target_user_id IS NULL THEN
      IF TG_OP = 'DELETE' THEN
        RETURN OLD;
      END IF;
      RETURN NEW;
    END IF;

    -- Process member rows only.
    IF NOT EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.id = target_user_id
        AND 'member' = ANY(COALESCE(u.roles, ARRAY[]::text[]))
    ) THEN
      IF TG_OP = 'DELETE' THEN
        RETURN OLD;
      END IF;
      RETURN NEW;
    END IF;

    SELECT MAX(p.payment_month)
    INTO last_payment_date
    FROM public.payments p
    WHERE p.user_id = target_user_id
      AND p.status = 'verified'
      AND p.payment_type = 'monthly_dues';

    IF last_payment_date IS NULL THEN
      new_member_status := 'inactive';
    ELSE
      months_overdue :=
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, last_payment_date))::INTEGER * 12
        + EXTRACT(MONTH FROM AGE(CURRENT_DATE, last_payment_date))::INTEGER;

      new_member_status := CASE
        WHEN months_overdue <= 1 THEN 'active'
        ELSE 'inactive'
      END;
    END IF;

    -- IMPORTANT: Do NOT touch kta_valid_from/kta_valid_until here.
    UPDATE public.users
    SET member_status = new_member_status
    WHERE id = target_user_id
      AND member_status IS DISTINCT FROM new_member_status;

    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

-- Backfill KTA correction data into users for already-approved applications.
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
  member_number = CASE
    WHEN u.member_number IS NOT NULL AND BTRIM(u.member_number) <> '' THEN u.member_number
    WHEN la.member_number IS NULL THEN u.member_number
    WHEN EXISTS (
      SELECT 1
      FROM public.users other_u
      WHERE other_u.id <> u.id
        AND other_u.member_number = la.member_number
    ) THEN u.member_number
    ELSE la.member_number
  END,
  kta_valid_from = COALESCE(la.kta_valid_from, u.kta_valid_from),
  kta_valid_until = COALESCE(la.kta_valid_until, u.kta_valid_until),
  kta_photo_url = COALESCE(NULLIF(la.kta_photo_url, ''), u.kta_photo_url),
  updated_at = NOW()
FROM latest_approved la
WHERE la.user_id = u.id
  AND (
    u.kta_valid_from IS NULL
    OR u.kta_valid_until IS NULL
    OR u.member_number IS NULL
    OR BTRIM(u.member_number) = ''
  );

COMMIT;
