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
