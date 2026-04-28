-- Add 'type' column to distinguish between 'standard' and 'sequence'
ALTER TABLE public.workouts 
ADD COLUMN IF NOT EXISTS type text DEFAULT 'standard';

-- Add 'clips' column to store the JSON array of clips
ALTER TABLE public.workouts 
ADD COLUMN IF NOT EXISTS clips jsonb DEFAULT '[]'::jsonb;

-- Add 'type' column to programs table
ALTER TABLE public.programs
ADD COLUMN IF NOT EXISTS type text DEFAULT 'standard';

-- Add 'clips' column to programs table (for sequence programs)
ALTER TABLE public.programs
ADD COLUMN IF NOT EXISTS clips jsonb DEFAULT '[]'::jsonb;

-- Add support for multiple workouts under one program day
ALTER TABLE public.program_days
ADD COLUMN IF NOT EXISTS workout_ids jsonb DEFAULT '[]'::jsonb;

-- Backfill old single-workout rows into the new array column
UPDATE public.program_days
SET workout_ids = jsonb_build_array(workout_id)
WHERE workout_id IS NOT NULL
  AND (workout_ids IS NULL OR workout_ids = '[]'::jsonb);
