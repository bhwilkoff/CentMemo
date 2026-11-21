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
- **Blocked on Ben**:
  1. Chrome is signed in to the Minerva Supabase account; sign in as the Learning is Change owner so the agent can enable the OAuth server (path `/oauth/consent/`), Site URL `https://centmemo.com`, redirect URLs. Or create an org-wide Supabase access token at `~/.centmemo/supabase-token`.
  2. Apple Developer sign-in in Chrome, then the agent prefills the FinanceKit form and Ben presses Submit.
  3. Optional: allow routine Supabase MCP tools in `/permissions` (the agent may not edit its own permissions).
- **Next after unblock**: connect MCP in Claude Code through OAuth and call all six tools; Ben adds the connector on claude.ai and runs the Duet live + scheduled test; email forwarding for privacy@ and hello@centmemo.com; M2 iOS app.
- **Open questions**: end of `docs/research/apple-card-financekit-connector.md`.

---

## Milestones

### M0: A first version, live at its own address

- [ ] The web app carries the app's name and is live on GitHub Pages
- [ ] AGENTS.md "Why we build" and "What this app does" hold the
      owner's own words (stage 00)
- [ ] One platform, real data from a real source, live at its address
      (stage 01)
- [ ] One person the owner knows has used it, and what they did first
      is written down

### When you go native (stage 03)

Only when the owner decides to add a platform, and logs the platform
set in DECISIONS.md. The agent does each of these; the owner never
clicks through Xcode or Android Studio.

- [ ] **Apple (universal)**: rename `AppName` and the bundle ids in
      `project.yml` (no spaces), run `xcodegen generate`, then build
      unsigned for iOS Simulator, tvOS Simulator, and macOS and run the
      Core tests, per `apple/README.md`. One target, four destinations;
      sources stay in `apple/`; `AppVersion.xcconfig` is already wired
- [ ] **Android**: `cd android && ./gradlew :app:assembleDebug`; rename
      the package from `com.example.appname` to your reverse-DNS and
      rebuild; smoke-test on a device or emulator
- [ ] **Links**: drop verification files in `/.well-known/` (with
      `.nojekyll`) once the `appID`, `package_name`, and fingerprints
      are known
- [ ] **CI / submission**: `.github/workflows/appstore-build.yml`
      (one workflow covers iOS + macOS + tvOS) with the seven signing
      secrets seeded per `docs/CLOUD-SUBMISSION.md`;
      `.github/workflows/android-build.yml` for CI builds and
      `.github/workflows/play-release.yml` to publish to Play (internal
      track first, then promote)

### M1: [First user-visible capability]

<!-- One sentence: what can a user DO after this milestone? -->

Before implementing, run the `learning-orientation-design` skill:

- [ ] Deepens understanding
- [ ] Invites participation
- [ ] Supports agency
- [ ] Clarity over cleverness

**Acceptance criteria** (observable by users, not developers):

- [ ] Web: …
- [ ] (each platform you have added: …)

**Parity check**: update PARITY.md row(s) for this capability in
the same change set. Reject the PR if PARITY.md is silent.

### M2: [Second user-visible capability]

- Learning-orientation check passed
- **Acceptance**:
  - [ ] Web: …
  - [ ] (each platform you have added: …)

---

## When to add a binding design doc

When a platform crosses ~5 views OR you find yourself making
inconsistent UI choices, create that platform's binding doc
(`tvOS-DESIGN.md`, `iOS-DESIGN.md`, `macOS-DESIGN.md`, `WEB-DESIGN.md`,
`ANDROID-DESIGN.md`), seeded from the matching per-platform template
in `docs/templates/` (start from `PLATFORM-DESIGN-template.md`, the
index). Invoke
`binding-design-doc-discipline` for the workflow. Treat as binding
from the moment it exists.

The sibling docs share a shape: the **principles** are identical;
the **idioms** they reference diverge per platform. Deliberate
rule inversions between platforms (tvOS auto-focuses Play; iOS
never steals focus) are stated explicitly so they don't get
"harmonized" away.

---

## Open questions

<!-- Add questions as they arise; remove when resolved. Don't
     accumulate. Every question should have a path to resolution. -->

---

## Out of scope (intentionally)

Document explicitly-rejected ideas so future sessions don't
re-litigate them. "We thought about this and chose not to design it
now" is far more useful than silently re-arriving at the same answer.

When a request gets declined, write a row. Format:
`**Idea**: Why declined. Revisit when …` (revisit condition lets
the entry retire when circumstances change).

| Idea | Why declined | Revisit when |
|---|---|---|
| <!-- e.g. Web push notifications | Too-inconsistent UX across browsers; APNs/FCM cover the need on mobile | iOS + Android push ship and a real cross-platform request appears --> | | |

---

## Session log

<!-- Append-only. Format: state found → work done → state left.
     Keep entries short: one paragraph per session. -->
