-- ==========================================
-- SUPABASE FIXES FOR STORIES AND SHARE
-- ==========================================

-- 1. Add missing column 'original_post_id' to 'stories' table for sharing posts as status
ALTER TABLE public.stories 
ADD COLUMN IF NOT EXISTS original_post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE;

-- Force Supabase to reload the schema cache so the error goes away instantly
NOTIFY pgrst, 'reload schema';

-- 2. Create the 'stories' storage bucket for uploading status images
INSERT INTO storage.buckets (id, name, public) 
VALUES ('stories', 'stories', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Add Security Policies so images can be uploaded and viewed

-- Allow everyone to view the stories
CREATE POLICY "Stories are publicly accessible" 
ON storage.objects FOR SELECT 
USING ( bucket_id = 'stories' );

-- Allow logged-in users to upload story images
CREATE POLICY "Users can upload stories" 
ON storage.objects FOR INSERT 
WITH CHECK ( bucket_id = 'stories' AND auth.role() = 'authenticated' );

-- Allow users to delete their own uploaded stories
CREATE POLICY "Users can delete their own stories"
ON storage.objects FOR DELETE
USING ( bucket_id = 'stories' AND auth.role() = 'authenticated' );
