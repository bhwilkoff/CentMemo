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

- **Status**: CentMemo (was Duet Connect), 2026-11-21. Bundle `com.learningischange.centmemo`, team Learning is Change, Inc. (`L2G756LY8N`). Ben's words: `docs/WHAT-CENTMEMO-IS.md`. Decisions 054-057.
- **Active milestone**: M1 (plan: memory file `~/.claude/plans/mighty-percolating-simon-*.md`): backend, connector, web app, skills, infrastructure.
- **Built (unverified end to end yet)**:
  - Supabase project `centmemo` (`qucsmmazfalbyduxlavl`, free tier). Migrations in `supabase/migrations/` applied. Edge Function `mcp` deployed; unauthenticated POST returns 401 + `resource_metadata` (verified). OAuth server NOT yet enabled (dashboard).
  - Money core `js/money/money.js` + goldens `node --test tests/*.test.mjs` (5 pass; golden seen failing first).
  - Web app (index.html, js/app.js, js/api.js, css), consent page, privacy, terms. Sign-in screen verified at 375px dark; signed-in views not yet seen.
  - Skills: `claude-connector-mcp`, `finance-app-foundations`, `money-story-design`.
- **Supabase slot**: free tier allows 2 active projects. boba-card-app was paused for CentMemo; Ben unpaused it 2026-11-21 to export BOBA data, and CentMemo is PAUSED until he is done.
- **Next actions**:
  1. When Ben's BOBA export is done: pause boba, restore centmemo.
  2. Dashboard (Chrome): enable OAuth server (authorization path `/oauth/consent/`), Site URL `https://centmemo.com`, redirect URLs, email template.
  3. Seed two synthetic test users + sample ledger; run `node tools/test_rls.mjs`; run `supabase/tests/agents_cannot_write.sql`.
  4. Repo rename to CentMemo, Pages at centmemo.com, DNS at the registrar.
  5. See signed-in views at 375 and 1440, light and dark; connect MCP in Claude Code and call every tool.
  6. Register bundle ID; prefill FinanceKit request for Ben to submit.
  7. Email: privacy@ and hello@centmemo.com are named on the site but don't exist yet.
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
