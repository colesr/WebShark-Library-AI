# Connecting WebShark Library.AI to a real shared backend

Right now, `webshark_v4.html` can run in two modes:

- **Local demo mode** (default, no setup needed) — submissions, votes, and the
  moderation queue only live in your own browser's storage. Good for testing,
  not for a real multi-visitor site.
- **Connected mode** — once you follow the steps below, submissions, votes,
  and moderation are shared across every visitor, backed by a real database.

The file automatically detects which mode to run in based on whether you've
filled in the config values (step 5).

## 1. Create a free Supabase project
Go to https://supabase.com, sign up, and create a new project. Free tier is
enough for this. Note your project's **Project URL** and **anon public key**
(Settings → API) — you'll need both in step 5.

## 2. Run the schema
Open **SQL Editor** in the Supabase dashboard, paste in the contents of
`schema.sql` (included alongside this file), and run it. This creates the
`resources` table, the `admins` table, and the safe upvote function.

## 3. Enable email/password auth
In **Authentication → Providers**, make sure "Email" is enabled (it is by
default). This is what the admin moderation panel will use to log in —
replacing the placeholder passcode from the demo version with real auth.

## 4. Create your admin account
In **Authentication → Users**, click "Add user" and create an account with
your email and a password. Copy the new user's UUID. Then back in the SQL
Editor, run:

```sql
insert into admins (user_id) values ('paste-the-uuid-here');
```

Anyone whose `user_id` is in this table can log into the moderation panel.
Add teammates the same way.

## 5. Connect the frontend
Open `webshark_v4.html` and find this near the top of the `<script>` block:

```js
const SUPABASE_URL = "YOUR_SUPABASE_URL";
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
```

Replace both with the values from step 1. Save the file — it will now run in
connected mode automatically.

## 6. Deploy
This is still a single static HTML file, so any static host works: Netlify,
Vercel, GitHub Pages, Cloudflare Pages, or your own server. The anon key is
safe to expose publicly — it only has the permissions you granted it via Row
Level Security in `schema.sql` (read approved resources, submit as pending,
nothing else).

## What's still local-only, on purpose
Favorites and dark mode preference stay in each visitor's own browser — those
are personal preferences, not shared community data, so that's the right
place for them.

## A note on the upvote safeguard
The `upvote_resource` function stops anonymous visitors from directly editing
resource rows, but it can't fully stop one person from voting multiple times
(e.g. by clearing their browser storage). Real vote-per-person dedup would
require requiring visitors to log in, which is a bigger tradeoff — worth
doing later if vote manipulation becomes an actual problem, not before.
