# Project Scratchpad: CentMemo

> Active working notes, loaded into every session, so keep it small.
> Keep only the two most recent session-log entries; roll older ones
> word for word into `docs/SESSION-LOG.md` (create it on the first roll).
>
> See `PARITY.md` for the cross-platform feature matrix (the single
> source of truth; don't duplicate rows here).
>
> The Current State block below is injected at every session start.
> If it drifts behind the code, fix it FIRST, then work. A stale
> scratchpad is worse than none.

## Current state

- **Status**: CentMemo (was Duet Connect), 2026-11-21. Bundle `com.learningischange.centmemo` (registered in ASC, id HF5UVXKG59), team Learning is Change, Inc. (`L2G756LY8N`). Repo `bhwilkoff/CentMemo` (public). Ben's words: `docs/WHAT-CENTMEMO-IS.md`. Decisions 054-057.
- **Active milestone**: M1: backend, connector, web app, skills, infrastructure.
- **Verified**:
  - Supabase `centmemo` (`qucsmmazfalbyduxlavl`, free tier) live; boba-card-app paused (BOBA exported, being shut down).
  - `node tools/test_rls.mjs` PASS on the deployed project; negative control FAILS as expected (read-only control).
  - Agent rule (SQL, rolled back): person writes; client_id token reads 22 rows, insert refused, update touches 0.
  - `node tools/seed_demo.mjs` idempotent (22 new, then 0). Synthetic users in `~/.centmemo/test-users.json` (owner = directory reviewer account).
  - Web views seen live at 1440 and 375 dark: Unexamined, Ledger (totals hand-checked), Story with values, memo save through the UI.
  - MCP function: unauthenticated POST returns 401 + resource_metadata.
  - Pages builds (`.nojekyll`); DNS at WordPress.com: 4 GitHub A records, `www` CNAME to bhwilkoff.github.io. HTTPS certificate pending, then Enforce HTTPS.
- **iOS app (2026-11-21, M2 started)**: target renamed CentMemo, iOS-only (Decision 055). Core: `Money` (Swift port, parity goldens vs web IDs, negative control seen failing), `APIClient` (Supabase REST via URLSession, Keychain session), `FinanceSource` (FinanceKit gated by `CMFinanceKitEnabled` Info key + entitlement; DEBUG `APP_SAMPLE_FINANCE=1`). Views: SignIn (email code), Unexamined, Ledger, Story, EntryDetail, Settings (import, connector, delete). Seen in simulator with live data: Unexamined, Detail. Lessons: dates must format at UTC (fixed + test); unsigned sim builds can't use Keychain, so build sim with `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual`. Tests: `xcodebuild test -scheme CentMemoTests -destination platform=macOS`.
- **Look (Decisions 059-060, docs/DESIGN.md binding)**: paper page, ink text, sanguine pencil; the person's color (aqua default, 6 choices, stored in profiles) marks only what still needs a memo and their values. Newsreader / New York serif. Seen: web Ledger + Unexamined light; iOS Unexamined. `tools/test_grounds.mjs`.
- **Sign-in (Decision 058, amended)**: Apple only. Web VERIFIED by Ben 2026-11-21 ("I also logged in just fine on the web"). iPhone (id_token) not yet verified: needs a team-signed device build.
- **Color research**: docs/research/color-search.md (Human Shaped method).
- **Testing (docs/TESTING.md)**: `tools/test_all.sh` (ALL PASS) off-device; on the iPhone 12 under the shared device lease: `tools/ios_uitest.py` (8/8 tap tests: tabs, memo write/read-back/remove, color persists; no crashes) and `tools/ios_run.py` (5/5 OCR scenarios; negative control FAILs as expected). Harness from Ear Drama (power never touched). Bugs it found: keyboard covered Save (now nav-bar Save + keyboard Done), "Saved." off-screen (now under the memo).
- **Store (docs/STORE.md)**: App Store Connect app 6837824241 (Finance); TestFlight 1.0 (1) VALID; internal group "CentMemo testers" (all builds), Ben invited 2026-11-21. Brand: Decision 061, /brand/.
- **Autonomous loop**: AUTONOMOUS_PROGRESS.md holds the backlog and tick log.
- **Blocked on Ben**:
  1. Chrome is signed in to the Minerva Supabase account; sign in as the Learning is Change owner so the agent can enable the OAuth server (path `/oauth/consent/`), Site URL `https://centmemo.com`, redirect URLs. Or create an org-wide Supabase access token at `~/.centmemo/supabase-token`.
  2. Apple Developer sign-in in Chrome, then the agent prefills the FinanceKit form and Ben presses Submit.
  3. Optional: allow routine Supabase MCP tools in `/permissions` (the agent may not edit its own permissions).
- **Next after unblock**: connect MCP in Claude Code through OAuth and call all six tools; Ben adds the connector on claude.ai and runs the Duet live + scheduled test; email forwarding for privacy@ and hello@centmemo.com; M2 iOS app.
- **Open questions**: end of `docs/research/apple-card-financekit-connector.md`.

---

## Milestones

- **M0 (done 2026-11-21)**: the owner's words in AGENTS.md; centmemo.com live
  over HTTPS; real data (an Apple Card CSV) through the web; the owner signed
  in (Apple, web).
- **M1 (done)**: backend, read-only Claude connector, web app, finance skills
  (plan: `~/.claude/plans/mighty-percolating-simon-*.md`).
- **M2 (in progress)**: iPhone app on TestFlight; FinanceKit once Apple grants
  it; photos by reference; shared stories. Tick-level work and the backlog:
  `AUTONOMOUS_PROGRESS.md`.

## Out of scope (intentionally)

| Idea | Why declined | Revisit when |
|---|---|---|
| Handwriting or informal typefaces | Ben: "read like elementary school kids are writing financial memos" (memory no-handwriting-fonts) | Never |
| The person's color as a page background | Ben: "reads as too much color ... harder to read" (Decision 060) | Never |
| Claude writing memos or values | The memo is the person's act of examining (Decision 056); FinanceKit Addendum 3.2 | A new decision |
| FinanceKit rows in the Claude connector | Addendum 3.2: no third-party disclosure without Apple's written permission | Apple grants it |
| Email sign-in or codes | Apple sign-in covers web and iPhone with two-factor; email codes need SMTP (Decision 058) | Non-Apple users appear |
| Shortcuts-only Apple Card capture | Sees only Apple Pay taps; FinanceKit is the full path | Never |
| tvOS and Android apps | FinanceKit is iPhone-only; not lean-back (Decision 055) | A CSV-only audience asks |

## Session log

The tick-by-tick log is `AUTONOMOUS_PROGRESS.md`; earlier sessions are in the
git history and DECISIONS.md.
