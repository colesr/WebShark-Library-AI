# Connecting WebShark Library.AI to a real shared backend

Right now, `index.html` can run in two modes:

- **Local demo mode** (default if Supabase keys are missing) — accounts, comments,
  submissions, votes, and the moderation queue only live in your own browser's
  storage. Good for testing, not for a real multi-visitor site.
- **Connected mode** — once you follow the steps below, everything is shared
  across visitors, backed by Supabase.

The file automatically detects which mode to run in based on whether the
Supabase URL and anon key look valid.

## Product model (what needs an account)

| Action | Account needed? |
|--------|-----------------|
| Browse, search, filter resources | No |
| Open / visit resources | No |
| Star favorites (local) | No |
| Upvote | No |
| Suggest a resource | No |
| Copy / share a link | No |
| Leave or delete comments | **Yes** — free account + public username |
| Admin moderation | **Yes** — account listed in `admins` |

## 1. Create a free Supabase project

Go to https://supabase.com, sign up, and create a new project. Free tier is
enough. Note your project's **Project URL** and **anon public key**
(Settings → API).

## 2. Run the schema

Open **SQL Editor** in the Supabase dashboard, paste the full contents of
`schema.sql`, and run it. This creates:

- `resources` — community submissions + moderation + votes
- `admins` — who can approve/reject
- `profiles` — public usernames (required for comments)
- `comments` — discussion threads keyed by resource
- `upvote_resource()` — safe anonymous upvote RPC
- `comment_counts` — convenience view for counts

If you already ran an older version of the schema, re-running the new file is
safe: policies are dropped/recreated, and new tables use `IF NOT EXISTS`.

## 3. Enable email/password auth

In **Authentication → Providers**, make sure **Email** is enabled (default).

Optional but recommended for production:

- Disable "Confirm email" while testing (Authentication → Providers → Email),
  or users must click the confirmation link before they can log in.
- Turn confirmations back on before a public launch if you want verified emails.

## 4. Create your admin account

1. Sign up through the site UI (Sign in → Sign up) **or** create a user under
   Authentication → Users.
2. Copy the user's UUID.
3. In SQL Editor:

```sql
insert into admins (user_id) values ('paste-the-uuid-here');
```

Anyone in this table can open the moderation panel after logging in with that
account. Add teammates the same way.

**Note:** Community users also use the same email/password auth. Only the
`admins` row elevates someone to moderator.

## 5. Connect the frontend

Open `index.html` and find:

```js
const SUPABASE_URL = "YOUR_SUPABASE_URL";
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
```

Replace both with the values from step 1. Save — the site runs in connected
mode automatically when the URL starts with `http` and the key is long enough.

## 6. Deploy

This is still a single static HTML file, so any static host works: Netlify,
Vercel, GitHub Pages, Cloudflare Pages, or your own server. The anon key is
safe to expose publicly — it only has the permissions granted via Row Level
Security in `schema.sql`.

## Sharing links

Each resource card has a **Share** menu:

- **Copy link** — deep link like `https://yoursite/?r=base-12`
- **Share…** — uses the browser's native share sheet when available
- **X / LinkedIn / Reddit** — opens a pre-filled share dialog

Deep links scroll to the resource and open its comments panel.

## What's still local-only, on purpose

- **Favorites** and **dark mode** stay in each visitor's browser (personal
  preferences, not shared community data).
- **Upvote "already voted" flags** are still browser-local to reduce double
  clicks. True one-vote-per-person would require forcing login for votes —
  intentionally not required so the library stays frictionless.

## Demo mode accounts

Without Supabase, "Sign up" stores users in `localStorage` so you can try
comments offline. Those accounts are not shared across devices or visitors.
