-- ============================================================
-- Group Feature Migration
-- ============================================================

-- TABLE: groups
CREATE TABLE public.groups (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  icon       TEXT NOT NULL DEFAULT '⚡',
  invite_code TEXT NOT NULL UNIQUE DEFAULT substr(replace(gen_random_uuid()::text, '-', ''), 1, 8),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- TABLE: group_members
CREATE TABLE public.group_members (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id  UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role      TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (group_id, user_id)
);

-- TABLE: group_battles
CREATE TABLE public.group_battles (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_a_id   UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  group_b_id   UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  metric       TEXT NOT NULL DEFAULT 'volume' CHECK (metric IN ('volume', 'workouts', 'streak')),
  start_date   DATE NOT NULL,
  end_date     DATE NOT NULL,
  status       TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'finished')),
  created_by   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- INDEXES
CREATE INDEX idx_group_members_group_id ON public.group_members(group_id);
CREATE INDEX idx_group_members_user_id  ON public.group_members(user_id);
CREATE INDEX idx_group_battles_group_a  ON public.group_battles(group_a_id);
CREATE INDEX idx_group_battles_group_b  ON public.group_battles(group_b_id);

-- ROW LEVEL SECURITY
ALTER TABLE public.groups         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_battles  ENABLE ROW LEVEL SECURITY;

-- RLS: groups - anyone can read, authenticated can create
CREATE POLICY "groups: public read"
  ON public.groups FOR SELECT USING (true);

CREATE POLICY "groups: authenticated insert"
  ON public.groups FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "groups: admin update"
  ON public.groups FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.group_members WHERE group_id = groups.id AND user_id = auth.uid() AND role = 'admin'));

CREATE POLICY "groups: admin delete"
  ON public.groups FOR DELETE
  USING (auth.uid() = created_by);

-- RLS: group_members - anyone can read, authenticated can join/leave
CREATE POLICY "group_members: public read"
  ON public.group_members FOR SELECT USING (true);

CREATE POLICY "group_members: self insert"
  ON public.group_members FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "group_members: self delete"
  ON public.group_members FOR DELETE
  USING (auth.uid() = user_id);

-- RLS: group_battles - anyone can read, members can create
CREATE POLICY "group_battles: public read"
  ON public.group_battles FOR SELECT USING (true);

CREATE POLICY "group_battles: authenticated insert"
  ON public.group_battles FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "group_battles: creator update"
  ON public.group_battles FOR UPDATE
  USING (auth.uid() = created_by);
