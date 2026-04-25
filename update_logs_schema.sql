-- Create table for logging clip performance
CREATE TABLE IF NOT EXISTS public.clip_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users NOT NULL,
  program_id text NOT NULL, -- or uuid if programs use uuid
  clip_index int NOT NULL,
  clip_title text,
  sets int DEFAULT 0,
  reps int DEFAULT 0,
  duration_seconds int DEFAULT 0,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.clip_logs ENABLE ROW LEVEL SECURITY;

-- Policy
CREATE POLICY "Users can insert their own logs"
  ON public.clip_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own logs"
  ON public.clip_logs FOR SELECT
  USING (auth.uid() = user_id);
