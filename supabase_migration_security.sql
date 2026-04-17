-- ============================================================
-- Security Features Migration
-- ============================================================

-- TABLE: reports
CREATE TABLE public.reports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason           TEXT NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (reporter_id, reported_user_id)
);

CREATE INDEX idx_reports_reported ON public.reports(reported_user_id);
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reports: self insert"
  ON public.reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "reports: self read"
  ON public.reports FOR SELECT
  USING (auth.uid() = reporter_id);

-- TABLE: blocks
CREATE TABLE public.blocks (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (blocker_id, blocked_id)
);

CREATE INDEX idx_blocks_blocker ON public.blocks(blocker_id);
CREATE INDEX idx_blocks_blocked ON public.blocks(blocked_id);
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "blocks: self insert"
  ON public.blocks FOR INSERT
  WITH CHECK (auth.uid() = blocker_id);

CREATE POLICY "blocks: self read"
  ON public.blocks FOR SELECT
  USING (auth.uid() = blocker_id);

CREATE POLICY "blocks: self delete"
  ON public.blocks FOR DELETE
  USING (auth.uid() = blocker_id);

-- ADD is_private column to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT false;

-- FUNCTION: delete own account and all data
CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.suggestions WHERE user_id = auth.uid();
  DELETE FROM public.reports WHERE reporter_id = auth.uid();
  DELETE FROM public.blocks WHERE blocker_id = auth.uid() OR blocked_id = auth.uid();
  DELETE FROM public.likes WHERE user_id = auth.uid();
  DELETE FROM public.group_members WHERE user_id = auth.uid();
  DELETE FROM public.workouts WHERE user_id = auth.uid();
  DELETE FROM public.routines WHERE user_id = auth.uid();
  DELETE FROM public.custom_exercises WHERE user_id = auth.uid();
  DELETE FROM public.profiles WHERE id = auth.uid();
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;
