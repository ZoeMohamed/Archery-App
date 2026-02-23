-- =========================================================
-- Competition schema synchronization (legacy -> V4-compatible)
-- Safe to re-run. Keep legacy columns/data intact.
-- =========================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Keep role helper available for RLS policies.
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

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS public.competition_news (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  title varchar(255) NOT NULL,
  content text NOT NULL,
  image_url text,
  gallery_urls text[],
  competition_name varchar(255),
  competition_date date,
  location varchar(255),
  category varchar(100),
  total_participants integer,
  published_by uuid REFERENCES public.users(id),
  is_published boolean DEFAULT false,
  published_at timestamptz,
  created_at timestamptz DEFAULT NOW(),
  updated_at timestamptz DEFAULT NOW()
);

ALTER TABLE public.competition_news
  ADD COLUMN IF NOT EXISTS image_url text,
  ADD COLUMN IF NOT EXISTS gallery_urls text[],
  ADD COLUMN IF NOT EXISTS competition_name varchar(255),
  ADD COLUMN IF NOT EXISTS competition_date date,
  ADD COLUMN IF NOT EXISTS location varchar(255),
  ADD COLUMN IF NOT EXISTS category varchar(100),
  ADD COLUMN IF NOT EXISTS total_participants integer,
  ADD COLUMN IF NOT EXISTS published_by uuid REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS is_published boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS published_at timestamptz,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT NOW();

-- Keep legacy winner_ids optional so modern inserts do not fail.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'competition_news'
      AND column_name = 'winner_ids'
  ) THEN
    EXECUTE 'ALTER TABLE public.competition_news ALTER COLUMN winner_ids DROP NOT NULL';
    EXECUTE 'ALTER TABLE public.competition_news ALTER COLUMN winner_ids SET DEFAULT ARRAY[]::uuid[]';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_competition_news_published
ON public.competition_news (is_published, published_at DESC);

CREATE TABLE IF NOT EXISTS public.competition_winners (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  competition_news_id uuid NOT NULL REFERENCES public.competition_news(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  rank integer NOT NULL,
  medal varchar(20) CHECK (medal IN ('gold', 'silver', 'bronze', NULL)),
  score integer,
  max_score integer,
  created_at timestamptz DEFAULT NOW(),
  CONSTRAINT unique_winner UNIQUE (competition_news_id, user_id)
);

ALTER TABLE public.competition_winners
  ADD COLUMN IF NOT EXISTS rank integer,
  ADD COLUMN IF NOT EXISTS medal varchar(20),
  ADD COLUMN IF NOT EXISTS score integer,
  ADD COLUMN IF NOT EXISTS max_score integer,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT NOW();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'competition_winners_medal_check'
      AND conrelid = 'public.competition_winners'::regclass
  ) THEN
    ALTER TABLE public.competition_winners
      ADD CONSTRAINT competition_winners_medal_check
      CHECK (medal IN ('gold', 'silver', 'bronze', NULL));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_winners_news
ON public.competition_winners(competition_news_id);

CREATE INDEX IF NOT EXISTS idx_winners_user
ON public.competition_winners(user_id);

-- Backfill winners from legacy winner_ids[] when available.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'competition_news'
      AND column_name = 'winner_ids'
  ) THEN
    EXECUTE $sql$
      INSERT INTO public.competition_winners (
        id,
        competition_news_id,
        user_id,
        rank,
        medal,
        created_at
      )
      SELECT
        uuid_generate_v4(),
        cn.id,
        ranked.user_id,
        ranked.rank_no,
        CASE ranked.rank_no
          WHEN 1 THEN 'gold'
          WHEN 2 THEN 'silver'
          WHEN 3 THEN 'bronze'
          ELSE NULL
        END,
        NOW()
      FROM public.competition_news cn
      CROSS JOIN LATERAL unnest(COALESCE(cn.winner_ids, ARRAY[]::uuid[]))
        WITH ORDINALITY AS ranked(user_id, rank_no)
      WHERE EXISTS (
        SELECT 1 FROM public.users u WHERE u.id = ranked.user_id
      )
      ON CONFLICT (competition_news_id, user_id) DO NOTHING
    $sql$;
  END IF;
END $$;

DROP TRIGGER IF EXISTS update_competitions_updated_at ON public.competition_news;
CREATE TRIGGER update_competitions_updated_at
BEFORE UPDATE ON public.competition_news
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.competition_news ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.competition_winners ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  p record;
BEGIN
  FOR p IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = ANY (ARRAY['competition_news', 'competition_winners'])
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON %I.%I',
      p.policyname,
      p.schemaname,
      p.tablename
    );
  END LOOP;
END $$;

CREATE POLICY competition_news_select
ON public.competition_news
FOR SELECT
TO authenticated
USING (
  is_published = true
  OR public.current_user_has_any_role(ARRAY['member', 'coach', 'staff', 'admin', 'pengurus'])
);

CREATE POLICY competition_news_manage_staff_admin
ON public.competition_news
FOR ALL
TO authenticated
USING (public.current_user_has_any_role(ARRAY['staff', 'admin', 'pengurus']))
WITH CHECK (public.current_user_has_any_role(ARRAY['staff', 'admin', 'pengurus']));

CREATE POLICY competition_winners_select
ON public.competition_winners
FOR SELECT
TO authenticated
USING (
  public.current_user_has_any_role(ARRAY['staff', 'admin', 'pengurus'])
  OR EXISTS (
    SELECT 1
    FROM public.competition_news cn
    WHERE cn.id = competition_winners.competition_news_id
      AND (
        cn.is_published = true
        OR public.current_user_has_any_role(ARRAY['member', 'coach', 'staff', 'admin', 'pengurus'])
      )
  )
);

CREATE POLICY competition_winners_manage_staff_admin
ON public.competition_winners
FOR ALL
TO authenticated
USING (public.current_user_has_any_role(ARRAY['staff', 'admin', 'pengurus']))
WITH CHECK (public.current_user_has_any_role(ARRAY['staff', 'admin', 'pengurus']));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.competition_news TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.competition_winners TO authenticated;

CREATE OR REPLACE VIEW public.v_latest_competition_news AS
SELECT
  cn.id,
  cn.title,
  cn.content,
  cn.image_url,
  cn.competition_name,
  cn.competition_date,
  cn.location,
  cn.published_at,
  COALESCE(
    array_agg(DISTINCT u.full_name) FILTER (WHERE u.id IS NOT NULL),
    ARRAY[]::text[]
  ) AS winner_names,
  COALESCE(
    array_agg(DISTINCT cw.medal) FILTER (WHERE cw.medal IS NOT NULL),
    ARRAY[]::text[]
  ) AS medals,
  cn.category,
  cn.total_participants
FROM public.competition_news cn
LEFT JOIN public.competition_winners cw
  ON cn.id = cw.competition_news_id
LEFT JOIN public.users u
  ON cw.user_id = u.id
WHERE cn.is_published = true
GROUP BY
  cn.id,
  cn.title,
  cn.content,
  cn.image_url,
  cn.competition_name,
  cn.competition_date,
  cn.location,
  cn.category,
  cn.total_participants,
  cn.published_at
ORDER BY cn.published_at DESC;

GRANT SELECT ON public.v_latest_competition_news TO authenticated;

COMMIT;
