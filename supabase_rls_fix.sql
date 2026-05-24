-- ==========================================
-- SUPABASE FIX FOR "SHARE TO FEED" (RLS Policy)
-- ==========================================

-- 1. Pehle agar koi purani policies hain to unhe remove karein (taake errors na aayen)
DROP POLICY IF EXISTS "Anyone can view shared posts" ON public.shared_posts;
DROP POLICY IF EXISTS "Sharer can insert" ON public.shared_posts;
DROP POLICY IF EXISTS "Sharer can delete" ON public.shared_posts;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.shared_posts;

-- 2. Sabhi ko posts dekhne ki ijazat dein
CREATE POLICY "Anyone can view shared posts"
  ON public.shared_posts FOR SELECT
  USING (true);

-- 3. Sirf Logged in (authenticated) users ko post share (insert) karne ki ijazat dein
CREATE POLICY "Enable insert for authenticated users"
  ON public.shared_posts FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- 4. User sirf apni share ki hui post delete kar sake
CREATE POLICY "Sharer can delete"
  ON public.shared_posts FOR DELETE
  TO authenticated
  USING (auth.uid() = sharer_id);

-- Optional: Cache reload (zaroori nahi but safe hai)
NOTIFY pgrst, 'reload schema';
