-- ============================================================
-- Workout Tracking App - Supabase Migration
-- ============================================================

-- Enable pgcrypto for UUID generation (usually already enabled in Supabase)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ============================================================
-- TABLE: profiles
-- ============================================================
CREATE TABLE public.profiles (
  id             UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username       TEXT NOT NULL UNIQUE,
  avatar         TEXT,
  streak         INTEGER NOT NULL DEFAULT 0,
  max_streak     INTEGER NOT NULL DEFAULT 0,
  last_workout_date DATE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: routines
-- ============================================================
CREATE TABLE public.routines (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  items      JSONB NOT NULL DEFAULT '[]'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: custom_exercises
-- ============================================================
CREATE TABLE public.custom_exercises (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  name_en       TEXT,
  category      TEXT,
  category_en   TEXT,
  type          TEXT NOT NULL CHECK (type IN ('weight', 'bodyweight', 'time', 'cardio')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: workouts
-- ============================================================
CREATE TABLE public.workouts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date         DATE NOT NULL,
  type         TEXT NOT NULL CHECK (type IN ('strength', 'cardio', 'other')),
  title        TEXT,
  routine_id   UUID REFERENCES public.routines(id) ON DELETE SET NULL,
  note         TEXT,
  distance     NUMERIC,
  duration_min NUMERIC,
  sets         JSONB NOT NULL DEFAULT '[]'::JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: likes
-- ============================================================
CREATE TABLE public.likes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_id UUID NOT NULL REFERENCES public.workouts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (workout_id, user_id)
);


-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_routines_user_id        ON public.routines(user_id);
CREATE INDEX idx_custom_exercises_user_id ON public.custom_exercises(user_id);
CREATE INDEX idx_workouts_user_id        ON public.workouts(user_id);
CREATE INDEX idx_workouts_date           ON public.workouts(date);
CREATE INDEX idx_likes_workout_id        ON public.likes(workout_id);
CREATE INDEX idx_likes_user_id           ON public.likes(user_id);


-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routines         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes            ENABLE ROW LEVEL SECURITY;


-- ------------------------------------------------------------
-- RLS: profiles
--   - Anyone (including anon) can read all profiles
--   - Only the owner can update their own profile
-- ------------------------------------------------------------
CREATE POLICY "profiles: public read"
  ON public.profiles FOR SELECT
  USING (true);

CREATE POLICY "profiles: owner update"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);


-- ------------------------------------------------------------
-- RLS: routines
--   - Only the owner can SELECT / INSERT / UPDATE / DELETE
-- ------------------------------------------------------------
CREATE POLICY "routines: owner select"
  ON public.routines FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "routines: owner insert"
  ON public.routines FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "routines: owner update"
  ON public.routines FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "routines: owner delete"
  ON public.routines FOR DELETE
  USING (auth.uid() = user_id);


-- ------------------------------------------------------------
-- RLS: custom_exercises
--   - Only the owner can SELECT / INSERT / UPDATE / DELETE
-- ------------------------------------------------------------
CREATE POLICY "custom_exercises: owner select"
  ON public.custom_exercises FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "custom_exercises: owner insert"
  ON public.custom_exercises FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "custom_exercises: owner update"
  ON public.custom_exercises FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "custom_exercises: owner delete"
  ON public.custom_exercises FOR DELETE
  USING (auth.uid() = user_id);


-- ------------------------------------------------------------
-- RLS: workouts
--   - Anyone can read all workouts (social feed)
--   - Only the owner can INSERT / UPDATE / DELETE
-- ------------------------------------------------------------
CREATE POLICY "workouts: public read"
  ON public.workouts FOR SELECT
  USING (true);

CREATE POLICY "workouts: owner insert"
  ON public.workouts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "workouts: owner update"
  ON public.workouts FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "workouts: owner delete"
  ON public.workouts FOR DELETE
  USING (auth.uid() = user_id);


-- ------------------------------------------------------------
-- RLS: likes
--   - Anyone can read all likes
--   - Authenticated users can insert a like (only for themselves)
--   - Authenticated users can delete their own like
-- ------------------------------------------------------------
CREATE POLICY "likes: public read"
  ON public.likes FOR SELECT
  USING (true);

CREATE POLICY "likes: authenticated insert"
  ON public.likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "likes: owner delete"
  ON public.likes FOR DELETE
  USING (auth.uid() = user_id);


-- ============================================================
-- TRIGGER: auto-create profile on new user signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, username, created_at)
  VALUES (
    NEW.id,
    -- Use email prefix as default username; unique conflicts resolved by app layer
    COALESCE(
      NEW.raw_user_meta_data->>'username',
      split_part(NEW.email, '@', 1)
    ),
    NOW()
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
