-- =========================================================
-- Enable role "pengurus" to manage competition achievements.
-- Safe to re-run.
-- =========================================================

BEGIN;

ALTER TABLE IF EXISTS public.competition_news ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.competition_winners ENABLE ROW LEVEL SECURITY;

-- Drop legacy and replacement policy names if present.
DROP POLICY IF EXISTS competition_news_select ON public.competition_news;
DROP POLICY IF EXISTS competition_news_manage_staff_admin ON public.competition_news;
DROP POLICY IF EXISTS competition_news_manage_manager_roles ON public.competition_news;

DROP POLICY IF EXISTS competition_winners_select ON public.competition_winners;
DROP POLICY IF EXISTS competition_winners_manage_staff_admin ON public.competition_winners;
DROP POLICY IF EXISTS competition_winners_manage_manager_roles ON public.competition_winners;

-- Competition news
CREATE POLICY competition_news_select
ON public.competition_news
FOR SELECT
TO authenticated
USING (
  is_published = true
  OR public.current_user_has_any_role(
    ARRAY['member', 'coach', 'staff', 'admin', 'pengurus']
  )
);

CREATE POLICY competition_news_manage_manager_roles
ON public.competition_news
FOR ALL
TO authenticated
USING (public.current_user_has_any_role(ARRAY['staff', 'admin', 'pengurus']))
WITH CHECK (public.current_user_has_any_role(ARRAY['staff', 'admin', 'pengurus']));

-- Competition winners
CREATE POLICY competition_winners_select
ON public.competition_winners
FOR SELECT
TO authenticated
USING (
  public.current_user_has_any_role(
    ARRAY['staff', 'admin', 'pengurus']
  )
  OR EXISTS (
    SELECT 1
    FROM public.competition_news cn
    WHERE cn.id = competition_winners.competition_news_id
      AND (
        cn.is_published = true
        OR public.current_user_has_any_role(
          ARRAY['member', 'coach', 'staff', 'admin', 'pengurus']
        )
      )
  )
);

CREATE POLICY competition_winners_manage_manager_roles
ON public.competition_winners
FOR ALL
TO authenticated
USING (public.current_user_has_any_role(ARRAY['staff', 'admin', 'pengurus']))
WITH CHECK (public.current_user_has_any_role(ARRAY['staff', 'admin', 'pengurus']));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.competition_news TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.competition_winners TO authenticated;

COMMIT;
