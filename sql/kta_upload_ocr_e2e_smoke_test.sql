-- =========================================================
-- KTA OCR upload smoke test (safe, no permanent data)
-- ---------------------------------------------------------
-- Tujuan:
-- 1) Verifikasi kolom koreksi OCR tersedia di kta_applications.
-- 2) Verifikasi insert payload upload KTA dari app dapat masuk.
-- 3) Tidak menyisakan data karena diakhiri ROLLBACK.
-- =========================================================

BEGIN;

DO $$
DECLARE
  v_user_id uuid;
  v_app_id uuid := uuid_generate_v4();
  v_member_number text := '811107299';
  v_valid_until date := DATE '2026-06-30';
  v_valid_from date := DATE '2025-06-30';
  v_row record;
BEGIN
  -- Preflight: kolom wajib OCR.
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'kta_applications'
      AND column_name = 'member_number'
  ) THEN
    RAISE EXCEPTION 'Missing column public.kta_applications.member_number. Run sql/kta_application_corrections_and_approval_sync.sql first.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'kta_applications'
      AND column_name = 'kta_valid_from'
  ) THEN
    RAISE EXCEPTION 'Missing column public.kta_applications.kta_valid_from. Run sql/kta_application_corrections_and_approval_sync.sql first.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'kta_applications'
      AND column_name = 'kta_valid_until'
  ) THEN
    RAISE EXCEPTION 'Missing column public.kta_applications.kta_valid_until. Run sql/kta_application_corrections_and_approval_sync.sql first.';
  END IF;

  -- Ambil 1 user existing untuk test FK kta_applications.user_id -> users.id.
  SELECT u.id
  INTO v_user_id
  FROM public.users u
  ORDER BY u.created_at DESC NULLS LAST
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No users found in public.users. Create at least 1 user profile first.';
  END IF;

  -- Simulasikan payload upload dari app (status pending).
  INSERT INTO public.kta_applications (
    id,
    user_id,
    confirmed_name,
    confirmed_birth_place,
    confirmed_birth_date,
    confirmed_address,
    kta_photo_url,
    status,
    member_number,
    kta_valid_from,
    kta_valid_until
  )
  VALUES (
    v_app_id,
    v_user_id,
    'Smoke Test OCR',
    'Jakarta',
    DATE '2000-01-01',
    'Alamat smoke test',
    'kta/' || v_user_id::text || '/smoke-test.jpg',
    'pending',
    v_member_number,
    v_valid_from,
    v_valid_until
  );

  SELECT
    ka.user_id,
    ka.status,
    ka.member_number,
    ka.kta_valid_from,
    ka.kta_valid_until
  INTO v_row
  FROM public.kta_applications ka
  WHERE ka.id = v_app_id;

  IF v_row.user_id IS DISTINCT FROM v_user_id THEN
    RAISE EXCEPTION 'E2E failed: user_id mismatch.';
  END IF;

  IF v_row.status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'E2E failed: status mismatch (expected pending).';
  END IF;

  IF v_row.member_number IS DISTINCT FROM v_member_number THEN
    RAISE EXCEPTION 'E2E failed: member_number mismatch.';
  END IF;

  IF v_row.kta_valid_from IS DISTINCT FROM v_valid_from THEN
    RAISE EXCEPTION 'E2E failed: kta_valid_from mismatch.';
  END IF;

  IF v_row.kta_valid_until IS DISTINCT FROM v_valid_until THEN
    RAISE EXCEPTION 'E2E failed: kta_valid_until mismatch.';
  END IF;

  RAISE NOTICE 'KTA OCR upload smoke test passed. user_id=%, app_id=%', v_user_id, v_app_id;
END $$;

-- Tidak menyisakan data test.
ROLLBACK;
