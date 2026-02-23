-- =========================================================
-- Enable "pengurus" role to manage payment data (read/update)
-- Safe to re-run.
-- =========================================================

BEGIN;

ALTER TABLE IF EXISTS public.payments ENABLE ROW LEVEL SECURITY;

-- Reset payment policies so behavior is predictable.
DO $$
DECLARE
  p record;
BEGIN
  IF to_regclass('public.payments') IS NULL THEN
    RETURN;
  END IF;

  FOR p IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'payments'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.payments', p.policyname);
  END LOOP;
END $$;

-- Member can see own payment rows.
CREATE POLICY payments_select_owner_or_management
  ON public.payments
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.current_user_has_any_role(ARRAY['admin', 'staff', 'pengurus'])
  );

-- Member can submit own payment rows.
CREATE POLICY payments_insert_owner
  ON public.payments
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Pengurus/staff/admin can verify/reject and update payment rows.
CREATE POLICY payments_update_management
  ON public.payments
  FOR UPDATE
  TO authenticated
  USING (
    public.current_user_has_any_role(ARRAY['admin', 'staff', 'pengurus'])
  )
  WITH CHECK (
    public.current_user_has_any_role(ARRAY['admin', 'staff', 'pengurus'])
  );

COMMIT;
