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
- Apply these migrations in Supabase Dashboard → SQL Editor, in order:
	1. `supabase-binary-network.sql` adds parent/sponsor placement fields, unique LEFT/RIGHT positions, cycle protection, network status, and hierarchy indexes.
	2. `supabase-distributor-accounts.sql` adds distributor inventory, ledger, commissions, payments, adjustment requests, row-level security, and atomic account RPCs.
	3. `supabase-distributor-identity-card.sql` adds the private profile-photo path used on distributor ID cards.
	4. `supabase-distributor-profile-updates.sql` adds owner-scoped RPCs for distributor profile, bank, and photo updates.
	5. `supabase-admin-remove-distributor.sql` replaces the older removal function. The admin removal action permanently deletes the distributor's sign-in, profile, application, stock, payments, commissions, and ledger, while keeping and detaching their downline accounts.
- Distributor applications retain the site's existing five-minute automatic approval behavior.

The Supabase URL and publishable (anon) key inside the HTML files are public by design. Data is protected by row-level security in the database.
