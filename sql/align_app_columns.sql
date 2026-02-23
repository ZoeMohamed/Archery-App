-- =========================================================
-- ALIGN DATABASE SCHEMA WITH FLUTTER APP COLUMNS
-- ---------------------------------------------------------
-- Menambahkan kolom yang sudah digunakan di app (model Dart)
-- tapi belum ada di schema V4.
--
-- Safe to re-run (idempotent via IF NOT EXISTS).
-- =========================================================

BEGIN;

-- =========================================================
-- 1. training_sessions — 4 kolom tambahan
-- ---------------------------------------------------------
-- Digunakan oleh:
--   - lib/models/supabase/db_training_session.dart
--   - lib/adapters/supabase_training_adapter.dart
--   - lib/services/supabase_training_service.dart
-- =========================================================

-- 1a. target_face_type — tipe bantalan target (e.g. 'Face Ring 6', 'Ring Puta', 'Face Mega Mendung')
--     Lebih spesifik dari target_type yang hanya 'bullet'/'animal'.
ALTER TABLE public.training_sessions
  ADD COLUMN IF NOT EXISTS target_face_type VARCHAR(50);

-- 1b. input_method — metode input skor ('arrow_values' atau 'target_face')
ALTER TABLE public.training_sessions
  ADD COLUMN IF NOT EXISTS input_method VARCHAR(30) NOT NULL DEFAULT 'arrow_values';

-- 1c. training_name — nama/label sesi latihan (opsional)
ALTER TABLE public.training_sessions
  ADD COLUMN IF NOT EXISTS training_name VARCHAR(255);

-- 1d. number_of_players — jumlah pemain dalam sesi
ALTER TABLE public.training_sessions
  ADD COLUMN IF NOT EXISTS number_of_players INTEGER;


-- =========================================================
-- 2. score_details — 2 kolom koordinat hit
-- ---------------------------------------------------------
-- Digunakan oleh:
--   - lib/models/supabase/db_score_detail.dart
--   - lib/adapters/supabase_training_adapter.dart
--     (untuk target_face input: posisi x,y tembakan pada target)
-- =========================================================

-- 2a. hit_x — koordinat X posisi tembakan (normalized -1.0 to 1.0)
ALTER TABLE public.score_details
  ADD COLUMN IF NOT EXISTS hit_x DOUBLE PRECISION;

-- 2b. hit_y — koordinat Y posisi tembakan (normalized -1.0 to 1.0)
ALTER TABLE public.score_details
  ADD COLUMN IF NOT EXISTS hit_y DOUBLE PRECISION;


-- =========================================================
-- 3. Verifikasi: kta_applications correction columns
-- ---------------------------------------------------------
-- Kolom ini seharusnya sudah ada dari migration
-- kta_application_corrections_and_approval_sync.sql.
-- Ditambahkan IF NOT EXISTS sebagai safety net.
-- =========================================================

ALTER TABLE public.kta_applications
  ADD COLUMN IF NOT EXISTS member_number VARCHAR(50);

ALTER TABLE public.kta_applications
  ADD COLUMN IF NOT EXISTS kta_valid_from DATE;

ALTER TABLE public.kta_applications
  ADD COLUMN IF NOT EXISTS kta_valid_until DATE;


COMMIT;


-- =========================================================
-- VERIFIKASI: Cek semua kolom sudah ada
-- =========================================================

DO $$
DECLARE
  missing TEXT := '';
BEGIN
  -- training_sessions checks
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'training_sessions'
      AND column_name = 'target_face_type'
  ) THEN missing := missing || E'\n  - training_sessions.target_face_type';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'training_sessions'
      AND column_name = 'input_method'
  ) THEN missing := missing || E'\n  - training_sessions.input_method';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'training_sessions'
      AND column_name = 'training_name'
  ) THEN missing := missing || E'\n  - training_sessions.training_name';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'training_sessions'
      AND column_name = 'number_of_players'
  ) THEN missing := missing || E'\n  - training_sessions.number_of_players';
  END IF;

  -- score_details checks
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'score_details'
      AND column_name = 'hit_x'
  ) THEN missing := missing || E'\n  - score_details.hit_x';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'score_details'
      AND column_name = 'hit_y'
  ) THEN missing := missing || E'\n  - score_details.hit_y';
  END IF;

  -- kta_applications checks
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'kta_applications'
      AND column_name = 'member_number'
  ) THEN missing := missing || E'\n  - kta_applications.member_number';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'kta_applications'
      AND column_name = 'kta_valid_from'
  ) THEN missing := missing || E'\n  - kta_applications.kta_valid_from';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'kta_applications'
      AND column_name = 'kta_valid_until'
  ) THEN missing := missing || E'\n  - kta_applications.kta_valid_until';
  END IF;

  -- Report
  IF missing = '' THEN
    RAISE NOTICE E'\n══════════════════════════════════════════';
    RAISE NOTICE '✅ ALL 9 COLUMNS VERIFIED SUCCESSFULLY!';
    RAISE NOTICE E'══════════════════════════════════════════\n';
    RAISE NOTICE 'training_sessions:';
    RAISE NOTICE '  ✅ target_face_type  VARCHAR(50)';
    RAISE NOTICE '  ✅ input_method      VARCHAR(30) DEFAULT ''arrow_values''';
    RAISE NOTICE '  ✅ training_name     VARCHAR(255)';
    RAISE NOTICE '  ✅ number_of_players INTEGER';
    RAISE NOTICE '';
    RAISE NOTICE 'score_details:';
    RAISE NOTICE '  ✅ hit_x             DOUBLE PRECISION';
    RAISE NOTICE '  ✅ hit_y             DOUBLE PRECISION';
    RAISE NOTICE '';
    RAISE NOTICE 'kta_applications:';
    RAISE NOTICE '  ✅ member_number     VARCHAR(50)';
    RAISE NOTICE '  ✅ kta_valid_from    DATE';
    RAISE NOTICE '  ✅ kta_valid_until   DATE';
  ELSE
    RAISE WARNING E'\n⚠️  MISSING COLUMNS:%', missing;
  END IF;
END $$;
