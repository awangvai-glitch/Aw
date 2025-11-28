-- Grant read-only access to the 'servers' table.
-- This allows any client with your Supabase URL and anon key to read the server list.
-- WARNING: This makes your server list public. For a real production app,
-- you would likely want more restrictive policies, for example, only allowing
-- authenticated users to read the data.

-- 1. First, ensure Row Level Security is ENABLED for the table.
--    You can do this in the Supabase Dashboard under Authentication -> Policies.
--    Or you can run:
--    ALTER TABLE public.servers ENABLE ROW LEVEL SECURITY;

-- 2. Then, create a policy to allow read access.
--    If a policy with this name already exists, you might need to drop it first.
--    DROP POLICY "Allow public read access" ON public.servers;

CREATE POLICY "Allow public read access"
ON public.servers
FOR SELECT
USING (true);

/*
--- How to use this file ---
1. Go to your Supabase project dashboard in your browser.
2. In the left-hand menu, click on the "SQL Editor" icon (it looks like a database with a query symbol).
3. Click "+ New query".
4. Copy the CREATE POLICY block from this file (lines 17-21).
5. Paste it into the SQL Editor.
6. Click the "RUN" button.

If it succeeds, you should see a "Success. No rows returned" message.
Your app will now have permission to read the server list.
*/
