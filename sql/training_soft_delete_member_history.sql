-- =========================================================
-- Soft delete training history for member deletes
-- ---------------------------------------------------------
-- Goal:
-- 1) Member "delete" on training_sessions becomes soft delete.
-- 2) Member can no longer see soft-deleted sessions/details.
-- 3) Coach/Admin can still see soft-deleted sessions/details.
--
-- Safe to re-run.
-- =========================================================

BEGIN;

-- Add soft-delete metadata columns.
ALTER TABLE IF EXISTS public.training_sessions
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_by uuid REFERENCES public.users(id);

CREATE INDEX IF NOT EXISTS idx_training_sessions_deleted_at
  ON public.training_sessions (deleted_at);

CREATE INDEX IF NOT EXISTS idx_training_sessions_user_deleted_at_training_date
  ON public.training_sessions (user_id, deleted_at, training_date DESC);

-- Rebuild RLS for training_sessions with soft-delete visibility rules.
DO $$
BEGIN
  IF to_regclass('public.training_sessions') IS NULL THEN
    RETURN;
  END IF;

  DROP POLICY IF EXISTS training_sessions_select_owner_or_coach_admin ON public.training_sessions;
  DROP POLICY IF EXISTS training_sessions_insert_owner ON public.training_sessions;
  DROP POLICY IF EXISTS training_sessions_update_owner_or_admin ON public.training_sessions;
  DROP POLICY IF EXISTS training_sessions_delete_owner_or_admin ON public.training_sessions;

  CREATE POLICY training_sessions_select_owner_or_coach_admin
    ON public.training_sessions
    FOR SELECT
    TO authenticated
    USING (
      (
        user_id = auth.uid()
        AND deleted_at IS NULL
      )
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
      (
        user_id = auth.uid()
        AND deleted_at IS NULL
      )
      OR public.current_user_has_any_role(ARRAY['admin'])
    )
    WITH CHECK (
      user_id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['admin'])
    );

  -- Keep owner/admin delete permission; owner delete is rewritten to soft delete by RULE below.
  CREATE POLICY training_sessions_delete_owner_or_admin
    ON public.training_sessions
    FOR DELETE
    TO authenticated
    USING (
      user_id = auth.uid()
      OR public.current_user_has_any_role(ARRAY['admin'])
    );
END $$;

-- Rebuild score_details policies so owners cannot read soft-deleted session details.
DO $$
BEGIN
  IF to_regclass('public.score_details') IS NULL THEN
    RETURN;
  END IF;

  DROP POLICY IF EXISTS score_details_select_linked_session ON public.score_details;
  DROP POLICY IF EXISTS score_details_insert_owner_session ON public.score_details;
  DROP POLICY IF EXISTS score_details_delete_owner_or_admin ON public.score_details;

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
            (
              ts.user_id = auth.uid()
              AND ts.deleted_at IS NULL
            )
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
          AND ts.deleted_at IS NULL
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
            (
              ts.user_id = auth.uid()
              AND ts.deleted_at IS NULL
            )
            OR public.current_user_has_any_role(ARRAY['admin'])
          )
      )
    );
END $$;

-- Rewrite DELETE into UPDATE (soft delete) while preserving existing app delete call.
-- Note: RETURNING is not supported on conditional rules, so keep this rule unconditional.
DROP RULE IF EXISTS training_sessions_soft_delete_member ON public.training_sessions;
DROP RULE IF EXISTS training_sessions_soft_delete ON public.training_sessions;

CREATE RULE training_sessions_soft_delete AS
ON DELETE TO public.training_sessions
DO INSTEAD
  UPDATE public.training_sessions AS ts
  SET
    deleted_at = COALESCE(ts.deleted_at, NOW()),
    deleted_by = COALESCE(ts.deleted_by, auth.uid())
  WHERE ts.id = OLD.id
  RETURNING OLD.*;

COMMIT;
