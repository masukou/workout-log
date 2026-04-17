-- ============================================================
-- Suggestions Feature Migration
-- ============================================================

CREATE TABLE public.suggestions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body       TEXT NOT NULL,
  status     TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'noted', 'done', 'declined')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_suggestions_user_id ON public.suggestions(user_id);
CREATE INDEX idx_suggestions_status  ON public.suggestions(status);

ALTER TABLE public.suggestions ENABLE ROW LEVEL SECURITY;

-- Only the submitter can read their own suggestions
CREATE POLICY "suggestions: self read"
  ON public.suggestions FOR SELECT
  USING (auth.uid() = user_id);

-- Authenticated users can submit their own suggestion
CREATE POLICY "suggestions: self insert"
  ON public.suggestions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own suggestion
CREATE POLICY "suggestions: self delete"
  ON public.suggestions FOR DELETE
  USING (auth.uid() = user_id);
