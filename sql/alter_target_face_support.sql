-- ============================================
-- Migration: Support target-face data in Supabase
-- Safe to run multiple times (idempotent)
-- ============================================

BEGIN;

-- training_sessions compatibility with latest app payload
ALTER TABLE public.training_sessions
  ADD COLUMN IF NOT EXISTS training_name VARCHAR(255),
  ADD COLUMN IF NOT EXISTS number_of_players INTEGER,
  ADD COLUMN IF NOT EXISTS input_method VARCHAR(20),
  ADD COLUMN IF NOT EXISTS target_face_type VARCHAR(50);

UPDATE public.training_sessions
SET number_of_players = CASE
  WHEN mode = 'individual' THEN 1
  WHEN jsonb_typeof(group_members) = 'array' AND jsonb_array_length(group_members) > 0
    THEN jsonb_array_length(group_members)
  ELSE 1
END
WHERE number_of_players IS NULL;

UPDATE public.training_sessions
SET input_method = 'arrow_values'
WHERE input_method IS NULL OR btrim(input_method) = '';

-- Do not hard-backfill target_face_type for legacy rows.
-- Legacy rows are inferred in app from hit coordinates to avoid wrong assumptions.

ALTER TABLE public.training_sessions
  ALTER COLUMN number_of_players SET DEFAULT 1,
  ALTER COLUMN input_method SET DEFAULT 'arrow_values',
  ALTER COLUMN input_method SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname = 'training_sessions'
      AND c.conname = 'training_sessions_input_method_check'
  ) THEN
    ALTER TABLE public.training_sessions
      ADD CONSTRAINT training_sessions_input_method_check
      CHECK (input_method IN ('arrow_values', 'target_face'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname = 'training_sessions'
      AND c.conname = 'training_sessions_number_of_players_check'
  ) THEN
    ALTER TABLE public.training_sessions
      ADD CONSTRAINT training_sessions_number_of_players_check
      CHECK (number_of_players > 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname = 'training_sessions'
      AND c.conname = 'training_sessions_target_face_type_check'
  ) THEN
    ALTER TABLE public.training_sessions
      ADD CONSTRAINT training_sessions_target_face_type_check
      CHECK (
        target_face_type IS NULL OR
        target_face_type IN (
          'Default',
          'Face Ring 6',
          'Ring Puta',
          'Face Mega Mendung',
          'Target Animal'
        )
      );
  END IF;
END $$;

-- score_details: add target-face hit coordinates
ALTER TABLE public.score_details
  ADD COLUMN IF NOT EXISTS hit_x DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS hit_y DOUBLE PRECISION;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname = 'score_details'
      AND c.conname = 'score_details_hit_pair_check'
  ) THEN
    ALTER TABLE public.score_details
      ADD CONSTRAINT score_details_hit_pair_check
      CHECK (
        (hit_x IS NULL AND hit_y IS NULL) OR
        (hit_x IS NOT NULL AND hit_y IS NOT NULL)
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_score_details_session_end_arrow
  ON public.score_details(session_id, end_number, arrow_number);

COMMIT;
