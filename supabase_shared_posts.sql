-- ============================================================
-- Supabase SQL: shared_posts table create karo
-- Ye script Supabase Dashboard > SQL Editor mein run karein
-- ============================================================

-- 1. shared_posts table banao
CREATE TABLE IF NOT EXISTS public.shared_posts (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sharer_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  original_post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  original_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  caption     TEXT DEFAULT '',
  created_at  TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 2. RLS enable karo
ALTER TABLE public.shared_posts ENABLE ROW LEVEL SECURITY;

-- 3. Policies banao
-- Anyone can view shared posts
CREATE POLICY "Anyone can view shared posts"
  ON public.shared_posts FOR SELECT
  USING (true);

-- Only the sharer can insert
CREATE POLICY "Sharer can insert"
  ON public.shared_posts FOR INSERT
  WITH CHECK (auth.uid() = sharer_id);

-- Only the sharer can delete their share
CREATE POLICY "Sharer can delete"
  ON public.shared_posts FOR DELETE
  USING (auth.uid() = sharer_id);

-- 4. Index banao for performance
CREATE INDEX IF NOT EXISTS idx_shared_posts_sharer_id ON public.shared_posts(sharer_id);
CREATE INDEX IF NOT EXISTS idx_shared_posts_original_post_id ON public.shared_posts(original_post_id);

-- ============================================================
-- NOTE: stories table mein 'original_post_id' column optional hai
-- Agar ye column nahi hai to ye error aa sakta hai jab status share karein
-- Is case mein neeche wali query bhi run karein:
-- ============================================================

-- 5. (OPTIONAL) Stories table mein original_post_id column add karo
-- Ye tab run karein agar stories table mein ye column nahi hai
ALTER TABLE public.stories 
  ADD COLUMN IF NOT EXISTS original_post_id UUID REFERENCES public.posts(id) ON DELETE SET NULL;

-- ============================================================
-- DONE! Ab Flutter app mein share feature kaam karega.
-- ============================================================
