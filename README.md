# AYU LIFE HEARBAL website

Static site (no build step) backed by Supabase.

- `/`        public website, customer and distributor login
- `/admin`   separate administrator panel
- `vercel.json` routes `/admin` and adds no-index / anti-framing headers

## Deploy (Vercel)
1. Import this repository in Vercel. Framework preset: **Other**. No build command. Output directory: `./`
2. Add your domain under Project → Settings → Domains.
3. Project → Settings → Deployment Protection: make sure production is public.

## Supabase settings to check
- Authentication → URL Configuration: set **Site URL** to your domain and add it to Redirect URLs.
- Authentication → SMTP: configure your own SMTP so sign-up confirmation emails are reliable.
- Administrator accounts have role `admin` in table `ayu_profiles`. Change admin passwords after first login (/admin → Settings).
- Run `supabase-binary-network.sql` once in Supabase Dashboard → SQL Editor before enabling the two-team hierarchy. It adds parent/sponsor placement fields, unique LEFT/RIGHT positions, cycle protection, network status, and recurring hierarchy indexes without removing existing records.

The Supabase URL and publishable (anon) key inside the HTML files are public by design. Data is protected by row-level security in the database.
