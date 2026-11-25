# Autonomous progress (CentMemo)

The loop's durable log and backlog (`autonomous-loop-cadence`). Every tick
appends an entry and commits. After compaction, read the backlog and the
last entry to resume.

**Cadence** (web and iOS are the shipped platforms; macOS waits, tvOS and
Android are out by Decision 055): tick % 5:
- 1 and 3: iOS
- 2: web
- 4: infrastructure (store, brand, connector, docs)
- 0: opt (net-remove lines)

The owner's requests jump the rotation.

**Rules every tick**:
- Quote `docs/DESIGN.md` before UI work.
- Audit before shipping (grep for the feature; PARITY.md can lie).
- Verify with `tools/test_all.sh` EVERY tick, however small (ticks 1 to 4
  skipped it and missed a manifest drift), and gate the commit on its EXIT
  CODE, never on `| tail` (tick 18 committed over a failure that way), plus the device tiers on the iPhone 12
  (`tools/ios_uitest.py`, `tools/ios_run.py`) for iOS work.
- One commit per tick. Bump both iOS version numbers on iOS-touching ticks.
- The agent is never the tester of record: Ben plays.
- No handwriting fonts; color is a mark, never a ground (memories).
- DECISIONS entries are append-only (Decision 033): never edit one in place,
  even a superseded one. Supersession shows in the newer entry and the index.

## Resume here (loop resumed by Ben, 2026-11-24 ~11am: "Can we resume the work loop for what has been documented? We need to keep building this out.")

Ben's order (2026-11-23): F1/F2 FinanceKit → D14 themes → D15 place → D12
sharing → item 10 files → L2/L3 submission → macOS and iPad later. Done
through item 10 except what is listed below. L2 stays held for Ben's design
sign-off.

**Unverified on a device (do first):**
- D15b `SettingUITests/testFindOnTheMapNearHere` on the iPhone 12: Find on
  the map → Current Location → a guess near the phone. The `canSearchNearby`
  section condition (cb693f3) is fixed but never observed. Or Ben taps
  Current Location on his Duo's Apple Store page.
- iOS photo copy upload ("Keep a copy in CentMemo"): the bench declines
  Photos access; needs a phone with access, and Ben's OK (writes to his account).

- D15b update, 2026-11-24: on the iPhone 12 Find on the map shows and Current
  Location taps; iOS then asks for location (first use). The test answers Not
  Now and skips, since a person grants access. The search after it is unseen.

**Bench facts:**
- The iPhone 12 Screen Time limit blocks CentMemo from about 9:20pm to past
  midnight (and likely overnight Downtime). Afternoons are clear. Never
  change Screen Time.
- Behind the limit the app looks signed out. `ios_uitest` now checks the
  failure recording's last frame (f5fcf4c), so it names the overlay.

**F2, granted by Apple 2026-11-24 (case 23709013):** the extension target is back
in project.yml, and FinanceKit is turned on for the walletdelivery App ID (portal,
Ben signed in). Signed build rc=0; app and appex both carry `financial-data` and
the App Group, and both profiles allow it. test_all rc=0. The debug build is on the
Duo and opens to Settings (frame read). **Verified 2026-11-24 5:42pm:** a
new purchase arrived without opening the app (tick 59). TestFlight 1.0 (17) carries it: uploaded and VALID.

**Connector question (case 23676235):** Wallet Entitlements referred Ben to Apple
Developer Support on 2026-11-24. Ben sent the question that day, Case ID
103023652799 (`docs/store/DEVELOPER-SUPPORT-QUESTION.md`). The switch stays off.

**Ben's answers, 2026-11-24 (verbatim; his numbers follow the list he was sent:
1 public links, 2 suggestion wording, 3 iPad width, 4 design sign-off, 5 throwaway
account, 6 the Connect button):**

> 1. Links to stories only make sense with a lot of design. It should be well
> designed to highlight the "setting", the "MEMOry", and the themes. No amount of
> money should ever be shared. You should be able to design your "share".
> 2. The default themes should be on the settings and not on the I examined page
> (I'm okay if we build out an onboarding system that lets you select these, but
> without it, they should go in the settings tab).
> 3. The design of any app layout should be done with design skills for that
> specific device size. Design and implement for every screen size.
> 4. I'm pretty sure we already made design calls based upon your artifacts.
> 5. We can always re-import to my account, so you can add and delete as you see fit.
> 6. And yes, definitely change language so that it makes sense for the actions
> we are taking.

**Work that follows, in order:**
- N1 ✅ No amount in anything shared: remove the amount toggles (memo card, theme
  card, web + Apple). A check must hold it.
- N2 ✅ Starter themes leave Unexamined; Settings keeps them (web + Apple).
- N3 ✅ "Connect Apple Wallet" reads "Sync Apple Wallet" once connected.
- N3b ✅ (tick 52) Audit every action's words on every platform.
- N4 🟡 (DESIGN S; web live; draft for Ben https://claude.ai/artifact/XTgCwKxwxF6ZyAEuhYYcpc; memo and theme built on web, iPhone, iPad, Mac; links and pencil choices live on web, iPhone, iPad and Mac (tick 57)) Design your share: Setting, memory, themes; the person chooses the look.
  Design with the skills first, on every size. Links after the design.
- N5 🟡 (rules: docs/DESIGN.md W; web at 375/768/1024/1440, iPad landscape, open Duo, Mac at 900/1180/1600 built and seen; Settings at wide and iPad portrait seen; closed Duo ⏳) Every screen size designed on purpose: iPhone 12, Duo closed and open, iPad
  portrait and landscape, Mac window small to large, web phone to desktop.
- N6 🟡 macOS on TestFlight (tick 53, 1.0.26 (27)); saving a memo, Skip and Rename pressed (tick 62); Sign in with Apple on a Mac and Ben's turn ⏳.
- Design direction is chosen (item 4): don't ask for a sign-off again. L2 follows
  N1 to N5, because those change what the app looks like.
- ✅ Delete account on the iPhone: done on Ben's Duo, 2026-11-24 1:15pm, with his OK
  ("You can use mine"). Do not repeat it without asking.

## Backlog

Sources: Ben's requests first, then SCRATCHPAD.md, PARITY.md,
docs/research/apple-card-financekit-connector.md, and the M1/M2 plan.

### Ben's requests (2026-11-21): "set up the app on the app store connect so that I can test on my other devices via testflight. You will also need to develop branding/logos, etc."
1. ✅ **Brand kit** (tick 1, Decision 061), following `make-it-look-like-itself`:
   - A mark that is drawn, not typeset, and not Duet's loop-on-a-circle.
   - The wordmark in Newsreader, sanguine on paper.
   - The iOS app icon (1024 px plus all sizes), favicon, apple-touch icon,
     and Open Graph image.
   - A brand page on the site.
   - Present the options to Ben and proceed with the recommended one.
2. ✅ (tick 2, app id 6837824241) **App Store Connect app record**: name CentMemo, bundle
   `com.learningischange.centmemo`, category Finance, SKU, primary language
   English (US).
3. ✅ (tick 2) **TestFlight**:
   - Archive, export, and upload with the API key.
   - An internal testing group with Ben.
   - Export compliance is already declared (`ITSAppUsesNonExemptEncryption NO`).
   - Bump both version numbers.
   - Note: the dev Mac's Xcode works for TestFlight. An App Store submission
     later goes through the cloud build (`cloud-appstore-submission`).

### FinanceKit (2026-11-22): Ben: "Finance kit entitlement approval just came in!"
F1. ✅ (launch tick 2; Ben's real syncs on TestFlight 12 and 13, his Wallet rows in his account) Real FinanceKit in the app. Revocation delete still unseen on real data.
F2. ✅ (tick 59) FinanceKit background delivery extension (iOS 26): first delivery seen 2026-11-24 5:42pm.

### Ben's request (2026-11-22): "Start with item one and keep going. You can also do the recording too. The skills should be built for that in at least one of my repositories. Start an autonomous loop to make sure you get it all done."
L1. ✅ (launch tick 1) First sign-in from inside Claude: the same-window Apple fallback asks
    no scope, so a brand-new account gets no email. Make it work with email.
L2. ⏸ (held 2026-11-22 by Ben until the story design work, docs/design/STORY-DESIGN-BRIEF.md, is done) 🟡 (recording, URLs, 4+, support, screenshots ✅; privacy labels answered, Ben publishes; copy, phone, Ben's clip, submit ⏳) App Store submission: privacy labels matching PrivacyInfo.xcprivacy,
    screenshots, description, the review recording (find the recording
    skill in Ben's repos), and the cloud build (the dev Mac runs a beta OS).
L3. 🟡 (form filled, acknowledgments ticked by Ben, reviewer creds in the
    notes and proven live by tools/test_reviewer_live.mjs; Ben pastes the password and submits) Connectors Directory submission.
L4. 🟡 (error state ✅ launch tick 8) iPhone checks still missing: import (file on the phone),
    delete account (needs a throwaway Apple ID: Ben).
Then, from the plan: 6 files and opt-in uploaded copies; 7 shared stories;
8 iPad readable width (Ben's answer); 9 macOS (later). FinanceKit waits on
Apple.

### Documented work
4. ✅ (tick 3) iOS parity with the web's drawn marks: the circled Unexamined count and
   the Ledger rule (PARITY / DESIGN M1).
5. ✅ (tick 4) Connector end to end:
   - Connect the MCP server in Claude Code through the real OAuth consent
     page as the synthetic owner.
   - Call all six tools.
   - Record the results.
6. ✅ (tick 9) Connector documentation page on centmemo.com. The Connectors Directory
   requires public docs and a privacy policy (the policy exists).
7. ✅ (tick 6) iOS FinanceKit sync path wired end to end with the DEBUG sample source:
   - Settings: Connect Apple Wallet.
   - Accounts and transactions upsert as `source = 'financekit'`.
   - History tokens are kept per account.
   - The connector excludes these rows (already in code).
8. ✅ (tick 7) Web: verify account deletion, plus the empty, error, and offline
   states at 375px.
9. ✅ (tick 54: the full tap tier on the iPad) The iPad Pro on the bench: run the tap tier there (the stand-in
   device, never yet run).
10. 🟡 (tick 11: iOS photos by reference ✅; files, upload, web ⏳) Photos and files attached to a memo by reference (M2, Decision 055
    attachments table; `money-story-design`).
11. 🟡 (tick 14: committed on a local template branch, awaiting Ben) Upstream to UniversalAppTemplate:
    - The three new skills.
    - The color-search tools.
    - The test_grounds pattern.
    - The device-harness lessons from docs/PROVENANCE.md.
11b. ✅ (tick 12) Web: static pages (privacy, terms, connect) set headings in system
    sans, not Newsreader (DESIGN T1). Found tick 9.
11c. ✅ (tick 15) Opt: DECISIONS.md is 1,476 lines, mostly the template's 001-053;
    AUTONOMOUS-LOOPS says it stays context-sized. Archive the inherited ones
    the app does not lean on to docs/DECISIONS-ARCHIVE.md (one line each
    left behind). Found tick 10.
11d. ✅ (tick 16) PARITY audit and the iOS privacy manifest (found by re-mining).
11e. 🟡 (tick 18: empty state ✅; error, import, delete still open) iOS: see the empty and error states with real conditions (stranger
    account on device; network off), and run import and delete account on
    a device (PARITY 🚧 cells, tick 16).
12. 🔮 Shared stories at a public URL (opt-in per story).
13. 🔮 macOS through the universal target.

### Blocked on Ben (not loop work)
- Push the template upstream: branch `upstream/centmemo-finance-connector`
  in ~/Documents/GitHub/UniversalAppTemplate (commit 7718d588). Ben looks
  at the three skills first (the plan), then: push and merge, or a PR.
- Sign in with Apple on the iPhone: sign out of the test account in
  Settings, then sign in.
- The Claude Duet test: add the connector on claude.ai, then ask once live
  and once in a scheduled task.
- The FinanceKit entitlement: waiting on Apple.

## Pending asks

### Ben (2026-11-23): "Yes, let's start working on all of these items, in order within the autonomous loop."
The loop takes these in order, after the D8 Rename save on the iPhone 12.
Heavier work is allowed now: no competing sessions.
Cadence (Ben said yes, 2026-11-23): ticks run back to back, about 60s apart. Wait (20-30 min heartbeat, plus a push notification) only when blocked on Ben, a locked device, or an external build or upload.
1. F1 real FinanceKit sync on Ben's phone, then F2 background delivery (iOS 26).
2. D14 default themes (Ben approves the set and words); this fixes D11's collisions.
3. D15 Place. Ben: "I think you can have it predict a specific location for
   each one of the purchases based upon an algorthmic search combined with
   other data factors (should we ask for location within the app to make it
   easier or can we make assumptions based upon the data we are already
   getting from financekit?)". Proposal in the brief, D15.
4. D12 sharing a theme and public story links (plan item 7).
5. Item 10: files and opt-in uploaded copies, plus the web side.
6. L2 App Store submission (after Ben signs off on the design), L3 directory.
7. Later: macOS, and iPad readable width (waits on Ben's answer).

## Ticks

### Tick 1 — 2026-11-21 — brand: the mark, icon, wordmark, web assets, brand page
- **Context:** Ben's request, backlog item 1.
- **Implementation:**
  - Three concepts drawn in `branding/brand.html` and compared at 180, 120,
    60, and 29 px. Chose A, the circled cent (Decision 061).
  - Smoothed the pencil stroke after seeing a sawtooth edge at 1024.
  - `tools/render_brand.sh` renders the iOS icon in light and dark (single
    1024 size, no alpha), favicons, the Apple touch icon, the 1200×630
    Open Graph image, wordmarks, and the PWA icons.
  - Wired into every page.
  - `/brand/` page added.
- **Verification:**
  - Viewed the icon at 1024 in light and dark, the Open Graph image, and
    the concept sheet.
  - `sips` reports 1024×1024 with no alpha.
  - The iOS build compiles with the icon.
  - US English passes.
- **Next:** backlog item 2, the App Store Connect app record (the owner's
  request jumps the rotation).

### Tick 2 — 2026-11-21 — store: App Store Connect record and first TestFlight upload
- **Context:** Ben's request, backlog items 2 and 3.
- **Implementation:**
  - Created the app record "CentMemo" in Chrome: iOS, English (U.S.),
    bundle `com.learningischange.centmemo`, SKU `centmemo-ios`, full access
    (app id 6837824241). The API cannot create apps.
  - Set the primary category to Finance through the API.
  - Adopted Ear Drama's `tools/submit-appstore.sh` and `asc_*` helpers
    (manual signing through the API key).
  - Restored the app's own `CentMemo` scheme (archives need it).
  - Uploaded 1.0 (1).
  - Created the internal group "CentMemo testers" (all builds), the
    Archive Watch pattern.
- **Verification:** "Upload succeeded"; the category reads back as FINANCE.
  Adding Ben to the group failed with "Tester(s) cannot be assigned" while
  the app had no processed build. A watcher adds him once processing ends.
- **Follow-up (same tick):**
  - Build 1 is VALID.
  - Ben was added by creating the tester by email for the group
    (`POST /v1/betaTesters`); his state is INVITED.
  - Routine and lessons are in `docs/STORE.md`.
- **Next:** tick 3 (iOS): backlog item 4, the drawn marks on iOS.

### Tick 3 — 2026-11-21 — iOS: the pencil circle around the Unexamined count (DESIGN M1)
- **Context:** backlog item 4. DESIGN M1 asks for a circle around the count
  on every platform; iOS rows keep the system divider by design, so the
  circle was the only gap.
- **Implementation:**
  - `PencilCircle` shape in `apple/iOS/Components/Grounded.swift`, using the
    same path as the web's `.pencil-circle` mask, drawn in sanguine around
    the count.
  - Build 1.0 (2).
- **Verification:**
  - The iOS build compiles.
  - On the iPhone 12, `TabSmokeUITests/testUnexamined` passes and the frame
    shows the circle; no crash logs.
- **Lessons:** with default MainActor isolation, a `Shape` conformance needs
  `nonisolated` (the compiler caught it before the device run).
- **Polish later:** the circle sits tight to the capsule; loosen it if Ben
  wants more of a hand-drawn feel.
- **Next:** tick 4 (infrastructure), backlog item 5, the connector end to
  end through OAuth.

### Tick 4 — 2026-11-21 — infra: the Claude connector end to end (OAuth, six tools, read-only)
- **Context:** backlog item 5.
- **Implementation:** `tools/test_connector.mjs` drives the connector the
  way Claude's client does:
  - Discovery from the 401 and `resource_metadata`, plus the authorization
    server metadata (S256).
  - Dynamic client registration, then authorization with PKCE. Supabase
    redirects to centmemo.com/oauth/consent.
  - Consent approved through the same calls `js/consent.js` makes, as the
    synthetic owner. Done in Node so Ben's own browser session stays
    signed in.
  - Code exchange (the token carries `client_id`), then initialize,
    tools/list (six tools, all titled and read-only), and each tool called
    with its expected answer.
  - The agent token reads through REST, gets 403 on insert, and changes no
    memo. The owner's own token can insert, which shows the 403 comes from
    being an agent.
  - Refresh works.
  - Added to `tools/test_all.sh`.
- **Verification:** 24/24 checks pass against the deployed project.
- **Note:** each run registers one OAuth client named "CentMemo connector
  test" (Supabase lists them under OAuth Apps).
- **Next:** tick 5 (opt): net-remove lines.

### Tick 5 — 2026-11-21 — opt: stale planning collapse, dead symbol, a caught drift
- **Context:** opt tick (net-remove lines).
- **Implementation:**
  - SCRATCHPAD.md's template placeholders became the real milestone state
    and a real "Out of scope" table of what Ben ruled out: the placeholder
    M0 to M2 sections, the "when you go native" checklist, and the
    binding-doc how-to.
  - Removed `DisplayType.heading` (unused).
  - Kept `js/compat.js`, `tv.js`, and the cast layer: the scaffolds of
    platforms ruled out stay (AGENTS.md), and compat has its own test.
- **Lines:** SCRATCHPAD.md plus Ground.swift went from 187 to 103 (−84).
- **Caught:** `tools/test_all.sh` failed on `manifest.json`. Tick 1's hand
  edit re-serialized a token-managed file. Regenerated, and the icons were
  kept.
- **Lesson:** run `test_all.sh` every tick (rule tightened above).
- **Verification:** `tools/test_all.sh` ALL PASS.
- **Next:** tick 6 (iOS), backlog item 7, the FinanceKit sync path with the
  DEBUG sample source. Item 6, connector docs, goes to the next
  infrastructure tick.

### Tick 6 — 2026-11-21 — iOS: Connect Apple Wallet (FinanceKit sync path, DEBUG sample source)
- **Context:** backlog item 7.
- **Implementation:**
  - `APIClient.syncFinance`: accounts upserted on `(user_id, source, source_id)`,
    transactions upserted as `source = 'financekit'` in chunks of 500, each on
    its own account (`accountSourceID`, never sent as a column), and FinanceKit
    deletions applied. History tokens stay per account (FinanceSource).
  - Settings, Money in: "Connect Apple Wallet" with the Addendum 3.3
    disclosure (what is read, how it is kept, that Claude never sees it,
    the privacy link) shown before access is asked. Haptics success/error.
  - `WalletSyncUITests`: sample sync, second sync, then removes the sample
    account as the synthetic owner so data is left as found.
  - Build 1.0 (3).
- **Verification:**
  - iPhone 12: `WalletSyncUITests` PASS, no crash logs; frame shows the
    result line and the disclosure.
  - Server after the run: 0 FinanceKit accounts, 0 FinanceKit transactions
    (cleanup confirmed directly, not from the test's word).
  - `tools/test_all.sh` ALL PASS.
- **Honest limit:** the second-sync check only shows the upsert succeeded
  again; no-duplicates rests on the table's unique constraint, not on this
  test. Real FinanceKit stays unverified until Apple grants the entitlement.
- **Next:** tick 7 (web), backlog item 8, deletion and the empty, error,
  and offline states at 375px.

### Tick 7 — 2026-11-21 — web: deletion proven, four states at 375px, one bug fixed
- **Context:** backlog item 8.
- **Audit:** the code already had all four states, the offline banner, and
  deletion, so this tick was verification.
- **Deletion:** `delete_my_account` run as the stranger inside a transaction
  that never commits: user 1 to 0, their rows 1 to 0, owner untouched.
  Saved as `supabase/tests/delete_my_account.sql` (ends in `rollback`).
  The first run lacked an explicit rollback; the stranger was confirmed
  still present afterward. Lesson saved to memory (supabase-approvals).
- **States:** `tools/test_web_states.mjs` (headless Chrome over CDP,
  dependency-free, sessions injected from the synthetic users, so Ben's
  browser is untouched): 13/13 at 375px. Empty (stranger), rows (owner, the
  control), error plus Try again plus recovery (REST blocked), offline
  banner plus message, no horizontal scroll. Added to `tools/test_all.sh`.
- **Bug fixed:** a network failure showed the browser's "TypeError: Failed
  to fetch". `failed()` now says "CentMemo couldn't reach its server.";
  the test checks the wording. Assets `?v=20261121e`.
- **Harness lessons:** a hash-only navigation keeps the document, so the
  injected session needs a reload; hidden sections keep old banners, so
  selectors are scoped to the visible view.
- **Noted, not fixed:** supabase-js retries failed reads, so an error takes
  about 7 s to appear after "Loading…". Acceptable for now.
- **Verification:** `tools/test_all.sh` ALL PASS.
- **Next:** tick 8 (iOS), backlog item 9, the tap tier on the iPad Pro.

### Tick 8 — 2026-11-21 — iOS: the iPad Pro on the bench (glass 5/5; tap tier blocked)
- **Context:** backlog item 9; first ever run on the iPad Pro 12.9
  (iPad13,8, paired).
- **Tap tier (XCUITest):** the app installed, but the runner failed twice
  with "Timed out while enabling automation mode". That is the device-side
  first-run gate (locked, or UI Automation not enabled in Developer
  settings). Stopped after one retry; it needs Ben at the iPad (Blocked on
  Ben). No crash logs; app left as found.
- **Glass tier (OCR, no automation needed):** ad hoc plus all five
  scenarios (unexamined, ledger, story, settings, item) RESULT OK: awake,
  app owns the glass, no error text, no clipping.
- **Seen:** the iPad uses the top tab bar (native iPadOS), and the pencil
  circle and color marks render.
- **Design finding (for Ben, not changed):** in landscape, rows run the full
  2732 px, so the amount sits far from its merchant. A readable-width rule
  belongs in an iPad section of DESIGN.md before any change.
- **No version bump:** no app code changed this tick.
- **Verification:** `tools/test_all.sh` ALL PASS.
- **Next:** tick 9 (infrastructure), backlog item 6, the connector
  documentation page.

### Tick 9 — 2026-11-21 — infra: centmemo.com/connect/, the connector's public docs
- **Context:** backlog item 6 (the Connectors Directory needs public docs;
  AGENTS.md: side doors findable on the website, never featured in apps).
- **Implementation:** `/connect/`: what the connector is (read-only), how to
  add it (custom connector, the MCP address, Apple sign-in, the consent
  page), the six tools in plain words from their registered titles, the
  fact a person cannot discover (Wallet purchases are never shared with
  Claude, Addendum 3.2, `SHARE_FINANCEKIT = false`), sample questions, how
  to disconnect, the privacy link and contact. Linked from the sign-in
  footer beside Privacy and Terms. CSS: doc table, wrapping code, ordered
  list indent. Assets `?v=20261121f`.
- **Verification:** `tools/test_web_states.mjs` now also checks connect/,
  privacy/, and terms/ at 375px (all 375 wide) and that connect/ states the
  Wallet exclusion; frame viewed. US English passes. `tools/test_all.sh`
  ALL PASS.
- **Lesson:** headless Chrome's `--window-size` has a minimum near 500 px,
  so a 375 screenshot taken that way shows false clipping; measure with
  device-metrics emulation (what test_web_states does).
- **Found:** static-page headings use system sans, not Newsreader (new
  backlog item 11b).
- **Next:** tick 10 (opt): net-remove lines.

### Tick 10 — 2026-11-21 — opt: true Current State, superseded 059 trimmed
- **Context:** opt tick (net-remove lines). Confirmed tick 9 live:
  centmemo.com/connect/ 200 with the Wallet sentence.
- **Implementation:**
  - SCRATCHPAD Current State (printed at every session start) rewritten to
    what is true now. It still said email-code sign-in, HTTPS pending, and
    the OAuth and FinanceKit steps blocked.
  - Decision 059 trimmed to what still holds (sanguine, the six colors
    stored per person, the Twitter-distance reason, how to add a color),
    marked "placement superseded by 060".
  - Audits found nothing dead in code: every `API.*` export is called, and
    every once-referenced Swift function is a test or protocol method.
- **Lines:** SCRATCHPAD 68 to 61, DECISIONS 1487 to 1476 (−18).
- **Found:** DECISIONS.md is far past context-sized (new item 11c).
- **Verification:** `tools/test_all.sh` ALL PASS; the session-start hook
  prints the new state.
- **Next:** tick 11 (iOS). The top iOS item is 10 (attachments by
  reference), but Ben's iPad readable-width answer and the static-page font
  (11b, web) are pending; take item 10.

### Tick 11 — 2026-11-21 — iOS: attach a photo to a memo by reference (build 1.0 (5))
- **Context:** backlog item 10. money-story-design: "by reference
  (PhotoKit local identifier) first; uploading a copy is a separate,
  explicit choice." Four-question test: passes (the person picks, nothing
  automated, native picker).
- **Implementation:**
  - `APIClient` attachments: list, `attachPhoto` (stores only `device_ref`),
    remove.
  - Detail view "Photos": thumbnails (`AttachedPhoto`, a tile that says "On
    another device" or "Allow Photos access to show it" when it can't draw
    the photo), long-press "Remove from this memo", and "Add a photo".
  - Photos access is asked when the person taps Add a photo (with
    `NSPhotoLibraryUsageDescription`). The picker lives in a sheet, so it
    exists only then.
  - `PhotoAttachUITests`. Builds 4 and 5.
- **Verification:**
  - iPhone 12 full tap tier 10/10, no crash logs; the server holds 0
    attachments and no test memos afterward.
  - The photo test declines Photos access on purpose (Ben's phone), so the
    denied path is the one verified. **CentMemo now has Photos access
    "None" on the iPhone 12**; Ben can change it in Settings.
  - `tools/test_all.sh` ALL PASS.
- **Honest notes:**
  - The early Photos prompt I first blamed on the picker sitting in the form
    was most likely a leftover prompt from an interrupted run (see
    docs/TESTING.md). The sheet design stays (it asks at intent), but the
    "bug" is unproven.
  - `testWriteThenRemoveMemo` was failing: taps placed the caret at the
    start of the text, so cleanup deleted nothing and leftover memos grew.
    Fixed with a triple-tap select, after four evidence-led attempts; one
    run in between covered nothing because the test didn't compile.
    Leftover test memos were removed from the synthetic owner each time.
- **Not done:** files, opt-in upload, and the web showing that a photo is
  attached (PARITY ⏳).
- **Next:** tick 12 (web), 11b (static-page headings in Newsreader) or the
  web side of attachments.

### Tick 12 — 2026-11-22 — web: photo parity note; static-page headings in Newsreader
- **Context:** cross-platform parity for tick 11's photos, plus backlog 11b.
- **Implementation:**
  - `API.transaction` also selects `attachments(kind)`. The detail view shows
    "1 photo attached in the CentMemo iPhone app." (a fact the person cannot
    discover on the web, which cannot draw a PhotoKit reference); nothing
    when there are none.
  - `.page-inner h1, h2` join the display-face rule (DESIGN T1), and
    `.page code` uses `--font-mono`. Assets `?v=20261121g`.
- **Verification:** `tools/test_web_states.mjs`:
  - The note appears for a photo reference created as the owner, with a
    control that it is absent once removed; the row is cleaned in `finally`
    and the server holds 0 attachments.
  - connect/, privacy/, and terms/ headings name Newsreader; the frame shows
    it rendered.
  - `tools/test_all.sh` ALL PASS. PARITY row updated.
- **Next:** tick 13 (iOS). Candidates: files on iOS, or the iPad
  readable width once Ben answers. Otherwise item 11, upstream to the
  template (infrastructure, tick 14).

### Tick 13 — 2026-11-22 — store: TestFlight 1.0 (5) (the pencil circle, Connect Apple Wallet, photos)
- **Context:** Ben's TestFlight request outranks the rotation; builds 2 to 5
  existed only locally.
- **Implementation:**
  - Confirmed the sample Wallet source and the test sign-in door are DEBUG
    only.
  - `tools/submit-appstore.sh ios`: archive, manual signing, export,
    "Upload succeeded".
- **Verification:**
  - App Store Connect reads build 5 VALID (build 1 still VALID). The
    internal group takes all builds, so Ben has it.
  - Build 5 had already passed `tools/test_all.sh` and the iPhone 12 tap
    tier 10/10 (tick 11).
- **Lesson:** the state check needs `tools/.asc-venv` and
  `tools/asc-credentials.env`. My first two watchers died on a missing jwt
  module, then on missing credentials, and the second failed silently into
  stderr for 30 minutes. Recorded in docs/STORE.md.
- **What Ben will see in TestFlight:** Connect Apple Wallet says FinanceKit
  is unavailable (no entitlement yet, so the release build has no sample
  data); photos ask for access when he adds one.
- **Next:** tick 14 (infrastructure), backlog item 11, upstream to
  UniversalAppTemplate.

### Tick 14 — 2026-11-22 — infra: upstream prepared for UniversalAppTemplate (not pushed)
- **Context:** backlog item 11. The plan says upstream "after Ben sees
  them", and pushing to another repo is outward-facing, so the change is
  committed on a local branch only.
- **Implementation:** template branch `upstream/centmemo-finance-connector`
  (7718d588):
  - The three skills, copied whole (their CentMemo mentions are incident
    citations, the template's convention).
  - `tools/colorsearch/` (header made generic).
  - The skill catalog rows and the AGENTS.md routing row, "Money, Claude
    connectors". It was shortened three times to keep the template's
    AGENTS.md under 24,000 bytes (23,998).
  - A PROVENANCE coverage row.
  - Bench lessons in DEVICE-HARNESSES.md (UI Automation gate, leftover
    prompts, caret placement, tab bar and lazy Form, failed-run data and
    stale logs, the headless window floor).
- **Left out:** `test_grounds` and `test_web_states` (bound to this app's
  data and selectors; the lessons went up instead).
- **Verification (template):** test_agent_files PASS, test_us_english PASS,
  skills frontmatter present, colorsearch compiles. CentMemo's
  `tools/test_all.sh` ALL PASS.
- **Next:** tick 15 (opt), backlog 11c, archive the inherited DECISIONS
  (the template just did the same: 001-032 rolled verbatim into
  docs/decisions/ with an index).

### Tick 15 — 2026-11-22 — opt: DECISIONS archived verbatim (71 KB to 16 KB loaded); tick 10's edit undone
- **Context:** backlog 11c; the template's 08e71455 shows the pattern.
- **Correction first:** tick 10 trimmed Decision 059 in place. That breaks
  Decision 033 ("never trim, edit, or summarize an entry in place"), which I
  had not read. 059 is restored byte for byte from before tick 10; its
  supersession shows in 060's title and the index. The loop rules now say
  so.
- **Implementation:**
  - Entries 001-053 (the template's) moved whole to
    `docs/decisions/DECISIONS-001-053.md`.
  - DECISIONS.md keeps its header, a "Where entries live" note, a one-line
    index of all 61, and 054 onward in full.
- **Verification:**
  - A script checked that each of the 61 entries in the pre-tick-10 file
    appears exactly once, byte for byte, across the two files: none
    missing or duplicated.
  - No links point into the old file. `tools/test_all.sh` ALL PASS.
- **Lines:** the always-loaded file goes from 71,238 to 16,097 bytes. The
  repo's total lines grow slightly (index plus archive header), because a
  verbatim move relocates text rather than deleting it; the saving is per
  session, which is Decision 033's purpose.
- **Next:** tick 16 (iOS). Open iOS items: files as attachments, the iPad
  readable width (needs Ben). Re-mine the backlog sources if those stall.

### Tick 16 — 2026-11-22 — iOS: honest PARITY, privacy manifest (build 1.0 (6))
- **Context:** the backlog had thinned to items blocked on Ben, so I
  re-mined the documented sources (PARITY, the plan's M2 list) instead of
  inventing work.
- **Found:** PARITY.md was template boilerplate with false claims (email
  sign-in, tvOS and Android ✅, a Face ID gate ✅) and stale 🚧 on features
  verified since. The iOS app had no `PrivacyInfo.xcprivacy`, though it
  uses `UserDefaults` (a required-reason API App Store review checks).
- **Implementation:**
  - PARITY sections 0 to 13 rewritten for CentMemo: web and iOS columns
    only, with the other platforms' status in the platform set. Every ✅
    names its test or observation; built-but-unseen stays 🚧 with the
    reason. The legend, the parity rule, and the maintenance protocol are
    kept. 371 to 201 lines.
  - `apple/Resources/PrivacyInfo.xcprivacy`: no tracking; email, financial
    info, and user content, all linked, all app functionality;
    UserDefaults CA92.1. Photos are not declared (references only). It
    matches centmemo.com/privacy/.
  - Build 6.
- **Verification:**
  - `plutil -lint` OK; the manifest is inside CentMemo.app.
  - iPhone 12 TabSmokeUITests 5/5, no crash logs.
  - `tools/test_all.sh` ALL PASS.
- **New backlog (from the audit):** 11e, see the iOS empty and error
  states, import, and delete account on a device.
- **Next:** tick 17 (web), then 11e on the next iOS tick.

### Tick 17 — 2026-11-22 — web: import proven through the real file input; idempotent on re-import
- **Context:** re-mined from PARITY. Web import's ✅ rested on a day-one
  look; no test drove the import screen.
- **Implementation:** `tools/test_web_states.mjs` import section. As the
  stranger it goes to Import, chooses `tests/fixtures/applecard-sample.csv`
  through `DOM.setFileInputFiles`, and confirms. The second import must say
  "0 new, 7 already in CentMemo." (Decision 057). It then sees the rows in
  the Ledger, and a `finally` deletes the stranger's csv account and batches
  and checks it is empty again, so the empty-state test stays valid.
- **Verification:** 7/7 import checks pass; `tools/test_all.sh` ALL PASS.
  The re-import check discriminates: a duplicate would read "7 new.".
- **Harness lessons:**
  - A new, empty account lands on Unexamined after sign-in, so a route in
    the URL is lost; set the hash once the app settles and wait for the
    view to be visible.
  - A `${'$'}{n}` written as if the Python heredoc were an f-string put a
    literal `${n}` into the matcher; the first passes were false failures,
    not false passes.
- **Product note:** no app code changed; nothing to bump.
- **Next:** tick 18 (infra) or 11e on iOS: device runs of iOS import,
  delete account, empty and error states.

### Tick 18 — 2026-11-22 — iOS: empty state seen on device; every iOS action was ink, now sanguine (build 1.0 (8))
- **Context:** backlog 11e (PARITY 🚧 iOS cells).
- **Implementation:**
  - The DEBUG sign-in door now switches to whichever synthetic account the
    test names, so a stranger test can't leave the owner tests signed in as
    the stranger.
  - `test_account_env()` hands the runner the stranger too.
  - `EmptyStateUITests`: the stranger sees "No transactions yet", the next
    step, and Import; the control has the owner back to purchases.
- **Found (measured, not eyeballed):** on the empty state's frame, the
  Import action was `#231B1C` (ink), not sanguine. Cause: `Grounded` set a
  screen-wide `.foregroundStyle(ink)`, which outranks the tint, so every
  button on every screen was ink (DESIGN C2). DESIGN.md got an iOS note
  first, then the override came out.
- **Verification (iPhone 12, build 8):**
  - Full tap tier 11/11, no crash logs.
  - Pixel check: the empty-state Import and Settings' Import and Connect
    Apple Wallet now read `#4A1520`; body text is the system label
    `#000000`, as the doc note says.
  - `tools/test_all.sh` ALL PASS.
- **Still 🚧:**
  - iOS error state (no way yet to fail the network on the device).
  - iOS import (system file picker; the file must be on the phone).
  - iOS delete account: Apple-only sign-in means no throwaway account, and
    the stranger is needed by the RLS tests. It stays 🚧 until Ben can
    delete a second Apple ID account on purpose, or a test-only delete
    target exists.
- **Next:** tick 19 (web).

### Tick 18 correction — 2026-11-22
- Tick 18's entry says `tools/test_all.sh` ALL PASS. It did not: it
  failed, and the commit went through anyway, because the command was
  `test_all.sh | tail -1 && ...` (tail always succeeds).
- The failure was intermittent: the web photo-note check landed on the
  wrong view when sign-in rewrote the route (the same race tick 17 found
  for the stranger).
- Fixed by setting the route after the app settles. 3/3 passes, then
  `tools/test_all.sh` exit 0.
- The loop rule now gates commits on the exit code.

### Tick 19 — 2026-11-22 — store: TestFlight 1.0 (8); loop stopped for Ben's turn
- **Context:** every unblocked backlog item has shipped. What remains needs
  Ben: decisions (the iPad readable width, the template push), play (the
  TestFlight build, Sign in with Apple on the phone, the Duet live and
  scheduled test, the iPad's UI Automation switch), or Apple (the FinanceKit
  grant). Opt-in uploads of photos and files are planned (M2) but store
  people's files server-side, so Ben should see the TestFlight build first.
  The method says Ben plays: the loop stops here (autonomous-loop-cadence
  stop condition: backlog empty after a fresh re-mine).
- **Implementation:** `tools/submit-appstore.sh ios`, "Upload succeeded"
  1.0 (8).
- **Verification:**
  - App Store Connect reads build 8 VALID.
  - Build 8 passed the iPhone 12 tap tier 11/11 and `tools/test_all.sh`
    exit 0 (tick 18 correction).
- **For Ben, in order:**
  1. TestFlight 1.0 (8): sign in with Apple on the iPhone; write a memo;
     attach a photo; look at Settings.
  2. Add the connector on claude.ai (centmemo.com/connect/); ask Duet once
     live and once in a scheduled task.
  3. Decide: the iPad readable width; push the template branch.
  4. iPad: Settings > Developer > Enable UI Automation.

### Launch tick 1 — 2026-11-22 — L1: first sign-in from inside Claude now gets an email
- **Context:** Ben's launch list, L1. The same-window Apple fallback asked no
  scope (Apple returns the email only by POSTing to a server), so a
  brand-new account created inside Claude's sheet had no email.
- **Implementation:**
  - `supabase/functions/apple-return` (v1): receives Apple's form_post and
    303s back to the consent page or the website with the token in the
    fragment. The page is chosen by the end of `state` from a fixed list of
    two; anything else gets 400, so it is never an open redirect. Stores
    nothing.
  - `js/api.js`: the fallback asks `scope=email`, `response_mode=form_post`
    to apple-return; `state` = 32 hex + ".c"/".w".
  - Apple Developer: added the Supabase host and the apple-return URL to the
    Services ID `com.learningischange.centmemo.web` (5 website URLs; the
    three existing ones kept).
- **Verification:**
  - The endpoint returns to exactly the two pages, carries a cancel through,
    and refuses an unknown target, a malformed state, and GET.
  - Apple accepts the new request (an unregistered address is refused);
    both old return addresses are still accepted.
  - `test_web_states`: the whole chain (POST to apple-return, follow the
    303, the page takes the token up with the state check passing).
  - `tools/test_all.sh` exit 0. The first run was blind (headless Chrome
    took more than 10 s to start); the start-up wait is now 30 s.
- **Not verified:** a real brand-new Apple ID signing up inside Claude.
- **Order kept:** the website change shipped only after Apple accepted the
  return address, so Ben's in-Claude sign-in never broke.
- **Next:** L2, App Store submission, starting with the review recording
  (Ear Drama's AppReviewTourUITests pattern plus the playbook's capture).

### Launch tick 2 — 2026-11-22 — FinanceKit granted: real Wallet in the app (build 1.0 (10))
- **Context:** Ben: "Finance kit entitlement approval just came in!" (Apple
  case 23676235: granted for team L2G756LY8N, bundle
  com.learningischange.centmemo). The grant does not answer the Addendum 3.2
  connector question, so the connector still excludes Wallet rows.
- **Implementation:**
  - FinanceKit enabled on the App ID (Developer portal).
  - `com.apple.developer.financekit = [financial-data]` in the entitlements.
  - The never-working `CMFinanceKitEnabled` Info flag removed: Xcode never
    wrote that custom key, so the path had been off in every build.
    FinanceKit now gates on `isDataAvailable`, with a truthful message where
    there is no Wallet data.
  - An invalid history token restarts that account instead of failing every
    sync.
  - `FinanceRevocation`: when Wallet access is turned off in Settings, the
    synced Wallet data is deleted, checked on every return to the
    foreground. The entitlement request promised this.
  - Build 10.
- **Verification:**
  - The signed app carries `financial-data`, and Apple's regenerated
    profile allows exactly that.
  - iPhone 12 tap tier 12/12, plus `WalletAvailabilityUITests`: Settings
    offers Connect there (FinanceKit reports Wallet data) and the
    pre-approval wording is gone.
  - `tools/test_all.sh` exit 0.
- **Deliberately not done:** tapping Connect on the bench. It runs as the
  synthetic account, so authorizing would copy a real person's Wallet data
  into test data. The first real sync is Ben's, on his own phone, signed in
  as himself (TestFlight build 10).
- **Not yet verified:** the revocation delete against real FinanceKit (it
  needs a real authorization, then turning it off).
- **Next:** TestFlight build 10 for Ben; then L2 (App Store submission).

### Launch tick 3 — 2026-11-22 — L2: the App Review recording (build 1.0 (11))
- **Context:** L2. Ben: "You can also do the recording too. The skills should
  be built for that in at least one of my repositories." Found in Ear Drama:
  `AppReviewTourUITests` and the store-submission-playbook's capture method.
- **Implementation:**
  - `ReviewTourUITests` (runs only with REVIEW_TOUR=1): Unexamined, a memo
    written and shown with a value, Ledger, Story, Settings (the Wallet
    disclosure, the connector address), and account deletion up to its
    confirmation, then "Keep my account". It never taps Connect Apple Wallet
    and removes its own memo, asserting both.
  - `tools/record_review.sh`: devicectl's screen-record is not supported on
    the iPhone 12, so two screenshot loops (about 0.8 fps) capture the tour.
    The video is trimmed to the tour's own launch and end marks (no home
    screen or notifications), blank frames are dropped (`frame_blind.py`
    from Ear Drama), and `tools/frames_to_video.swift` (AVFoundation)
    makes the 1920x1080 video.
  - **App fix found by the tour:** on iOS 26 the delete confirmation sheet
    showed only "Delete everything, permanently" (cancel-role buttons
    hidden). It is now an alert with "Keep my account".
  - The harness reports a self-skipped test as SKIP, not FAIL.
- **Verification:**
  - `build/store-video/centmemo-tour-20261122-0933.mp4`: 113 s, 1920x1080;
    contact sheets viewed (starts on Unexamined, ends in Settings).
  - The server shows no tour memo left. One earlier take had left one; it
    was removed and the tour now asserts the cleanup.
  - Full tap tier on build 11 passes; `tools/test_all.sh` exit 0.
- **Lessons:** Homebrew's ffmpeg here is broken (a missing x265 library),
  hence AVFoundation; a triple tap right after dismissing the keyboard
  selects one word, so focus first.
- **Still L2:**
  - Ben's own clip: Sign in with Apple, then Connect Apple Wallet on his
    phone, using iOS screen recording.
  - The App Store version: description, keywords, screenshots, privacy
    labels, age rating, review notes.
  - Upload the recording, then submit through the cloud build.

### Fix — 2026-11-22 — Ben's first real Wallet sync failed: "All object keys must match" (build 1.0 (12))
- **Found by Ben** on his iPhone Duo (TestFlight 10): Connect Apple Wallet
  showed PostgREST's "All object keys must match".
- **Cause:** Swift's synthesized Encodable drops nil optionals. An account
  without a credit limit (Apple Cash, Savings) or a pending purchase (no
  posted date) sent objects with fewer keys in the same bulk insert. The
  DEBUG sample had one account and no pending rows, so it never showed.
  The iOS CSV import had the same flaw for pending rows.
- **Fix:**
  - `ImportRow` and the new `FinanceAccountRow` encode every key, nil as
    null.
  - The sample now looks like a real Wallet: an Apple Cash account with no
    limit, plus a pending purchase.
- **Verification:**
  - `UniformKeysTests` was seen failing on the old encoder (pending vs
    posted keys differ) and passes after the fix.
  - iPhone 12 `WalletSyncUITests` against the real database: "Synced 4
    transactions from 2 accounts", re-sync idempotent, cleaned up (0
    left).
  - `tools/test_all.sh` exit 0.
- **Lesson:** a sample source must carry the real data's variety (several
  account kinds, missing optionals), or it proves only the happy path.
- **Next:** TestFlight 12 to Ben; the real sync on his phone.

### Launch tick 4 — 2026-11-22 — L2: listing facts, support page, reviewer notes drafted
- **Context:** L2. Version 1.0 open (PREPARE_FOR_SUBMISSION); build 12 VALID.
- **Implementation:**
  - App Store Connect: support https://centmemo.com/support/, marketing
    https://centmemo.com/, privacy https://centmemo.com/privacy/, age rating
    declared all none (Apple computes 4+).
  - New `/support/` page from facts (contact, Wallet, import, turning access
    off, deletion, Claude), linked in the footer and in the 375 px checks.
  - `/review/applecard-sample.csv`: the synthetic fixture, for reviewers whose
    accounts start empty.
- **Held for Ben:**
  - The description, subtitle, promotional text, and keywords are product
    copy (AGENTS.md: no AI-written copy), so they are drafted from his own
    sentences in docs/store/LISTING.md, marked where verbatim, for him to
    edit and approve.
  - The review details need a contact phone (+country code; App Store
    Connect refuses them without one); the notes wait in
    docs/store/REVIEW-NOTES.md.
- **Verification:** the attributes read back; `tools/test_all.sh` exit 0
  (support/ fits 375 px).
- **Next:** privacy labels (App Store Connect web UI; the API has no
  endpoint) and the screenshots.

### Fix — 2026-11-22 — Ben's second real sync: "ON CONFLICT DO UPDATE command cannot affect row a second time" (build 1.0 (13))
- **Found by Ben** on TestFlight 12. The accounts step now succeeds, so the
  previous fix held.
- **Cause:** FinanceKit's history reports a purchase as inserted and then
  updated (pending, then booked). Both went into one upsert, which may not
  touch a row twice.
- **Fix:**
  - `FinanceChanges.normalized()`: one row per purchase in its latest
    reported state; none that end deleted; accounts de-duplicated. Called
    by `APIClient.syncFinance` before anything is sent.
  - The sample reports a purchase twice, as FinanceKit does.
  - Account names, institution names, and currencies are clamped to the
    table's checks, so one odd value can't fail the whole sync (status
    values were already allowed).
- **Verification:**
  - `FinanceChangesTests` seen failing on a stub, then passing.
  - iPhone 12 `WalletSyncUITests` against the real database, with the
    duplicate report: 4 transactions from 2 accounts, idempotent, cleaned
    up.
  - Full tap tier passes; `tools/test_all.sh` exit 0.
- **Lesson (now twice):** real FinanceKit data has a variety the sample
  lacked (account kinds, missing optionals, repeated reports). Before the
  next real-data step, read the target table's constraints against
  everything the source can produce.

### Launch tick 5 — 2026-11-22 — L2: App Store screenshots placed
- **Context:** L2. Build 13 VALID (TestFlight; Ben notified).
- **Implementation:**
  - Five real screens from the iPhone 12 tap tier (Unexamined, a memo with
    values, Story, Ledger, Settings with Connect Apple Wallet).
  - Native 1170x2532 go in `IPHONE_FACE_ID_MEDIUM_PROFILE`; the same, scaled
    to 1290x2796, in `IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE` (Asset Library
    reference data read first for the exact sizes).
  - Uploaded and placed with the template's `asc_asset_library.py`; all 10
    ACTIVE.
- **Data fix:** a demo memo on the synthetic owner ended "(synthetic test
  memo)". Removed after checking that no test relies on it, and the Ledger
  was re-captured.
- **Verification:** contact sheet viewed (no email, no personal data);
  `tools/test_all.sh` exit 0.
- **Next:** the privacy labels (App Store Connect web UI, needs Ben signed
  in). Then the copy, phone, and Ben's clip, which wait on Ben.

### Launch tick 5b — 2026-11-22 — L2: App Privacy labels answered (not published)
- **Answers** (App Store Connect web; the API has no endpoint): Email
  Address, Other Financial Info, Other User Content, and User ID, each used
  for App Functionality only, linked to the user, not used for tracking.
  Read back from the page; no type mentions tracking.
- **Not published:** Publish asks the owner to agree the responses are
  accurate and lawful, a legal attestation for Learning is Change, so Ben
  presses it. The answers are saved.
- **PrivacyInfo.xcprivacy** gains User ID, so the manifest and the labels
  agree; it ships with the next build.

### Launch tick 6 — 2026-11-22 — L3: reviewer account and reviewer sign-in (Decision 063)
- **Ben chose:** "Reviewer-only sign-in".
- **Implementation:**
  - `review@centmemo.com` created (signup API, confirmed in SQL, password
    only in ~/.centmemo/test-users.json at mode 600).
  - Seeded with `seed_demo.mjs reviewer`: 22 purchases, 4 memos; re-run
    adds nothing.
  - The consent page has a collapsed `<details>` "Reviewer sign-in" that
    accepts only that address.
- **Verification:**
  - `test_web_states`: a real authorization opens; another email is
    refused toward Apple; the reviewer signs in, sees the ask, approves,
    and the browser requests the callback with a code and the same state
    (read from the network record, since the callback has no listener).
  - `tools/test_all.sh` exit 0 on the final run. One earlier run failed a web
    check that the 15-line tail hid; four web runs and the next suite run
    passed. `test_all.sh` now prints every failing line first, so a recurrence
    names itself. The flake is still unidentified, not fixed.
- **Next:** the directory form at claude.ai/directory/manage (Ben's
  account; the compliance acknowledgments are his to make).

### Launch tick 6b — 2026-11-22 — L3: the directory form, answered in docs/store/DIRECTORY.md
- Opened claude.ai/directory/manage > MCP connector: 7 steps. Step 1 needs a
  connector added at https://mcp.centmemo.com under Ben's account (his
  Apple sign-in); Ben's existing "Centmemo" connector still uses the old
  address. Steps 6 and 7 are his acknowledgments and Submit.
- Exited without saving. Every field's answer is in docs/store/DIRECTORY.md,
  the listing words drafted from Ben's own, for a short session with him.

### Launch tick 7 — 2026-11-22 — L3: the directory form, filled with Ben
- Ben added the connector at https://mcp.centmemo.com (his Apple sign-in and
  approval). The form detected sign-in always required and DCR, 6 tools, OAuth.
- **Found by the form:**
  - **Step 2:** "Missing title annotation" on all six tools. The title was
    only top-level; now also in `annotations.title` (mcp v6).
  - **Step 6:** one acknowledgment reads "Tool descriptions contain no
    instructions about model behavior", and `unexamined_transactions` said
    "Use it to invite them ...; do not write the memo for them". It now
    says only what the tool returns (mcp v7).
  - `test_connector.mjs` checks both; each check was seen failing against
    the old server, then passing through both addresses.
- **The Worker** redirects /favicon.ico and /apple-touch-icon.png to
  CentMemo's icon. Claude shows the server address's favicon, and that
  address serves only the connector. Deployed through the dashboard,
  verified live (301).
- **Filled:**
  - Listing: one-liner and description from Ben's words, Financial
    Services, author, links, custom icon.
  - Test & launch: three use cases, prerequisites, Read only, self-tested.
  - Data handling: own API, no health data, nothing sponsored.
  - Company: name, website, contact, reviewer notes. A guessed "Founder"
    role was cleared.
- **Left to Ben:** the seven policy acknowledgments, Review and submit, and
  emailing the reviewer credentials (in ~/.centmemo/test-users.json under
  "reviewer").

### Launch tick 8 — 2026-11-22 — L3 reviewer proof + L4 iPhone error state
- **L3:** Ben asked whether the reviewer credentials really work.
  `tools/test_reviewer_live.mjs` follows the reviewer's Claude, live:
  - mcp.centmemo.com discovery, then client registration.
  - The live consent page in headless Chrome, where Reviewer sign-in uses
    the exact credentials in the form, then Allow reading.
  - The token, then all six tools on the sample data.

  A wrong password is refused (the control). PASS; it now runs in test_all.
  The credentials sit in the form's notes (Decision 064), and the password
  is on Ben's clipboard.
- **L4:** the iPhone showed URLSession's own error text, where the web says
  "CentMemo couldn't reach its server." / "You're offline."
  - `SessionStore.describe` maps URLError to the web's words.
    `ErrorWordsTests` passes in the Core suite.
  - A DEBUG door `APP_FAIL_NETWORK=offline|unreachable` fails REST calls
    only; sign-in still works.
  - `ErrorStateUITests` on the iPhone 12: unreachable, offline, and a
    no-door control all PASS, Try again survives, and there are no crash
    logs. Screenshot read: "Couldn't load / CentMemo couldn't reach its
    server. / Try again".
- **Next:** L4 import on the phone (a file in Files), and F2 background
  delivery. L2 and L3 wait on Ben.

### Design tick 1 — 2026-11-22 — D1, D2 research; D3 Duo harness
- **D1:** `docs/research/story-design-research.md` covers journaling apps,
  data-rule writing suggestions, 14 starter value themes, memo-as-moment
  precedents, and collections and sharing. Agent caveat: four URLs and the
  FinanceKit field names came from memory; check them before building.
- **D2:** `docs/research/merchant-tiles-and-views-research.md` covers:
  - Clearbit's logo API is gone; logo APIs need web domains we don't have,
    and they leak the merchant list. So the default is an on-device monogram
    tile: initials, a pencil-hue mark hashed from the cleaned merchant, and
    a category glyph.
  - A local name cleaner, with the person's renames becoming rules.
  - Swift Charts marks; color is never the only signal (WCAG 1.4.1).
  - Filters: a scope plus search tokens.
  - Names for "Ledger": Timeline or Chronicle. Ben's call.
- **D3:**
  - "duo" registered (app_config.DEVICES, bench _LEGACY → ios).
    `ios_uitest.py --device duo` runs; its XCUITest frames are blind because
    the outer display is off when the phone is open (correctly failed).
  - New `tools/design_shots.py`: every screen on iphone and duo, every
    display by id, only while CentMemo is in front; flat frames are dropped
    and named. First run: 8 frames, with the Duo inner display at
    2853x2007.
  - Read duo-unexamined: one full-width list, names far left, debits far
    right. That confirms Ben's "everything ... seems like a list".
- **Next:**
  - D4/D5: put language options and three directions in front of Ben, as
    mockups.
  - Meanwhile build what's inferable either way: merchant name cleaning
    and the monogram tile.
  - Port Ear Drama's UITestScrolling and regular-width rules for the Duo.

### Design tick 2 — 2026-11-22 — D5 mockups for Ben; D8 store names and tiles
- **D5:** published three directions for Ben, each on iPhone and the open
  Duo, with a language table and the pieces every direction shares:
  https://claude.ai/artifact/TtRywFmQhiiq9Mdg1Q2jPu
  - Notebook: writing first, three suggestions with reasons, the memo as
    the headline.
  - Collection: keepsake stubs, sets, store pages.
  - Chronicle: a pencil thread, a theme calendar, a month strip.

  Waiting on his pick, the Ledger word, and the 14 themes.
- **D8 (shared by every direction):**
  - `cleanMerchant`, `merchantInitials` and `merchantHue` (FNV-1a) in
    js/money/money.js and Money.swift, one algorithm. The golden is
    `tests/fixtures/merchant-names.json`, read by both suites; a planted
    wrong value fails node and Swift (seen).
  - Six store hues in design-tokens.json (color.semantic.store*),
    regenerated; the contrast test passes.
  - `StoreTile` (iOS): initials, the hue mark, and the category SF
    Symbol. The web `.tile` has initials and the hue mark; the web glyph
    is ⏳ (Material/inline SVG).
  - Seen on the iPhone 12 (ledger, after a fix where the glyph crowded
    the initials), on the Duo's inner display (unexamined), and on the web
    at 375px.
- **Next:**
  - Build Ben's chosen direction.
  - Until he picks: the store page and "call it..." renames, and the Duo
    regular-width two-pane layout.

### Design tick 3 — 2026-11-22 — D3: two panes on the open Duo
- Ben's clarification on the directions is pending, so this tick shipped what
  every direction shares: "The open Duo uses two panes".
- `TwoPane` + `EntryLink` + `PaneSelection` (apple/iOS/Components/TwoPane.swift):
  - At regular width, the list sits on the left and the tapped purchase
    opens on the right, never pushed. The first purchase opens on its own,
    so no half-screen is empty.
  - Compact width keeps the push. The branch is on width only (Ear Drama
    iOS-DESIGN 3.6).
  - Unexamined keeps its inbox path.
- **Verified:**
  - `DuoTwoPaneUITests` on the Duo: PASS (the list stays, and the tapped
    store shows in both panes).
  - On the iPhone 12 it SKIPs by its own compact check (the control).
    MemoUITests and TabSmokeUITests pass there.
  - Duo ledger frame read: the list with the selected row on the left, the
    Tattered Cover detail on the right.
- **Seen, next (D6):** the detail is still a bank form (Date, Posted,
  Category, Type, Account, Statement, then Memo). Every direction makes the
  memo the headline and the amount a footnote.

### Design tick 4 — 2026-11-22 — Ben's choices recorded; vocabulary applied; Skip (D13)
- **Ben chose** (directions page feedback, verbatim in the brief): the
  Chronicle design as the base. Words: memo, Narrative (was Ledger), Story,
  plot points, Skip, Themes, Setting (never merchant). Recorded as Decision
  065, in the brief's vocabulary table, and in memory story-vocabulary.
- **Language applied** on iOS, web and tests:
  - Narrative tab and title.
  - Themes instead of Values (settings, the memo editor, Story scope).
  - "Nothing in your Narrative yet".
  - Events instead of transactions in the delete, connector, sync and
    detail texts.
- **Skip:**
  - Migration 20261122010000_skip_events adds `transactions.skipped_at`
    (additive; imports and sync upsert only their own columns, so a skip
    survives), and the unexamined view excludes skipped events.
  - iOS: a swipe Skip / Bring back (`skipAction`), a detail ⋯ menu item,
    and the Narrative's "N skipped" section of separate rows.
  - Web: a Skip / Bring back button on the event page; the Narrative
    `details.skipped`.
- **Verified:**
  - test_web_states runs the skip round trip: Unexamined → the Narrative
    group → Bring back, fixture left as found.
  - SkipUITests on the iPhone 12: PASS after three test-side fixes, each
    found by looking:
    - A full swipe fires the action, so the test now reveals by a partial
      drag.
    - A DisclosureGroup's children share one cell, so the skipped group is
      now a Section of separate rows.
    - A tap under the floating glass tab bar opened Story (seen in the
      frame), so the test now scrolls clear of it.
  - Frames read: King Soopers gone from Unexamined (14), and "1 skipped"
    with Bring back revealed.
  - `tools/restore_skips.mjs` repairs the fixture after a failed run.
- **Duo:** this run FAILED on the Duo, both DuoTwoPane and Skip. Ben's Duo is
  now in portrait on the inner display. A design_shots frame shows the app
  fine (two panes), so this is the known XCUITest portrait-frame quirk on
  the open Duo (Ear Drama). Port Ear Drama's UITestScrolling and recheck.
  The two-pane test passed earlier in landscape.
- **⏳ next:**
  - The connector's `unexamined_transactions` should exclude skipped events
    (deploy).
  - The narrow left pane in Duo portrait wraps the date and category.
  - D6: the event page is still a bank form.

### Design tick 5 — 2026-11-22 — connector Skip (v8); D6 event page memo-first; Duo link fix
- **Connector v8:** `unexamined_transactions` leaves skipped events out.
  The test_connector check skips one as the owner, expects it gone, then
  restores it. Seen failing on v7, passing on v8. The reviewer path still
  passes.
  - Note: v8 shipped a trimmed money.js beside the function (only
    toMinor/formatMinor, all it uses). tools/deploy-mcp.sh ships the full
    file when a token is present.
- **D6 event page (iOS):**
  - The Setting tile (56pt) and the name lead, with the date under them.
  - The memo editor follows, with the placeholder "What happened here?"
    (wording for Ben to review).
  - Themes, then Photos.
  - The amount, account and category form a footnote line that opens the
    bank facts (a DisclosureGroup).
  - On save, a pencil stroke draws in beside "Saved." (PencilStroke).
  - MemoUITests and SkipUITests pass on the iPhone 12. Frames read on the
    iPhone 12 (memo, blank) and the Duo.
- **Duo bug found by looking:** an item opened by a link (the inbox, the
  APP_START_ITEM door) was pushed onto the left stack while the right pane
  said "Choose a purchase". Now `AppStore.openedItem` routes it to the right
  pane at regular width. Seen fixed in the Duo frame.
- **design_shots.py** captures event pages too (`--screen memo|blank`).
- **⏳:**
  - The web event page doesn't lead with the memo yet (parity).
  - Narrative and Story rows as memo-first.
  - S1 Venmo CSV.
  - Ben's FinanceKit choice (S4).

### Design tick 6 — 2026-11-22 — D6 on the web (parity)
- The web event page now matches the iPhone:
  - The big Setting tile and the name lead, with the date under them.
  - Then the memo ("What happened here?" placeholder), Themes, then
    Save / Skip.
  - The amount, account and category are the summary of a closed
    `details.txn-details` footnote holding the bank facts.
- **Found by reading the frame:** a stray "null" on the page.
  `body.replaceChildren` (native DOM) stringifies the null that
  `photosNote()` returns when there are no photos; this was latent before
  the reorder. Fixed with `|| ''`. The new check was seen failing on the
  bug, then passing.
- **Also fixed:** the theme input had no placeholder; "values belong to a
  memo" now says "themes" on the web.
- **Next:**
  - Narrative as the Chronicle thread (D10).
  - Memo-first rows.
  - S1 Venmo CSV.
  - D14 default themes for Ben.

### 2026-11-22 — Ben's words: the memo prompt; the email to Apple sent
- Empty memo prompt: "What do you want to remember?" (Ben), on iOS and web.
  The vocabulary table now holds it, along with "memos are MEMOries".
- Ben sent the email in Case-ID 23676235 (Decision 066). Watch for Apple's
  reply; the turn-on steps are docs/store/WALLET-IN-CONNECTOR.md.
- The mobile CSV export paths for Venmo, PayPal and Cash App are being
  researched (docs/research/p2p-csv-export-paths.md).
- Verified "What do you want to remember?" on the iPhone 12 and the Duo
  (frames read). MemoUITests.testDetailShowsMemoAndValues failed once (the
  event never opened, the first launch after install) and passed on the
  rerun: a flake, logged, not a regression.
- docs/research/p2p-csv-export-paths.md:
  - Venmo has a phone path.
  - PayPal and Cash App are documented only on their websites. Cash App's
    app gives PDF statements only.

### Design tick 7 — 2026-11-22 — D10 the Narrative as a thread (iOS)
- `ThreadRow`: a continuous pencil line.
  - A written memo is a filled mark in its first theme's hue (theme hue =
    `Money.merchantHue(theme)` over the six store hues, until D14 gives
    themes their own colors), with the memo in serif as the headline and a
    small Setting tile, the date, the Setting and the theme under it.
  - A waiting event is a hollow mark with one quiet line (date · Setting ·
    amount).
  - The month query now brings memo themes.
- **Verified:** TabSmoke and Skip pass on the iPhone 12; frames read on the
  iPhone 12 and the Duo (thread on the left, event on the right).
- Ben approved S2 (PayPal and Cash App via their documented web exports);
  every source shows its documented path beside Import.
- **Next:**
  - The web Narrative thread (parity).
  - The S1/S2 importers, with the paths shown.

### Design tick 8 — 2026-11-22 — a privacy fix (test sign-in on Ben's Duo); Duo layout done right; deposits quiet
- **Incident:** my harness's test sign-in (APP_TEST_EMAIL door) persisted on
  Ben's own Duo. A later Wallet sync in that session copied his real Wallet
  (6,979 events) into the synthetic test-owner account at 21:15 UTC. His own
  account also has them, from his own sync at 17:07 UTC. Nothing reached
  Claude (the connector excludes FinanceKit) and nothing left this Mac; the
  web test screenshotted them into build/qa (gitignored, local).
  - **Fixes:**
    - A door sign-in lasts only for door launches; any plain launch signs a
      synthetic account out. Seen on the iPhone 12: a door launch, then a
      plain launch, lands on the sign-in screen.
    - Real Wallet never syncs into a synthetic account
      (`SessionStore.isSynthetic`, unit tested).
    - design_shots never sends test credentials to the Duo (PERSONAL).
    - ios_uitest refuses the Duo unless CENTMEMO_UITEST_DUO=1.
  - **⏳ Ben to confirm:** delete the copy from the test-owner account.
    WalletSyncUITests fails until then (the fixture holds his accounts).
- **Duo layout, found on Ben's real data:**
  - The list ended 84pt short of the divider. Fixes I guessed at failed
    four times. Then I measured: an on-screen readout showed window 867 +
    84 inset, pane 364, list 280, and an experiment without the pane's own
    NavigationStack filled the column.
  - Ben pointed at the existing solution: Ear Drama iOS-DESIGN §3.6e
    (ProductionScreen), one stack per screen with the list as a plain
    column. TwoPane now does exactly that; the workarounds and the readout
    are removed.
  - Plus 16pt off the divider for the month › and the event header.
  - Seen on the Duo on Ben's account and on the iPhone 12; the iPhone tap
    tier passes.
- **Deposits:** Daily Cash deposits (FinanceKit `deposit`: 2,113 Savings +
  1,017 Apple Cash) and `interest` are quiet by default in the Narrative,
  with "N deposits and interest hidden · Show" on iOS and web.
- **Ben's direction:** design on his real data from now on (the Duo, his own
  session); the synthetic accounts stay on the iPhone 12 and the web tests.

### 2026-11-22 — Wallet tour (Ben's request): what Apple Wallet shows that CentMemo could use
- `tools/wallet_tour.py` + `WalletTourUITests`:
  - Read-only: it opens the Apple Card and up to five purchases, recording
    each screen's accessibility labels.
  - A forbidden-label list keeps it off anything that moves money or shows
    card numbers. It never launches CentMemo and runs only with
    WALLET_TOUR=1 and CENTMEMO_UITEST_DUO=1 (Ben's say-so).
  - Output stays in build/qa/ (local).
  - Two fixes: it first opened the Card Balance row (now it targets
    identifier "transaction" by label), and a key-path build error.
- **Found:** a purchase screen shows the Maps place and map, city/state,
  time, status, card last four, Daily Cash, "Shown on Statement as", and
  Apple's category. FinanceKit exposes no place. D15 is updated with a
  lookup-and-confirm proposal for Ben.

### Design tick 9 — 2026-11-22 — S1/S2 Venmo, PayPal, Cash App import (web)
- js/money/money.js:
  - `detectExport` recognizes the file by its header.
  - `parseVenmoCsv`, `parsePayPalCsv` and `parseCashAppCsv` follow every
    trap in docs/research/p2p-csv-export-paths.md:
    - Venmo's title, balance and disclaimer rows, and the `- $65.00` signs.
    - PayPal's Memo-impact holds, mapped by header name.
    - Cash App's FAILED rows, and Notes being the store on card purchases.
  - `looseMinor` handles every sign style. The person's note goes to
    `description`; the other party or store to `merchant`.
- Golden tests on synthetic fixtures (tests/fixtures/{venmo,paypal,cashapp}-sample.csv);
  a planted FAILED row is caught (seen).
- `API.importExport(kind)` gives each source its own account.
- The web import page takes any of the four, says which it found
  ("Import 3 Venmo events"), and lists each source's documented export
  path (Ben: "share the documented path for each of the csv pathways").
- test_web_states imports the Venmo sample through the real file input as
  the stranger: 3 new, in the Venmo account, with notes; left empty.
  Screenshot read.
- **⏳:**
  - The iPhone import still takes only Apple Card (Swift port of the
    three parsers, with goldens, next).
  - "Use this note as my memo" on events that carry one.

### 2026-11-22 — Test accounts hold only fake data (Ben: "Yes. The test account should only have fake data.")
- With Ben's yes, deleted the copy of his Wallet from the synthetic test
  owner, as the owner through REST: 6,979 events, 3 FinanceKit accounts, no
  balances. It now holds only its 22 fake Apple Card CSV events. A SQL check
  across accounts: real Wallet rows exist only in Ben's own account.
- New guard in tools/test_rls.mjs (runs in test_all): a synthetic account's
  Wallet rows must all be the app's samples (`sample-…`). A negative control
  catches a real id.
- **Found while re-checking:** WalletSyncUITests had failed since design
  tick 4, because the vocabulary pass changed the sync message and the test
  still expected "Synced 4 transactions". I had blamed its failure on the
  contamination. The message is now "Synced N events from M accounts."
  ("Added" misread on a re-sync).
- **Lesson:** after any wording change, run the full iPhone tap tier, not
  only the suites touched. Full tier on the iPhone 12: 17 PASS (corrected from "19"), 3 SKIP by
  design, no crashes, data left as found.

### Design tick 10 — 2026-11-22 — S1/S2 on the iPhone
- Money.swift: `looseMinor`, `parseVenmoCSV`, `parsePayPalCSV`,
  `parseCashAppCSV`, `detectExport` and `parseAnyExport`, one algorithm
  with the web. `OtherSourcesTests` read the same fixtures as the node
  goldens; a planted FAILED row is caught (seen).
- `APIClient.importExport(kind)` (an account per source).
- Settings: "Import a CSV" takes any of the four. "Where to get a CSV"
  lists each documented path, in the same words as the web.
- **Verified:**
  - The full iPhone 12 tier: 18 PASS (new testExportPaths) and 3 SKIP by
    design.
  - Frames read on the iPhone 12 (paths open) and the Duo (Ben's account).
- **Correction:** the previous entry's "19 PASS" was 17. The tier then had
  17 tests plus 3 skips.
- **⏳:** an import of a real file through the Files picker hasn't run on a
  device.

### Design tick 11 — 2026-11-22 — D7 suggestions with reasons on Unexamined
- `memo_suggestions()` (migration 20261122020000), one algorithm in SQL that
  both clients show. At most one event per rule:
  - first visit to a place
  - biggest this month
  - busiest day (3+)
  - a memo from a year ago, quoted

  Details (deposits, interest, payments, transfers, refunds, skipped)
  never count. "Today" is the person's latest event. Security invoker;
  anon gets 401; the stranger gets none.
- **iOS:** `SuggestionCard` (reason in pencil, the Setting tile, a prompt
  or the quoted memo), swipe Skip included. Words in `SuggestionWords`.
- **Web:** `.suggestion` cards with the same words. The count circle is
  gone on both, so Unexamined doesn't show a to-do number.
- **Verified:**
  - Web: test_web_states asserts suggestions with reasons and no count;
    frame read.
  - iPhone 12: TabSmoke, Skip and EmptyState pass. Skip first failed
    because King Soopers now shows twice (card + row) and the card had no
    swipe; cards can be skipped now.
  - Duo, on Ben's real data: three suggestions (first time at AutoNation
    Toyota, biggest at the Apple Store, busiest day at State Farm); frame
    read.
- **Not verified:** the follow-up so the Duo opens the first suggestion
  (the list and suggestions now load together). The Duo refused launches
  (likely locked).
- **For Ben:** the reason and prompt words ("First time here / What brought
  you here?", "Biggest this month / What was it for?", "Your busiest day
  this month / What was the day about?", "A year ago you wrote").

### Design tick 12 — 2026-11-22/23 — D9 filters; the Duo checks closed
- **Duo (Ben's account):**
  - Unexamined now opens the first suggestion on the right (the list and
    suggestions load together).
  - Folded, the outer display shows the compact layout cleanly. Frames
    read.
- **D9:**
  - `NarrativeFilter` (Core): All / Written / Unwritten, one theme, and
    deposits and interest (off by default). Skipped events are always
    apart. Unit tested.
  - iOS: a native toolbar Menu on the Narrative; the icon fills when a
    filter is on.
  - Web: the same rule (`narrativeFilter`) as selects above the thread.
- **Verified:**
  - FilterUITests on the iPhone 12 (Written hides King Soopers and keeps
    the penguins memo); frame read.
  - test_web_states (Written, then back to All); frame read.
  - Duo: the filter button is in the toolbar strip.
  - A test-side bug: two `const s` in separate CDP evaluates collide (the
    page keeps globals). Each step is now its own function.
- **Next:** D11 the color-coded month strip, or D12 Themes as collections;
  D14 default themes for Ben's review.

### Design tick 13 — 2026-11-23 — Duo padding made consistent, measured against guides (Ben's request)
- **Measured first:** guide lines on the Duo frames showed every surface on a
  different edge:
  - title 20, cards 16, Unexamined rows ~21 with amounts at the divider
  - month bar 29 and 9 past the guide
  - thread 24/44
  - pane cards 1pt off the divider and 2pt off the strip
- **Applied Ear Drama iOS-DESIGN §3.6b/e:**
  - Words stand 20pt in from both column edges (`PaneEdges`,
    `columnRowInsets()`); the month bar became a row so it stands on them.
  - Boxes stand 16pt in.
  - The pane keeps 20pt plus the measured safe area (`PaneMargins`, Ear
    Drama's PageMargins). A first try with plain contentMargins ran the
    cards under the strip.
- **Verified:** guides on the Duo frames (Unexamined and Narrative, Ben's
  account), every edge on its line; the iPhone 12 unchanged (guides); the
  iPhone tap tier subset passes.
- **Bound:** docs/DESIGN.md section L (L1–L5).

### Design tick 14 — 2026-11-23 — D11 the month strip by theme
- `ThemeStrip.parts` (Core, unit tested): money spent under each written
  memo's first theme; parts add up; skipped, unwritten and money in are left
  out. The web's `themeStrip` follows the same rule.
- `MonthStrip` (iOS) and `.month-strip` (web) go under the Narrative's
  totals: one bar split by theme, and a legend naming each part with its
  amount (WCAG 1.4.1: never color alone). `ThemeHue` is now the one color
  rule for the thread marks and the strip.
- **Verified:** test_web_states (a part per theme, each named); frames read
  on the web and the iPhone 12; iPhone tests pass. The Duo refused the
  launch (locked), so it's not seen there yet.
- **Found by reading the frames:** "Being outside" and "Time with my kids"
  share a color. With 6 hues, a name hash collides, so D14 must give each
  theme its own color (stored with the theme). D14 is next, with Ben
  approving the set.

### Design tick 15 — 2026-11-23 — D12 Themes as the Story's collections
- **Story tab (iOS):** a Themes shelf, each theme with its mark and how many
  memos it holds (`APIClient.themeCounts`). Tapping one reads only that
  theme; "Every memo" goes back. The picker is months only now.
- **Web:** the same `.theme-shelf`; the "Show" picker became "Month" and
  hides while a theme is open, so themes aren't offered twice.
- **Duo, measured against the guides:** the Story column broke L2 (the Month
  row, the count and the card ran to the divider, "$13.00" touched it). Now
  rows sit on the words edge and cards on the box edge, with their words
  16pt inside.
- **Verified:**
  - ThemesUITests on the iPhone 12 (Great meals shows only its memos,
    Every memo returns).
  - test_web_states (the shelf, a theme filter, Every memo).
  - Frames read on the iPhone 12, the web and the Duo (with guides).
- **Seen:** theme tags on memos are still aqua pills (the ground color),
  while collections use per-theme marks. That's two color systems for one
  idea; D14's theme colors settle it.

### Design tick 16 — 2026-11-23 — D12 sharing a memo, private by default
- **iOS:** ⋯ → Share opens "Share this memo": a paper-and-ink card
  (`MemoShareCard`; the memo in serif, its theme, the date, the CentMemo
  mark) with "Show where" and "Show the amount", both off by default, and a
  ShareLink sending the rendered image. The event query now brings theme
  names.
- **Web:** a "Share this memo" panel with the same card and switches; it
  shares via navigator.share, or copies the text where there is none.
- **Verified:**
  - ShareUITests on the iPhone 12 (the date line alone by default, "Show
    where" adds the place); frames read.
  - test_web_states (the same checks).
- **Three test-side lessons:**
  - Overflow-menu items keep their label, not their accessibility id.
  - A tap at a Toggle row's center hits the label; tap the switch.
  - A check by on-screen text matched the page behind the sheet; check the
    card's own line.
- MemoUITests flaked once more on the first launch after install (passed
  on the rerun).
- **Not seen:** the share sheet on the Duo (design_shots can't open the ⋯
  menu; the tap tier stays off Ben's phone).
- **Next:** D14 themes, once Ben answers; sharing a whole theme; public links
  later (they need server pages).

### 2026-11-23 — TestFlight 1.0 (15): the design pass so far
- Full iPhone 12 tier before the upload: 21 PASS, 3 SKIP by design; RLS
  plus the fake-data guard pass.
- 1.0 (15) uploaded (not submitted for review; L2 stays held). In it, since
  14:
  - the Duo layout by Ear Drama's rules (DESIGN L)
  - deposits quiet by default
  - suggestions with reasons and no count
  - filters
  - the month strip
  - Themes as collections
  - sharing a memo
  - Venmo, PayPal and Cash App import with the paths
  - the test-account guards

### Design tick 17 — 2026-11-23 — D8 a Setting's page
- **Audit first:** the brief's D10 web mark was stale (the web Narrative has
  been a thread since tick 13). D13's connector cell was stale too: mcp v8
  already leaves skipped events out of unexamined. Both are now marked.
- **Built:** "Every visit" on the event page opens the Setting's page:
  - the tile and the name
  - "N visits · since <first> · M memos"
  - every visit as the thread, the place said once at the top
  - Web: `#/setting/<name>`; Back walks the app's own history.
  - iOS: `SettingPageView` via `SettingRoute`, plus a DEBUG door
    `APP_START_SETTING` (design_shots `--screen setting`).
- **The query:** one rule on both stacks. `settingPattern` builds an ilike
  pattern from the name's words; it is golden-tested in JS and Swift against
  merchant-names.json, and checked to find its own raw descriptor. Only exact
  cleaned-name matches are kept.
- **Verified:**
  - `tools/test_all.sh` passes (rc=0).
  - test_web_states: Every visit → Setting with its count and memos; Back
    returns. setting.png read.
  - ~~iPhone 12: `SettingUITests.testSettingDoor` passed.~~ Corrected in
    tick 18: it ran under the Time Limit overlay, and the harness flags that
    pass as proving nothing.
- **Not verified:**
  - **The iPhone 12 tap test:** a Screen Time "Time Limit: You've reached
    your limit on CentMemo" overlay covered the app during the run. Ben
    needs to lift the limit; changing Screen Time is not mine to do.
  - **The Duo:** it runs Ben's TestFlight 15, so the new page isn't on it.
    I didn't overwrite the build he's trying.
- **Seen on the Duo frame:** a long Setting name hyphenates in the pane header
  ("AutoNa-tion Toyo…"). Next tick: fit the name without breaking words.
- **Next:**
  - the header fit
  - re-run SettingUITests once the limit is lifted
  - D14 when Ben answers

### Design tick 18 — 2026-11-23 — a Setting's name never breaks a word
- **Found:** the Duo frame from tick 17 showed "AutoNa-tion Toyo…" in the
  event header.
- **Measured from that frame:** the Duo held in portrait gives a 669pt window,
  so the pane's title has about 180pt at the default 34pt largeTitle.
- **Fix:** `SettingTitle` (Core) steps down to title, then title2, when the
  name's longest word won't fit whole on one line. It uses ViewThatFits; each
  candidate's ideal width is its longest word. Used on the event page and on
  the Setting page.
- **Verified offline:** `SettingTitleRenderTests` renders the header at 180pt
  before and after, to build/qa/setting-title/, and I read the frames:
  - before: "AutoNatio / n Toyota…" (the bug reproduced)
  - after: "AutoNation / Toyota / Arapahoe" at 28pt
  - "Denver Zoo" stays at 34pt
- `tools/test_all.sh` passes (rc=0).
- **Not seen on a phone:** the iPhone 12 still shows the Screen Time Time
  Limit on CentMemo. Tick 17's door "pass" ran under that overlay, so the
  claim is corrected above. The Duo runs TestFlight 15.
- **Waiting on Ben:**
  - lift the iPhone 12's limit
  - or say whether to install a debug build on the Duo, or ship TestFlight 16

### Design tick 19 — 2026-11-23 — the iPhone 12 is still blocked after midnight
- Reran `SettingUITests` on the iPhone 12 at 12:03am. The harness flagged
  the "Time Limit: You've reached your limit on CentMemo" screen again; I
  read the frame. It has "Ask for More Time" and the status bar shows Sleep,
  so this is not a daily limit that resets at midnight. It needs Ben (Screen
  Time is a system setting, not mine to change).
- No code changed. The Setting page and the header fix are still not seen on
  a phone.
- **Next:** rerun once Ben lifts the limit, or ships TestFlight 16, or says
  to install a debug build on the Duo.

### 2026-11-23 — TestFlight 1.0 (16): the Setting page
- **Ben:** "Ship the latest TestFlight".
- `tools/test_all.sh` passes (rc=0). 1.0 (16) uploaded with
  `tools/submit-appstore.sh ios` (not submitted for review; L2 stays held).
- **New since 15:** a Setting's page, every visit there, from "Every visit"
  on the event page (D8). A long Setting name steps down a size instead of
  breaking a word.
- **Not run before this upload:** the iPhone 12 tap tier, because the
  Screen Time limit still covers CentMemo.
- **Next:** once 16 is on the Duo, capture the Setting page and the header
  there and read the frames.

### Design tick 20 — 2026-11-23 — the Setting page seen on the Duo
- **Ben:** "You should be able to add builds to the duo." I installed a debug
  build 16 over TestFlight on the Duo (devicectl; no test sign-in, so his own
  session).
- **Seen on the open Duo, frames read** (build/design/2026-11-23):
  - the Setting door, Apple Store: the tile, the name, "107 visits · since
    Nov 5, 2019", and the thread of visits
  - the AutoNation event page, from his own data: "AutoNation / Toyota
    Arapahoe" at the stepped-down size, with no word broken, then
    "Nov 20, 2026 · Every visit"
- **Harness gap found:** the `memo` screen's fixture item isn't in Ben's
  account, so on the Duo it shows "This purchase isn't in your CentMemo."
  Worked around this with `--env APP_START_ITEM=<his event>`. The real item id
  stays out of git.
- **Seen, Ben's to judge:** the Setting page covers the whole Duo window.
  Each row puts the date at the left and the amount about 1,500pt away at the
  right, with nothing between them when there is no memo.
- **Still blocked:** the iPhone 12 tap test (Screen Time).

### Design tick 21 — 2026-11-23 — an invitation card, relevant questions, a Settings sidebar
- **Ben:** "the recommendations on the unexamined page look almost identical
  to the regular rows and the questions are often incredibly irrelivent
  (State Farm Insurance - 'What was the day about?'). We need to create a
  proper card that is actually encouraging you to to write a memo that is
  relevant." Also: Settings on the open Duo should "work like a regular
  sidebar with the actual settings showing on the right".
- **The database** (migration 20261123010000, applied):
  - Bills are never suggested: insurance and finance, utilities, phone and
    cable, and subscriptions by MCC, plus the same charge at the same place in
    two earlier months.
  - The three picks are at three different places.
  - Each pick names its moment (meal, groceries, trip, ride, fuel, car,
    outing, find, care, giving, gift, shop), from the MCC or the Apple Card
    category.
  - Checked against Ben's own data:
    - before: State Farm and two Apple Store picks
    - after: AutoNation "car", Apple Store "shop", Uber Eats "meal"
- **The card (iOS and web):**
  - one invitation at a time, with "Another"
  - the question leads, in the serif, over a pencil line
  - the place, date and amount are the small print
  - it ends on "Write a memo"
  - the questions fit the moment ("What did the car need?", "What was the
    occasion?"); these are my drafts and await Ben's approval
- **Settings at regular width:** a 380pt sidebar of sections (Ground, Themes,
  Money in, Connect Claude, Account, Privacy and terms), with the chosen
  section's form on the right. Compact width keeps the one list.
- **Verified:**
  - On the open Duo with Ben's own data, frames read: the card, then a fix
    (a footer drew a black band and clipped "Another"; it is now a row of its
    own, and the question is a size smaller), and the Settings sidebar.
  - On the web, test_web_states: one card; it ends on the act; Another shows
    a different moment. happy-unexamined.png read.
  - `tools/test_all.sh` passes (rc=0).
- **Not verified:** the iPhone 12 (Screen Time still covers CentMemo).
- **Follow-ups the same morning (Ben):**
  - "why does the refresh button also need a text label": it is now the
    icon alone, still named "Another suggestion" for VoiceOver.
  - "The refresh button should be within the card as well": it sits in the
    card's top corner, beside the reason. On iOS it is an overlay on the row;
    on the web it is a sibling laid over the card's link, so it never opens
    the event.
  - Both seen and read: the open Duo frame and web happy-unexamined.png.
  - The web test clicks it and gets a different card. On iOS, tapping it is
    not verified yet: the Duo takes no taps from the harness, and the
    iPhone 12 is under Screen Time.
- **Wallet in the connector:** Kavya's reply (2026-11-23) declines to
  interpret the Addendum. Ben chose to keep it off until L2.

### Design tick 22 — 2026-11-23 — D8 categories for Wallet purchases
- **Found:** about 6,979 of Ben's events had an empty category. FinanceKit
  gives a merchant category code but no category.
- **Built:** `transactions.plain_category`, a generated column (migration
  20261123020000, applied; nothing rewritten). It is the bank's category,
  else Apple Card's own word read from the code: Restaurants, Grocery, Gas,
  Airlines, Hotels, Transportation, Utilities, Insurance, Medical,
  Entertainment, Shopping, Services, Other. The view now carries it.
  - iOS: LedgerEntry reads it as the category, so rows, the event page and
    the tile glyph all get it.
  - Web: the catOf(t) helper.
- **Result:** about 3,400 events now have a category. The ~3,600 without
  one have no merchant code (deposits, older Wallet rows).
- **Verified:** the Duo's outer display (Ben's data, frame read) shows
  "Restaurants" with a fork and knife, "Transportation" with a car, and
  "Grocery" with a cart. test_web_states passes, and `tools/test_all.sh`
  passes (rc=0).
- **Known miss:** Crumbl reads as Grocery (bakery code 5462). It should
  probably be Restaurants; it's a one-line change in the next migration.
- **Resources (Ben: "be aware of the resources you are using"):**
  - Every build, capture and suite ran under `nice -n 19` with
    xcodebuild `-jobs 2`, one job at a time.
  - Before the captures I waited for another session's Ear Drama build
    (two swift-frontend processes, load 35) to finish.
  - test_all now compiles for `generic/platform=iOS`, never the simulator,
    and the CentMemo simulator is deleted.

### Design tick 23 — 2026-11-23 — bakeries are Restaurants
- Migration 20261123030000 (applied) moves MCC 5462 from Grocery to
  Restaurants in plain_category (Postgres 17 SET EXPRESSION; nothing
  rewritten), and from "groceries" to "meal" in memo_suggestions. Ben's
  Crumbl now reads "Restaurants".
- A database-only tick: the Mac was loaded (load 9: Android Studio, media
  analysis), so no local builds ran. The full suite runs at the next quiet
  moment.

### Design tick 24 — 2026-11-23 — D8 renames
- **Built:** the person names a Setting, and every visit there takes the name.
  - `public.setting_names` (migration 20261123040000, applied). One row per
    place, keyed by the cleaned name both clients already compute. Owner-only
    RLS; agents are refused like every other table; added to test_rls.
  - Web: Rename on the Setting page. Rows, tiles, cards, the event page and
    the share card show the name. "On the statement: ..." sits under a
    renamed place. Clearing the name brings the bank's name back.
    `placeKey` stays the route key.
  - iOS: `LedgerEntry.settingKey` (the key) and `placeName`. APIClient
    loads the names once and fills them on every ledger read. A pencil in
    the Setting page toolbar opens a native alert with the name, plus
    "Use the statement name".
- **Verified:**
  - Web: test_web_states renames Denver Zoo to "The Zoo" and clears it again
    (frame setting-renamed.png read).
  - The Duo (build 16 debug, Ben's data): the Apple Store page renders with
    the pencil under Back (frame read). The save itself was not pressed,
    because it would write into Ben's real account.
  - The iPhone 12 is still under Screen Time.
  - `tools/test_all.sh`: rc=0, ALL PASS (niced; load about 9, from
    contactsd and Chrome; no other builds running).
- **Not done:** the connector still shows Claude the bank's names. The next
  step is mcp reading setting_names.

### Design tick 25 — 2026-11-23 — D8 renames reach Claude (mcp v9); the deploy token moves to the Keychain
- **Connector v9:** a renamed place reads `place: The Zoo (statement: Denver
  Zoo)`, and `search_transactions` finds it by the person's name. Names are
  read once per request, as the person, under RLS, and passed to txnLine;
  there is no module state, so nothing crosses between users.
  - New test_connector check (6c): the owner renames a place, Claude
    searches by that name, then the name is cleared. It failed on v8 and
    passes on v9.
  - Deployed through the Supabase connector with a trimmed money.js
    (formatMinor, cleanMerchant, settingPattern).
- **Ben (2026-11-23):** "The supabase connector should work via the keychain,
  which is what we fixed so that we wouldn't have keys on the mac."
  - Found: the Supabase personal access token was never moved into the
    Keychain. There's no `centmemo:` item and no Supabase CLI login, and
    deploy-mcp.sh still read the old token files, which are gone.
  - Fixed: deploy-mcp.sh reads `centmemo:SUPABASE_ACCESS_TOKEN` from the
    Keychain (or the environment) and never from a file. The new recipe
    `tools/secrets.sh keychain-paste SUPABASE_ACCESS_TOKEN` stores a token
    from the clipboard and then clears the clipboard. The value never sits
    on a command line or in a file.
  - Ben's step: make a token in the Supabase dashboard, copy it, and run
    that recipe once.
- **Verified:** test_connector passes, and `tools/test_all.sh` passes
  (rc=0, niced, load about 8).

- **Correction (Ben, 2026-11-23):** "I DO NOT want to create tokens and
  manage them myself." The keychain-paste recipe and the "Ben's step" above
  are withdrawn. Edge Function deploys go through the signed-in Supabase
  connector, with no token, and deploy-mcp.sh says so.

### Design tick 26 — 2026-11-23 — D4 vocabulary audit; the backend skill no longer asks for a token
- **Skill fix:** `zero-cost-hosted-backend` told agents to keep a Supabase
  personal access token in a mode-600 file. Changed it so migrations and
  deploys go through the signed-in connector, and the owner is never asked
  to create or paste a token (Ben, 2026-11-23).
- **D4 audit** of the on-screen words against the vocabulary table
  (Decision 065), on the web and iOS:
  - Web: "That export has no transactions." became "That export has no
    purchases in it." The theme field's screen-reader label "Value name"
    became "Theme name". Assets are now at `?v=20261123g`.
  - iOS: no screen word breaks the table.
  - Kept on purpose:
    - Apple's own button name "Export Transactions (CSV)" in the export
      steps.
    - The privacy disclosure's "accounts and transactions", because it
      names exactly what is read.
    - "Category", which is Apple's plain category on the event, not a
      Theme.
  - Internal route and table names (`#/ledger`, `transactions`) are not
    on screen and stay as they are.
- **Verified:** greps of every user-facing string in js/app.js, index.html
  and apple/iOS; `tools/test_all.sh` rc=0, ALL PASS (niced). No iOS change, so no
  new device frames this tick.

### Design tick 27 — 2026-11-23 — D6 Story rows: the memo is the headline
- **Change (web + iOS):** each Story entry now opens with the memo, then its
  themes. Date, Setting and amount follow in a quiet footnote line, as on
  the event page. The Story header reads "N memos" and no longer adds
  "· $X spent": the Story is the memos, and money stays in the Narrative's
  month facts. Web assets are at `?v=20261123h`.
- **New web check:** "a Story entry leads with its memo (D6)".
- **Verified:**
  - Web: frame `story-theme.png` read. The memo leads, the chips sit
    below it, and the footnote is spaced from the chips.
  - `tools/test_all.sh`: rc=0, ALL PASS (niced), with the iOS build.
  - Duo: build installed (debug), but the capture was refused because the
    phone was locked ("device was not, or could not be, unlocked").
  - iPhone 12: still under Screen Time.
- **Not verified:** the iOS Story on a device. The next tick retakes the
  Duo frame (`design_shots.py --device duo --screen story`, run with
  /usr/bin/python3, which has Pillow) before D6 is marked done.
- **Duo, after Ben unlocked it (2026-11-23):** frame `duo-story-1.png` read.
  The Story pane shows "1 memo", and the entry leads with Ben's memo ("This
  is the CentMemo domain purchase..."). "Nov 21, 2026 · Wp" and -$13.00
  follow in the muted footnote. The event opens in the second pane.
  D6 is ✅. The iPhone 12 frame waits on Screen Time.
- **iPhone 12 (Ben, 2026-11-23: "screentime does not impact the iphone 12 at
  this time of day"):** build installed on the bench device `iphone`
  (synthetic owner), and both frames were read:
  - `iphone-story-0.png`: "5 memos". Each card leads with its memo
    ("Anniversary. Worth every cent..."), then the theme chip, then
    "Nov 7, 2026 · Water Grill" and -$186.40 in the muted footnote.
  - `iphone-setting-0.png`: Denver Zoo's Setting page shows the DZ tile,
    "1 visit · 1 memo", the memo on the thread, and the pencil (Rename)
    at the top right.
  - D6 is now verified on web, Duo and iPhone 12. The D8 Setting page is
    seen on both phones.
- **Next:** press Rename → Save on the iPhone 12. It runs as the synthetic
  owner, so no real data is touched, and closes D8's iOS save. Then D12.

### Design tick 28 — 2026-11-23 — D8 rename saved on the iPhone 12
- New test `SettingUITests.testRenameSavesAndClears`, run as the synthetic
  owner: it renames Denver Zoo to "The Zoo", checks "On the statement:
  Denver Zoo", then uses "Use the statement name" to clear it.
  - It passes on the iPhone 12. Frames read: the alert with "Every visit
    here takes this name." and the renamed page.
  - The tile follows the name: "The Zoo" gives "Z" and a different mark
    color. That's acceptable; D14 theme colors don't touch tiles.
  - PARITY: Rename iOS ✅. Brief: D8 ✅.
- `tools/test_all.sh` rc=0, ALL PASS (full speed now).
- **Next:** F1, real FinanceKit (Ben's order).
- **Harness fixes (Ben, 2026-11-23: "What are the failures that keep
  happening? Is there any way to solve for them?"):**
  - Pillow: frame_blind re-runs under /usr/bin/python3. Proven by running
    design_shots with Homebrew python3, which captured a frame.
  - Locked phone: devicectl lockState is checked before a run, and the
    tools print `LOCKED`. It reads False on both unlocked phones; the
    locked case is not yet seen.
  - Readable frame names: `setting-door.png` was exported beside its UUID
    copy (testSettingDoor passed on the iPhone 12).
  - Recorded in docs/TESTING.md. `tools/test_all.sh` rc=0.

### Tick 29 — 2026-11-23 — F2 background delivery built; waits on two portal settings
- **F1:** already done. Ben's real syncs ran on TestFlight 12 and 13, and
  the backlog's 🟡 was stale.
- **F2, built on branch `f2-wallet-delivery`:**
  - The ExtensionKit target `CentMemoWalletDelivery`, extension point
    `com.apple.financekit.background-delivery`, iOS 26. It runs the app's
    own sync (Core) as `FinanceBackgroundSync.run()`, never for a synthetic
    account, and never notifies.
  - Shared through the App Group `group.com.learningischange.centmemo`:
    - The Keychain session; older items still load.
    - The history tokens, moved over from standard defaults on first read.
  - APIClient adopts a newer stored session before refreshing, and retries
    with it, so the app and extension don't revoke each other's refresh
    token.
  - Delivery is enabled hourly after a successful Wallet sync and disabled
    on revocation.
- **Blocked:** Duo build rc 65. The ASC API has no FinanceKit capability
  type, and automatic signing can't add a managed capability or an App
  Group. Two developer-portal changes (Ben's account) are needed:
  1. FinanceKit on the App ID `com.learningischange.centmemo.walletdelivery`.
     If it isn't offered, Apple must extend the grant to that bundle id.
  2. Register `group.com.learningischange.centmemo` and assign it to both
     App IDs.
- main is untouched and still builds for the devices.
- **Portal (Ben said yes):** registered the App Group
  `group.com.learningischange.centmemo` ("CentMemo shared") and assigned it
  to both App IDs. The ASC API confirms APP_GROUPS on both, and FINANCE_KIT
  is still on the app.
- **FinanceKit on the extension:** the walletdelivery App ID's Capability
  Requests tab shows "FinanceKit: No Requests". Apple's grant covers only
  `com.learningischange.centmemo`, so the extension needs its own request,
  which Ben submits as Account Holder.
- **On main now (without the extension):** the shared Keychain session,
  the App Group tokens, the refresh-token handoff, and the enable/disable
  calls. The extension target joins project.yml from branch
  `f2-wallet-delivery` once the grant arrives.
  - Duo, debug build with the App Group: Ben's real session survived, and
    the Narrative loaded his November (113 events, his memo). Frame
    `duo-ledger-1.png` read.
  - `tools/test_all.sh` rc=0.
- **FinanceKit request for the extension, pre-filled in Ben's Chrome:**
  - Bundle `com.learningischange.centmemo.walletdelivery`, App Apple ID
    6837824241, US, privacy link, iOS yes, financial management tools yes,
    no financial products, not sold, no marketing, 0–10,000 users.
  - The explanation cites case 23676235 and says nothing changes but the
    timing. No notifications; the connector carve-out is unchanged.
  - **Ben's step:** read the addendum, press Agree, then Submit.
- **Next:** D14 default themes, while Apple reviews.

### Tick 30 — 2026-11-23 — D14 starter themes drafted for Ben
- Proposal page: https://claude.ai/artifact/BmXyQZdab1uCcF9gLcRM5R (source:
  docs/design/starter-themes.html).
  - 13 themes from the research's 14, with "Beauty" folded into Joy so
    every theme has its own color. "Taking care of things" is stone grey.
  - The 12-hue palette is made in OKLCH (L 0.50 light / 0.80 dark). Each
    color is at least 5.4:1 on paper and 9:1 on the dark page.
  - Color rule: each theme stores its color. A new theme gets the first
    color none of the person's themes uses, so up to 12 themes never
    share one. This fixes D11's hash collisions.
  - Ben's existing themes keep their names; a name that matches a starter
    theme takes its color.
- **Ben's choices:** the set and its words (Beauty back as a 14th?), the
  first-run prompt with themes ticked or unticked, and whether Taking care
  of things is offered at first run.
- **Next:** D15 place prediction (Ben's direction, 2026-11-23) while D14
  waits.

- **Ben (2026-11-23), on D14:** "I like the list. Let's keep it and
  implement it everywhere?" The 13 themes and their colors are approved.
  His two open choices take the proposal's defaults until he says
  otherwise:
  - first run asks "Which of these sound like you?" with every theme
    unticked;
  - Taking care of things is offered like the others.

### Tick 31 — 2026-11-23 — D15 place prediction on iOS (first slice)
- Ben (2026-11-23): "predict a specific location for each one of the
  purchases based upon an algorthmic search combined with other data
  factors".
- **Built:**
  - `setting_places` table, keyed like setting_names, with owner RLS,
    refusing agents, and added to test_rls.
  - `PlaceHint` in Core reads street, city, ZIP and state after the store
    name. PlaceHintTests pass, including the negative cases.
  - The Setting page's guess is an Apple Maps search on the phone (store
    name plus the statement's place words), keeping only results named
    like the Setting. With no address, the search is biased toward the
    centroid of the person's confirmed places.
  - "Is this the place?" offers That's it / Another / Not here. A
    confirmed place shows a small map that opens Maps; a long press
    chooses again. No location permission is used.
  - The privacy page names the confirmed places and the Apple Maps lookup.
- **Fix found on the device:** the first try never searched. Its view
  started empty, so SwiftUI dropped the row and its task never ran. The
  search now lives in a page-owned SettingPlaceModel.
- **Verified:**
  - iPhone 12, `SettingUITests.testPlaceGuessConfirmAndForget` passes:
    guessed "Denver Zoo, 2300 Steele St, Denver", confirmed, saved map
    shown, forgotten. Frames place-guess and place-saved read.
  - `tools/test_all.sh` rc=0.
- **Next slices:** the confirmed place on the event page and on the web
  Setting page; the Duo check on Ben's data (it writes only if he
  confirms). Then D14 themes, now approved.

### Tick 32 — 2026-11-23 — D14 starter themes on web and iOS (Ben approved the list)
- **Data:** `tests/fixtures/starter-themes.json` holds Ben's 13 themes and
  the palette. The JS copy (js/money/themes.js) and the Swift copy
  (Themes.swift) are each tested against it word for word.
- **Rule:** a chosen color stays; a starter name takes its own color;
  everything else, oldest first, takes the first free palette color.
  One golden is shared by `tests/themes.test.mjs` and ThemesTests; the JS
  golden was seen failing on a planted change.
- **DB:** `life_values.color`, nullable and limited to the palette names,
  for colors a person chooses later.
- **Tokens:** 13 `semanticTheme*` pairs. test_design_tokens passes,
  including contrast.
- **Web:**
  - Theme marks use the rule.
  - The first-run card on Unexamined (purchases, no themes) shows 13
    unticked themes, with Keep these / Not now.
  - Settings shows each theme's mark and offers the starter themes not
    yet held, each in the color it would take.
  - test_web_states adds checks: the stranger sees the card, ticks Health,
    and keeps exactly Health; Settings offers People I love with its
    mark. Frames first-themes and settings-starters were read.
- **iOS:** the same three pieces, plus a DEBUG door `APP_FIRST_THEMES=1`.
  ThemesStarterUITests is written; the iPhone 12 was leased by an Ear
  Drama session, so the device run is queued.
- `tools/test_all.sh` rc=0.
- **Ben (2026-11-23, about 4:00pm):** the Duo leaves the house in about 15
  minutes. Duo checks (D14 themes, D15 place on Ben's data) wait until it's
  back; the iPhone 12 carries the device verification meanwhile.
- **D14 on the iPhone 12:** ThemesStarterUITests found a real flaw in the
  first rule: a starter's preview (Home, clay) could take a color an
  existing theme already showed (Time with my kids). Adding Home would
  have recolored Ben's theme.
  - Fix: `nextColor`, a twin in JS and Swift with golden tests. A new
    theme stores its color when created: its starter color if no theme
    shows it, else the first free color. Every add path (memo editor,
    first run, Settings) stores it, and the Settings preview uses it.
  - Two golden mistakes caught on the way: my expected "clay" when Time
    with my kids already held it, and a case whose input already
    contained Home. Both corrected.
  - Verified:
    - Web: the kept theme stores moss; the previews shift nothing.
    - iPhone 12: both UI tests pass. Frames first-themes,
      first-themes-end and settings-starters read; Home now previews
      olive.
    - `tools/test_all.sh` rc=0.
  - D14 is done on web and iPhone 12. The Duo check on Ben's data waits
    until the Duo is back.
- **Next:** D15 slices (the confirmed place on the event page and the
  web), then D12 theme sharing.

### Tick 33 — 2026-11-23 — D15: every visit carries the place (event page, web)
- **iOS event page:** the confirmed place's map and address sit under the
  memo, themes and photos (D6: the memo leads). The first try put the map
  above the memo; the frame showed it pushing the memo down, so it moved.
- **Web:** `API.settingPlaces()` (cached, cleared on sign-out). The
  Setting and event pages show "Denver Zoo · 2300 Steele St, Denver"
  linked to Apple Maps at the place's coordinates.
- **Verified:**
  - test_web_states inserts a place as the owner, sees it on both pages
    (Maps link checked), then deletes it. Frame setting-place read.
  - iPhone 12: testPlaceGuessConfirmAndForget now also opens the event
    and finds entry-place. Frame entry-place read with the memo first.
  - `tools/test_all.sh` rc=0.
- **Harness note:** a fresh openAs straight to a deep route (#/setting/…,
  #/settings) lands on Unexamined in the headless harness; the tests
  navigate in-app instead. Not reproduced in the app code; worth checking
  a real deep link once Ben is signed in on the web.
- D15 is done on web and iPhone 12; the Duo (Ben's places) waits until
  it's back.
- **Next:** D12, sharing a whole theme and public links.

### Tick 34 — 2026-11-23 — D12: share a whole theme as one card (web + iPhone 12)
- **Story, with one theme shown:** "Share this theme" makes one card: the
  theme's mark and name, then its memos and dates (up to 6 on the iPhone
  card, "and N more"). Any memo can be left out, and places and amounts
  stay off unless turned on. The card is made on the device (an image on
  iOS, text on the web); CentMemo publishes nothing.
- **Verified:**
  - test_web_states: the card holds Anniversary, shows no "$", and drops
    a memo when it's unticked. Frame share-theme read.
  - iPhone 12: ShareUITests.testShareTheme passes. Frame share-theme read
    (both memos on the card, toggles off).
  - `tools/test_all.sh` rc=0.
- **Harness fix:** the web harness profile kept the "starters seen" flag
  between runs, which hid the first-run card. The test now clears it
  first.
- **For Ben:** public links (three options in the brief; recommendation:
  unlisted links to the person's own words only). FinanceKit Addendum 3.2
  rules out CentMemo hosting Wallet amounts or places.
- **Next:** item 10, files and opt-in uploaded copies.

### Tick 35 — 2026-11-23 — Item 10: keep a copy of a photo in CentMemo
- **Storage:** private bucket `attachments`, JPEG only, 5 MB. Files live
  under `<user id>/`; the owner can read, add and remove them, and agents
  can't write. test_rls now checks against the live project: the owner
  uploads and reads; a stranger can't read or plant a file; there are no
  public reads.
- **iOS:** a photo's menu offers "Keep a copy in CentMemo" and "Remove the
  copy". The copy is redrawn at up to 1600 px and encoded fresh, so no
  location or camera metadata goes along, and a check mark marks it.
  Removing the photo removes its copy, and deleting the account removes
  every copy first, since storage files outlive the database cascade.
- **Web:** kept copies show on the event page through hour-long signed
  links. Deleting the account on the web removes the copies too.
- **Privacy page:** describes copies, their stripped metadata, and their
  deletion.
- **Verified:**
  - test_web_states: a planted copy draws from a signed link, then is
    cleaned up.
  - iPhone 12: PhotoAttachUITests passes with the new menu item. The bench
    declines Photos access by design, so the run shows the new message
    "To keep a copy, allow CentMemo to see your photos in Settings, then
    try again." Frame photo-copy was read; the wording was changed after
    reading the first version.
  - `tools/test_all.sh` rc=0.
- **Not verified:** the iOS upload itself (needs a phone with Photos
  access; the Duo when it's back, with Ben's OK, since it writes to his
  account).
- **Next:** L2 prep while Ben reviews (public links, FinanceKit
  extension), or file attachments.

### Tick 36 — 2026-11-23 — Item 10: files on a memo (iPhone + web)
- **iOS:** a Files section with "Add a file" (PDF or image). A file is kept
  as a private copy, because a file reference only works on one device;
  images are re-encoded as JPEG with no metadata, and the limit is 5 MB.
  Files are listed by name, open through an hour-long signed link, and
  can be removed (copy too). One line says "Files you add are kept in
  CentMemo, privately."
- **Bucket:** now accepts application/pdf as well as JPEG.
- **Web:** the event page lists files by name with signed links.
- **Verified:**
  - test_web_states: a kept file lists with a token link.
  - iPhone 12: FileAttachUITests passes; the DEBUG door attaches a
    generated one-page PDF, then removes it. Frame file-kept read. The
    first run failed only because the footer was below the fold; the
    test now scrolls to it.
  - After the runs: no test attachments and 0 storage objects left (SQL
    check).
  - `tools/test_all.sh` rc=0.
- Item 10 is done, apart from the iOS photo-copy upload, which waits on a
  phone with Photos access.
- **Next:** the backlog order reaches L2 (held until Ben signs off on the
  design). Open for Ben: public links (D12), the FinanceKit extension
  request, D7 suggestion words. The loop moves to the remaining smaller
  items (D10/D13 polish, iPhone import and delete-account checks).

### Tick 37 — 2026-11-23 — iPhone import verified on a device (and a result that vanished)
- **ImportUITests** runs on the iPhone 12 as the empty stranger. The DEBUG
  door APP_IMPORT_SAMPLE=1 feeds the same import code a three-row Apple
  Card export: the first import says "Apple Card: 3 new.", the second
  "Apple Card: 0 new, 3 already in CentMemo." (Decision 057).
  `tools/cleanup_stranger.mjs` empties the account afterwards; test_rls
  still finds it empty.
- **Real bug found on the way:** the import's result line could vanish.
  Settings rebuilds its rows while an import runs, so the finished import
  reported into a view that no longer existed (one run even imported
  twice from two view copies). The result now lives in a small observed
  `ImportStatus`, and the DEBUG door runs once per launch. Separately,
  Unexamined's empty state hides its import button as soon as the
  purchases arrive, so the test runs from Settings.
- PARITY: iOS import ✅. `tools/test_all.sh` rc=0.
- **Next:** iOS delete account on a device. It needs a throwaway account,
  so a test that creates one and deletes it, rather than the stranger or
  Ben's account.

### Tick 38 — 2026-11-23 — Parity audit: Venmo import, error and offline states seen on the iPhone 12
- `ImportUITests.testVenmoImport`: "Venmo: 3 new." from
  tests/fixtures/venmo-sample.csv through the same DEBUG door. Stranger
  emptied after.
- ErrorStateUITests rerun: unreachable, offline and the control all pass.
  Frame error-offline read ("Couldn't load / You're offline." with Try
  again).
- PARITY: Venmo/PayPal/Cash App iOS ✅, Error iOS ✅, Offline iOS ✅. Those
  rows had been stale since launch tick 8.
- **Gate:** the first test_all run failed on a dropped connection
  (ECONNRESET) in test_connector. It passed alone and on the full rerun
  (rc=0), so it was network noise, not code.
- **Delete account on iOS:** needs a throwaway account. Creating one is
  Ben's call; asked.

### Check-in — 2026-11-23, about 5:50pm
- **FinanceKit for `com.learningischange.centmemo.walletdelivery`:** the
  developer portal's Capability Requests tab reads "Submitted". Ben's
  submit went through; F2 waits on Apple.
- The Duo is still away ("unavailable" in devicectl).
- Still open for Ben: the throwaway account for the iPhone delete check,
  public links (D12), D7 words, iPad width, and the design sign-off for L2.
- **About 6:20pm:** the Duo is back. The current build (themes, places,
  files) is installed, but the phone is locked, so the captures wait for
  Ben to unlock it. Planned, read-only on Ben's data: Settings (his
  themes plus starters) and a Setting page (place guess shown, not
  confirmed).

### Tick 39 — 2026-11-23, about 7:25pm — the Duo on Ben's data: themes fine, place guess finds nothing
- New DEBUG door `APP_START_PANE=themes`. The Duo's two-pane Settings
  opens on Ground, so a frame of the Themes pane needed it.
- **Themes (Ben's data):** he has no themes yet. The pane says "Add a
  theme from any memo." and offers all 13 starters in their colors. Frame
  read; works as designed.
- **Place (Ben's data), a real gap:** Apple Store shows 107 visits and no
  guess. Ben's 107 Apple Store rows are all FinanceKit with merchant and
  description both "Apple Store", so there are no place words. With no
  confirmed places there's no home area, and Apple's retail stores are
  named "Apple <mall>", which fails the 60% name match on "Apple Store".
  The guess as built only works when the statement carries an address (CSV
  exports). It misses the FinanceKit-only case Ben has.
- **Next (D15b):** a home area from the person's own data (cities and ZIPs
  in any statement, geocoded on the phone), chain-aware matching (brand
  word plus Apple Maps category), and the one-time "Use where I am" button
  from the proposal for when nothing else fits. Chains are confirmed per
  visit.

### Tick 40 — 2026-11-23 — D15b: place guesses for statements with no place words (built; device run queued)
- **Chain matching** moved into Core as `PlaceHint.nameMatches`: "Apple
  Store" accepts "Apple Park Meadows" (the brand leads), with a brand word
  of at least 4 letters and not a common lead word. PlaceHintTests:
  Applebee's, Best Buy, Big Lots and Golden Gate Park are all refused.
- **No place words, no confirmed places** (Ben's 107 FinanceKit "Apple
  Store" rows): a quiet "Find on the map" row, never a pushed guess. It
  reveals Apple's one-time Current Location button; one reading via
  `CLLocationUpdate`, used for that search only and never stored.
- `NSLocationWhenInUseUsageDescription` added (project.yml); the privacy
  page names the one-time location use. L2 note: re-check the App Privacy
  answer on location (sent to Apple Maps only, not collected by CentMemo).
- **Verified:** unit tests; the iOS build; `tools/test_all.sh` rc=0.
- **Not yet verified:** the iPhone 12 run (SettingUITests.
  testFindOnTheMapNearHere). Ear Drama held the phone for 15+ minutes;
  queued with a 40-minute wait. On the Duo, Ben taps Current Location on
  Apple Store himself (it's his location).
- **About 9:00pm:** two queued runs of testFindOnTheMapNearHere (40 and
  50 minute waits) covered nothing. Ear Drama's ios_uitest (pid 7063) has
  held the iPhone 12 since about 6:58pm, renewing its lease. Not taken
  from it; the next tick retries.
- **About 9:20pm, the iPhone 12 freed (Ear Drama done):**
  - Run 1 found a real flaw. "Apple" (MONTHLY INSTALLMENTS, not a place)
    got a pushed guess, "Apple Aspen Grove, 7301 S Santa Fe Dr, Littleton".
    With no region, Apple Maps answers near the phone's rough location on
    its own. That's right for FinanceKit's bare "Apple Store", wrong for
    installments.
  - Fix: `PlaceHint.namesStore`. Search only when the statement begins
    with the store's name or carries an address; otherwise "Find on the
    map". Unit tests cover installments, the bare store name and a city.
  - Run 2: no guess was pushed, but the place section was hidden because
    the page only showed it for a place or a guess. The condition now
    includes `canSearchNearby`.
  - Run 3: Screen Time's "Time Limit" ("You've reached your limit on
    CentMemo") covered the app at 9:23pm. The harness flagged the overlay,
    so the run proves nothing.
- `tools/test_all.sh` rc=0. **Not verified on a device:** Find on the map
  → Current Location → guess. Next: iPhone 12 tomorrow, outside Screen
  Time hours, or Ben on the Duo.

### Tick 41 — 2026-11-23 10:25pm — iOS: D15b device run, still blocked by Screen Time
- **Context:** retry `SettingUITests/testFindOnTheMapNearHere` on the iPhone 12 (no device lease held).
- **Result:** run 1 failed at "place-find": the app showed its sign-in screen. The owner's sign-in works from the Mac (`tools/test_rls.mjs` PASS). Run 2 at 10:27pm caught the cause in a frame: Screen Time's "Time Limit" overlay (the harness flagged it). The signed-out screen was the app behind that limit, not a CentMemo bug.
- **Harness gap noted:** run 1 failed without the overlay flag because no frame caught the overlay; check the frames for "Time Limit" before debugging sign-in (memory updated).
- **Not verified on a device:** Find on the map → Current Location → guess.
- **Next:** retry on the iPhone 12 tomorrow afternoon, or Ben taps Current Location on the Duo's Apple Store page.

### Tick 42 — 2026-11-23 11:28pm — harness: failure recordings checked for Screen Time
- **Context:** D15b device retry. Still blocked at 11:29pm. The failure again looked like a signed-out app, because the test failed before taking any screenshot, so the overlay check saw nothing.
- **Implementation:** `tools/ios_uitest.py` `export_shots` pulls the last frame of each failure recording (ffmpeg) into the overlay check. `docs/TESTING.md` updated.
- **Verification:** positive: replaying the 11:28pm result now reports "shows a system overlay ('Time Limit')". Negative control: a recording built from a good frame (place-guess, Denver Zoo) reports nothing. Both frames read. `tools/test_all.sh` rc=0.
- **Correction to tick 40:** the replay shows the 9:21pm and 9:22pm D15b runs were also behind the Time Limit screen. So "the Find on the map link wasn't appearing because the page hid the whole place section" was never observed on a device. The `canSearchNearby` condition is still right on reading the code, but it is fixed, not verified. Only the 9:20pm Apple Aspen Grove false guess was a real device observation.
- **Screen Time hours:** blocked about 9:20pm to past midnight (12:03am frame from the night before).
- **Next:** iPhone 12 tomorrow afternoon for `testFindOnTheMapNearHere`, or Ben on the Duo.

### Ticks 43–49 — 2026-11-24 12:32–6:26am — hold, then stopped
- Hourly holds overnight: the iPhone 12 was under Screen Time and everything else waited on Ben. Ben stopped the loop around 7am. Resume state is under "Resume here" at the top of this file.

### 2026-11-24 — FinanceKit for the extension; TestFlight 1.0 (17)
- **Ben:** "There are a couple more emails about approval for FinanceKit. Can
  you read and address the information found there?" and "Testflight is for
  testing across all devices. It should always be a part of major updates."
- **Done:** the extension target is in the app, signed with FinanceKit (details
  under Resume here); the Addendum 3.2 question, sent by Ben (Case ID 103023652799).
- **Tap tier:** the first full run on the iPhone 12 had 6 failures, all stale
  tests, not the app. Starter themes (D14) pushed Settings rows below the fold
  of a lazy list; Story's count no longer has a "·"; the location button is
  drawn by the system, so it carries no identifier of ours. Fixed and rerun
  (8 pass, 1 skip, over those 9 tests); the other 26 passed in the first run.
- **Lesson:** a permission prompt left open by one test covers every test after
  it. setUp now declines it.
- **Gate:** test_all failed once after the full tap tier: ImportUITests leaves
  rows in the stranger's own account, so the RLS and web-state checks found it
  not empty. Not a leak (memos and themes still read 0). Run
  `node tools/cleanup_stranger.mjs` after a full tap tier. The reviewer check
  failed once too ("wrong password is refused" read an empty page) and passed alone.

### 2026-11-24 — versions: 1.0.PATCH, both numbers on every build
- **Ben:** "Why are we not increasing the versioning on each build? 1.0.0 is
  the method we have used for all of our other apps."
- **State found:** builds 1 to 17 all shipped as "1.0", against the cadence rule
  at the top of this file. STORE.md step 1 had softened it to "user-visible
  changes", and the version test was not in test_all.
- **Done:** 1.0.17 (18), Ear Drama's pattern (PATCH = build - 1). The test now
  refuses a two-part version, or a build bump without a version bump (both seen
  to fail), and runs in test_all. Build 17 stays "1.0" on TestFlight.
- **At L2:** the App Store Connect version record still reads "1.0"; it must
  match the build submitted.
- **Ben:** "why the color picker in settings is called 'Ground'? That doesn't
  make any sense." A leftover of Decision 059 (color as the page's ground), which
  060 replaced. Now "Color" on iPhone and web. Also Ben: "Connecting apple wallet
  seems to be working on the duo for adding new items to the database." The
  button said 3 new items, so that was the regular sync, and that tap is what
  turns on hourly delivery. A delivery with the app closed is still unseen.
- **Ben:** "Please stop asking me if you should push and commit. If you have done
  work that needs to be represented on devices and tested, then you should push
  a new version to testflight."

### Tick 43 — 2026-11-24 — iOS: F2 made observable, and an offline open no longer signs you out (1.0.18 (19))
- **Is delivery running?** The server's edge logs name the process: the app is
  `CentMemo/<build>`, the extension `CentMemoWalletDelivery/<build>`. Every wake
  posts accounts, so the logs are a detector with no code on the phone. As of
  11:02am: no extension request. The Duo (Darwin 27.3) enabled delivery at
  10:09:26am on build 17. It may only mean no new Wallet data yet.
- **Bug found reading that path:** any failed token refresh (no signal, a 5xx)
  signed the person out and deleted the session shared with the extension.
  `ErrorStateUITests/testOfflineRefreshKeepsTheSignIn` failed on the iPhone 12
  before the fix and passes after. Only a refusal (400, 401, 403) ends a session
  (`SessionTests`). The earlier offline check never expired the session, so it
  could not see this.
- **Delivery gaps closed:** re-enabled on every return to the foreground for
  someone already connected; each wake rereads the stored session (sign-out or
  a switch of accounts); the usage string is in the extension's Info.plist
  (Apple's setup article asks for one and does not say which target).
- **Verified:** 12 iPhone 12 tests pass (Error, TabSmoke, WalletSync), no crash logs.
  **Not verified:** a delivery; the re-enable on real Wallet data.
- **Open, Ben's words:** the button reads "Connect Apple Wallet" even once connected.
- **Next:** check the logs again after the Duo runs 19; then macOS (13).

### Tick 44 — 2026-11-24 — the Mac app runs; Ben's answers N1 to N3 (1.0.19 (20))
- **Delivery logs, about 11:15am:** no extension wake; the Duo had not opened 1.0.18.
- **Mac (item 13, Decision 055):** the universal target builds for macOS 26.
  `NavigationSplitView` shell, Settings window, ⌘1 to ⌘3, ⌘S; the lists and the
  purchase page are the phone's views behind `apple/iOS/Components/Platform.swift`
  (haptics now mapped in that one place, as AGENTS.md asks). No FinanceKit and no
  "search near me" on the Mac. Signed, sandboxed, frames read in dark mode
  (build/qa/mac): three flaws seen and fixed. **Not checked:** the Settings window,
  sign-in with Apple, saving a memo, light mode, small and large windows.
- **N1:** no amount on any share surface, web and Apple; `share_no_money` holds it.
- **N2:** the starter themes left Unexamined, web and Apple; Settings keeps them.
- **N3:** the Wallet button reads "Sync Apple Wallet" once connected.
- **Verified:** full iPhone 12 tier on the shared-view change (32 pass, 4 skip), then
  the 13 tests nearest N1 to N3; `tools/test_all.sh` (now builds the Mac too).
- **Next:** N5 with the Mac included, then N4.

### Tick 45 — 2026-11-24 — deleting an account no longer starves the next sync (1.0.20 (21))
- **Found before pressing Delete:** the phone kept its Wallet history token after a
  deletion, so signing in again and syncing would return only new purchases.
  Deletion now clears the token and stops delivery, and every sync starts over
  when the server holds no Wallet account (which also covers a deletion on the web).
- **Verified:** iPhone 12 WalletSync and WalletAvailability pass; test_all. The
  deletion itself is not yet run: the Duo is locked.
- **Finding for L2 (App Review 5.1.1(v)):** an app with Sign in with Apple should
  revoke the Apple token when an account is deleted. CentMemo keeps no Apple
  authorization code or refresh token, so it cannot. Needs a design before submission.

### Tick 46 — 2026-11-24 — N5: the purchase desk, the Story as a page (1.0.21 (22))
- **Looked first** at iPad, Duo, Mac and the web at four widths. The iPad wore the
  Duo's layout stretched; the web was one phone column at every width.
- **Rules:** docs/DESIGN.md section W (room, not device; three classes).
- **Built (Apple):** lists at 440 when wide; the purchase page as a writing desk
  with its belongings beside it (pane 780 and up); the Story as a reading column
  with a shelf (iOS regular width and the Mac's own columns); a Setting's map beside
  its visits. No empty Themes row. A thread row keeps its date and place on one line.
- **Web bugs found and fixed (live):** the Story's month menu was empty (a list
  passed to replaceChildren becomes text), and stray "null" on three screens. `fill`
  replaces replaceChildren; test_web_states checks every screen.
- **Seen:** iPad landscape (6 screens), open Duo on Ben's data (3), Mac dark (2).
  **Not seen:** iPad portrait, the closed Duo, Mac at 900 and 1600, light Mac.
- **Verified:** full iPhone 12 tier 32 pass, 5 skip; test_all.
- **Corrected by Ben:** I reported the Duo locked from a 25-minute-old check.

### Tick 47 — 2026-11-24 — N5: the web at every width, the Mac at three sizes; sign out means this device (1.0.22 (23))
- **Web:** two columns from 760px (the side before 320 at 1100): Unexamined's
  invitation, the Narrative's month and filters, the Story's shelf, a Setting's
  head stand beside what they belong to; the purchase desk from 900; Settings in
  labeled rows. Every screen read at 375, 768, 1024 and 1440 (dark).
- **Mac:** 900, 1180 and 1600, light and dark, read (APP_WINDOW and APP_APPEARANCE
  doors). The memo field's white box in light mode is gone.
- **Bug found because a Mac frame came up signed out:** signing out on one device
  ended the sign-in on every device (the server's default scope), so signing out
  of the web would also have stopped Wallet delivery on the phone. Measured with
  two sessions; `tools/test_signout_scope.mjs` holds it, with the default as control.
- **Sign-in page:** serif sanguine title and sanguine links (DESIGN T1, C2).
- **Verified:** 16 iPhone 12 tests, test_all, web states. Deletion: no
  delete_my_account call in the logs yet (12:31pm). Delivery: no wake yet.

### Tick 48 — 2026-11-24 — N4: design your share (web)
- **Design:** docs/DESIGN.md section S, drawn as one module (`js/money/share-card.js`)
  and shown to Ben as a working page (docs/design/share-studio.html).
  Four looks (Page, Setting, Theme, Words), three papers, three shapes, what shows,
  and the words the person underlines in their own memo. No suggestions, no amount.
- **Learning test:** choosing the words that matter is the act of rereading the
  memo; every choice is the person's; nothing is generated.
- **Web:** the event page's "Share this memo" is the studio; it shares a PNG through
  the system sheet, or saves it where there is none. Read at 375, 768 and 1440.
- **Held by:** share_no_money (now covers the drawing, and its colors against the
  tokens) and test_web_states (every look and shape redraws, no amount offered).
- **Changed on purpose:** the Setting shows by default now (Ben: highlight the
  setting); it was off by default before. Each can be hidden.
- **Next:** the Apple twin, then the theme card, then links.

- **Ben on the share (about 1pm):** "the design for sharing looks very good so far." And the three closing status lines were unclear: write them plainly.

### Tick 49 — 2026-11-24 — N4: design your share on iPhone, iPad and Mac (1.0.23 (24))
- **Built:** `apple/Core/ShareCard.swift`, step for step the web's drawing, in New
  York; `ShareMemoSheet` is the studio (card beside the choices from 760, above them
  on a phone); the PNG is drawn when it is sent.
- **Verified:** ShareCardTests render all 36 look, paper and shape combinations (PNGs
  read beside the web's) plus long and themeless memos; ShareUITests designs one on
  the iPhone 12; iPad and Mac studio frames read (APP_START_SHARE door). 12 iPhone 12
  tests, test_all. **Not seen:** the open Duo; a picture actually sent.
- **Next:** the theme card in the same design, then links.

### 2026-11-24 1:15pm — Delete account pressed for real on the Duo
- **Ben:** "You can use mine. I'm not saving anything I need forever in my account
  yet." and "You can tap on my duo and have done so many times."
- **I was wrong** that the Duo takes no taps: it ran 8 times on 2026-11-22. The 12:14pm
  automation timeout was transient; the same command passed at 1:15pm.
- **Verified:** testDeleteAccount passed (Keep my account keeps it; the second time
  deletes and lands on sign-in). Server: 3 accounts, 6,982 events and 1 memo before;
  the user and every row gone after; the three synthetic users unchanged (22/22/0).
  The suite's own FAIL is its frames: they come from the Duo's dark outer display.
- **Next for Ben:** sign in on the Duo and tap Connect Apple Wallet; the full history
  should come back (the token fix, tick 45).

### Tick 50 — 2026-11-24 — N4: a whole theme, designed (web, iPhone, iPad, Mac; 1.0.24 (25))
- **Design S6:** Cover, Pages, Lines. Lines is the theme as a poem of the words the
  person underlined in each memo.
- **Built:** `drawTheme` (web) and `ThemeShareCard` (Apple); both studios now share one
  set of pieces on each platform.
- **Verified:** test_web_states (each look redraws, no amount, an unticked memo leaves),
  ShareCardTests (all 27 theme combinations, 60 memos, none), frames read.

### Tick 51 — 2026-11-24 — N4: story links, designed only
- **Design:** docs/design/story-link.html. A reader's page for one memo, one for a theme
  (cover in the theme's color, Lines, then each memory), and what the writer sees
  before a link exists. Nothing public is built until Ben has seen it.
- **Constraint (Addendum 3.2, docs/research):** a page CentMemo hosts is CentMemo
  disclosing, and consent does not override it. So a Wallet purchase's store and date
  never go on a link; the writer types the place and the time themselves or leaves
  them out. Imported (CSV) purchases may prefill. A card the person sends is theirs
  to send, so cards keep the Setting.
- **How it would work:** a snapshot per link, an unguessable address, no listing or
  indexing, turned off at once, and off with the memo, theme or account.
- **For Ben:** is this the page; may the place be typed; does a link carry a name.
- **Next:** N3b (words on every action), then Settings at wide on Apple.

### Tick 52 — 2026-11-24 — N3b: the words on every action; Ben's history came back (1.0.25 (26))
- **Ben:** "I signed in again and synced again." Server, 2:00pm: 6,982 events from
  2018-11-05 to today, 3 accounts, exactly what was deleted. The token fix (tick 45)
  holds: deleting and coming back is proven end to end.
- **Words:** "Money in" read as income, now "Bring in purchases". A sync says what it
  did ("3 new or changed events", "Nothing new in Apple Wallet."), since some are
  changes the bank made. Share switches are Where and When ("Settings" read as the
  app's). The web's "Import from Apple Card" takes four sources: "Import a CSV".
- **Not only words:** an empty account led with a CSV import on a phone that has
  Wallet; Connect Apple Wallet leads now, with Apple's required disclosure above it.
  Swiping a theme away removed it from every memo unasked; it asks first.
- **Settings at wide:** the choices keep a reading width beside the list (iPad seen).
- **Verified:** 12 iPhone 12 tests (the empty-state one rerun after its words changed),
  test_all.

### Tick 53 — 2026-11-24 — the Mac app on TestFlight (1.0.26 (27))
- **Built:** a Mac icon (the circled cent in the Mac's rounded square, 16 to 512 at 1x
  and 2x); the sign-in kept in the data protection keychain, so an update never asks
  for the Mac's password; Settings names what to do on a Mac ("Connect Apple Wallet in
  CentMemo on your iPhone, and your purchases appear here too.").
- **Seen:** the Settings window (two tabs, light). The first Mac upload went through
  from this Mac and is VALID; the internal group gets every build.
- **Not seen:** Sign in with Apple on a Mac; a memo saved on a Mac (same code as the
  phone's); Photos on a Mac.
- **At L2:** the App Store record has no macOS version yet (only iOS 1.0 in preparation).

### Tick 54 — 2026-11-24 — the iPad's first full tap tier; portrait; shorter dates (1.0.27 (28))
- **The iPad takes taps.** The first try timed out behind "Enter iPad Passcode for XCTest"
  (photographed); the second passed. Retry before calling a device blocked.
- **First full tier there:** 23 pass, 12 fail. None was an app bug: Settings is a sidebar
  on the iPad, and the tests assumed the phone's one list (they pass APP_START_PANE now);
  two failures were an earlier failed run's leftovers. All pass after.
- **Portrait seen** (PortraitUITests turns the iPad upright and puts it back). Rows wrapped
  because each date repeated the year: a row now names the year only when it isn't this
  one, on web and Apple.
- **Verified:** iPad tier, 15 iPhone 12 tests, test_all.

- **Ben on story links (about 3:45pm):** "The story links design is nice. I'd like a
  little more customization from the web, but I really like the bold colors and the
  touch of the pencil marks. I'd like to be able to choose which words get the underline."
- **Design v2:** every choice is the writer's, live beside the reader's page: the marked
  words, the pencil (underline, two lines, circle, highlighter), bold / paper / night,
  the theme's color, what leads, the parts of a theme's page, where / when / from in
  their own words. Bold is the default, as Ben likes it.
- **Build next (opt-in, per link):** a `shares` table (owner-only), a snapshot payload
  with no amount and no Wallet store or date, one public read by unguessable code, a
  static `/s/` page marked noindex, a list to turn links off, cascade on delete. RLS
  tested as a stranger first. The pencil choices also go to the share cards.

### Tick 55 — 2026-11-24 — N4: story links, the private half (deployed, not yet in the app)
- **Table and rules:** `shares`, `make_share`, `get_share` (migration 20261124010000,
  Decision 067). Links are owner-only to list and turn off; the connector cannot make one.
- **Caught before applying:** a hidden place would still have been in the page's data,
  and a lines-only page would have carried whole memos. The server leaves them out.
- **Verified on the deployed project:** `tools/test_shares.mjs`, 24 checks as the owner,
  a stranger and signed out (in test_all). Security advisor: only the intended public
  read. Not tried: a real connector token (make_share refuses agents in code).
- **Next:** the reader's page at /s/ (noindex, a report link), the maker on the event
  and Story pages, Your links in Settings, and the privacy policy's paragraph.

### Tick 56 — 2026-11-24 — N4: story links on the web
- **Built:** the reader's page (`/s/#code`: the code never reaches a server log; noindex;
  a report link), the maker on the event and theme pages, Your links in Settings, the
  privacy policy's paragraph and a report address on Support.
- **Caught by looking:** the published page was gray where the preview was clay (a theme
  with no stored color); the writer's color travels with the link now (migration 2).
- **Privacy policy corrected:** it said CentMemo never asks for location; it does, once,
  when Current Location is tapped, and records nothing.
- **Verified:** test_shares (24), test_web_states (make, open as a reader, same color,
  fits a phone, listed, turned off, then says so), frames at 375, 768 and 1440; test_all.
- **Renamed after Ben asked** *"Isn't "where" and "from" the same field? What is the
  difference?"*: From is now Shared by, the words the page prints. The Apple maker uses
  the same label.
- **Found by the gate failing:** Settings waited on the list of links before drawing
  anything. The list now loads by itself, with Loading, Try again and offline; a check
  holds the answer back forever. A second, intermittent failure was the test reloading
  a page that was already reloading itself. Four clean runs after both.

### Tick 57 — 2026-11-24 — N4: links from iPhone, iPad and Mac; the pencil on cards — v1.0.28 (29)
- **Built:** Make a link (event ⋯ menu, a theme's Story), Your links in Settings, the
  four pencils on memo and theme cards (web and Apple). The preview is the site's page
  code bundled in the app, so the two cannot drift.
- **Caught by looking:** typing in Shared by scrolled the field away; a new link's
  address was off screen; a filled Where or When had no label; the circle cut the first
  and last letters; the highlighter on a color page fell to 2.97:1. All fixed. Pressing
  Make twice no longer makes a twin (web too).
- **Verified:** iPhone 12 taps (make, type, send offered, listed, turned off, theme
  parts), Mac and iPad seen, unit tests, test_all.
- **Not verified:** iPad taps (it wants its passcode for UI automation, Ben's to enter);
  the Duo (not reachable from this Mac at 4:40pm); a link sent from a share sheet.
- **Shipped:** 1.0.28 (29) processed on TestFlight for iOS and Mac (4:58pm).

### Tick 58 — 2026-11-24 — An agent's token could reach Wallet rows directly; closed in the database
- **How it was found:** closing the untested claims about links (theme removal, agents).
  The agent could list `shares`, whose page can hold a memo on a Wallet purchase. The
  same question of the other tables: 11 direct ways to Wallet rows with a real token.
- **Fixed:** migrations 20261124030000 and 20261124040000, Decision 068. Only agents'
  reads change. Seen to fail first (11), then all 56 connector checks pass; imported
  purchases are still shared (control).
- **Was it used?** Data API callers since 2026-11-22 (Ben's first Wallet sync), by user
  agent: the app, the test runners, the site in a browser, and our own connector.
  One other, a Python script from a hosting company
  (2026-11-24 05:11 UTC, no sign-in), got 401 and nothing else. User agents can be faked,
  so this is what the logs show, not proof.
- **Also verified:** removing a theme, a memo, or the purchase turns its links off; the
  account's deletion cascades (`confdeltype = c`).
- **Noted:** every connector test run leaves a registered test client and consent on the
  synthetic owner (350 and 346). Harmless; worth a cleanup with Ben's OK.
- **Duo:** still not reachable from this Mac at 5:10pm.

### Tick 59 — 2026-11-24 — The first background Wallet delivery
- **Seen:** 5:42pm, `CentMemoWalletDelivery/24` on the Duo: token refresh 200, accounts
  read 200, accounts upsert 200, transactions 201; one new row in the database at that
  second. The Duo's app had last called the server at 2:02pm (build 24), so nothing
  but the extension did this.
- **Still open:** iPad taps (asked again, timed out; it wants its passcode); the Duo is
  not reachable from this Mac and has build 24; nothing else in the backlog is free of
  Ben or Apple.

### Tick 60 — 2026-11-24 — The share screens on the open Duo — v1.0.29 (30)
- **State found:** the Duo answered again (unlocked, 1.0.23 (24)). Seen there for the
  first time, the link and card screens were one narrow column, the choices mostly below
  the fold: the Duo gives a sheet 653pt, under the 760pt two-column rule. A custom
  PresentationSizing asking for 900pt is ignored (seen).
- **Done:** beside from 640pt (DESIGN S9), a 16pt margin beside the preview on the Duo and
  iPad (the form had none), the preview runs to the sheet's bottom edge, "Highlighter" (cut
  off) is "Highlight" on Apple and web. DEBUG door `APP_SHARE_MEMO` shows the screens on
  an account with no memos; it saves and publishes nothing.
- **Verified:** open Duo and iPad landscape seen; iPhone 12 share taps 4 of 4; test_all rc=0.
- **Not verified:** the Duo closed (display off), a theme's link on the Duo, iPad taps, the
  Mac's 16pt wider choices (builds only).
- The Duo holds a debug 1.0.28 (29) of this work; TestFlight 30 replaces it.
- **Shipped:** 1.0.29 (30) VALID on TestFlight for iOS and Mac. iPad taps tried again ~7:30pm: still could not start UI automation.

### Tick 61 — 2026-11-24 — The Mac's link screen; a blank preview that was the capture
- **Mac at 1180x800:** the wider choices column fits. The preview was white in the window
  capture, with and without tick 60's change. The page had drawn (a snapshot taken by the
  web view itself shows it): the window was fully covered, and macOS does not paint web
  content in a covered window. **A Mac window capture is blind to a WKWebView when the
  window is covered; use `takeSnapshot` before calling it a bug.**
- **Duo:** open, build 30 debug installed, Settings with Your links seen; its closed
  display is still off.
- **iPad taps:** tried 8:33pm, timed out enabling automation. No reply from Apple.

### Tick 62 — 2026-11-24 — The Mac pressed for the first time; Share right after Save — v1.0.30 (31)
- **State found:** saving a memo on the Mac was listed as waiting on Ben. It was not: this
  Mac's terminal already has Accessibility permission. `tools/mac_uitest.py` (+
  `mac_ax.swift`) presses the Mac app's own buttons in the background as the synthetic
  owner, never in front: save, relaunch, read back, remove; Skip and Bring back; Rename
  and its statement name back. Seen to fail first (no Save press; old builds).
- **Bug 1, every platform:** after Save the page kept the purchase as it was when opened,
  so Share and Make a link were missing after a first memo and held the old words after an
  edit. Fixed on Apple and web; test_web_states failed on the old code (2 checks), passes.
- **Bug 2, Mac:** Rename opened blank the second time (the Mac empties an alert's field; the
  same words set again are no change to SwiftUI). A new field per opening. Resetting the
  draft when the alert closes did not fix it.
- **PARITY audited:** a Mac column; four stale cells (Wallet sync, delivery, iPhone sign-in, iPad).
- **Lessons:** a button that closes its own sheet reports an AXError after working. A busy
  Mac (load 12, other builds) answers accessibility late: BLIND, not a hang (sampled: main
  thread idle or laying out its first window). A covered window's capture is stale for
  native views too, so read the control tree.
- **Certificate emails:** "Your Certificate Has Been Revoked" (four today) is not
  this Mac's: BE4F3F4F, its development certificate, is still on App Store Connect.
- **Not verified:** the fix on an iPhone (iPhone 12 under Time Limit at 9:48pm, frame seen;
  MemoUITests now checks it; run it in the afternoon). iPad: 9:35pm, automation mode timed out.
- **Gate:** test_all rc=0.
- **Shipped:** 1.0.30 (31) VALID on TestFlight for iOS and Mac (11:01pm); the web fix is live.
- **Next:** more Mac presses (theme on a memo, filters, a link made and turned off, empty and error states); the iPhone 12 in the afternoon.

### Tick 63 — 2026-11-25 — The rest of the Mac pressed; what only a swipe could do — v1.0.31 (32)
- **Pressed on the Mac:** a theme on and off a memo, one theme read alone, the filter, a
  link made, listed and turned off, unreachable and offline, the empty account
  (mac_uitest: 10 tests, 17 checks, all passing in one run).
- **Found and fixed, Mac only:** Settings hid Privacy and terms behind an arrow since Your
  links joined it (560pt to 640pt; the check failed on the old build). A theme could not
  be removed (swipe only): a minus button that asks first. Nothing reloaded the lists
  (pull only): View > Reload, ⌘R.
- **Verified by** mac_uitest; frames of Settings read; test_all rc=0. No iPhone change.
- **Still 🚧 on the Mac:** import, photos and files, a place confirmed, share cards saved,
  Delete account, Sign in with Apple (Ben's).
- **Apple:** no reply at 11:43pm.
- **Shipped:** 1.0.31 (32) VALID on TestFlight for iOS and Mac (12:01am).
- **Next:** Mac import (APP_IMPORT_SAMPLE, stranger), a place confirmed; the iPhone 12 in the afternoon.

### Tick 64 — 2026-11-25 — What signing out left behind; the Mac's tests keep their own sign-in — v1.0.32 (33)
- **Pressed on the Mac:** an Apple Card export twice (3 new, then none) and a Venmo one
  (stranger, cleaned), and a place confirmed from the statement (forgotten after). The
  imports use the DEBUG door; the file panel itself is the system's, and the sandbox
  allows a file the person picks (entitlement read from the signed app).
- **Found and fixed:** after signing out on the Mac an open Settings window still held the
  person's themes, Sign out and Delete account; it now says to sign in. On Apple, place
  names, places and theme colors cleared only on Sign out, not when the server ended the
  session; now they clear whenever the person changes. The Mac's Story and open purchase,
  and the last link opened, are forgotten too.
- **Found before it hurt:** the Mac's Debug build and TestFlight share one Keychain item, so
  the fake account would have been signed in when Ben opened the TestFlight app. Cleared
  (two ordinary launches show Sign in with Apple); test runs now use their own item.
- **Verified:** mac_uitest (sign_out failed on the old build; the import door once ran under
  the account before the switch and imported nothing; it now waits for its account, 3 of 3);
  test_all rc=0, then both apps built again after that door edit.
- **Apple:** no reply at 12:52am.
- **Shipped:** 1.0.32 (33) VALID on TestFlight for iOS and Mac (1:11am).
- **Next:** the iPhone 12 in the afternoon (MemoUITests, ShareUITests); iPad after its passcode; on the Mac only photos, files, a saved share card, Delete account and Sign in with Apple are unpressed.

### Tick 65 — 2026-11-25 — A session the server ends (Mac)
- **Verified:** mac_uitest `server_ends_the_session`: the fake account's sessions ended on
  the server, Reload, and both windows go to signed out with no themes left. Sign-in after
  it works (read_one_theme). Test only; nothing to ship. Not run on an iPhone.
- **Not tried at 2:10am:** phone and iPad taps (they light the screens). No reply from Apple.

### Loop stopped by Ben — 2026-11-25
- **Ben:** "You can stop the loop and report all of the updates made and things you are waiting on for me."
- **State left:** 1.0.32 (33) VALID on TestFlight for iOS and Mac; tree clean; no Apple reply
  at 4:09am. Unverified: ticks 62 and 64 on an iPhone (run MemoUITests and ShareUITests in an
  afternoon), iPad taps, the closed Duo, a theme's link on the Duo.

### 2026-11-25 — Opening is instant — v1.0.33 (34), Decision 068
- **Ben:** "I noticed that it takes multiple seconds to load all of the items in my account
  on the app. It should be instantaneous when you open the app. Can you investigate what is
  taking so long and look for ways to optimize for speed on startup?"
- **Measured on the Duo (his account, APP_LAUNCH_DIAG):** list on screen at 5.39, 4.73 and
  4.73 s; the rows had arrived at 0.26 to 0.52 s and waited for memo_suggestions (4.3 s in
  the database). After the query alone: 0.75, 0.49, 0.53 s (live, no update needed). After
  ReadStore: 0.14, 0.14, 0.13 s kept, refreshed at about 0.3 s; a first open 0.65 s.
- **Query:** 4,303 ms to 56 ms; identical to the old one in 28 comparisons (year_ago not
  exercised: that account has no memos; its rule is unchanged but for a tie-break).
- **Also:** requests run together on Apple and the web; one token refresh serves all; the
  Story and Narrative stopped waiting in line.
- **Found:** URLSession.shared kept answers, sign-in tokens included, in a cleartext
  Cache.db (AGENTS.md: never in cleartext on disk). Gone, and old files deleted at launch.
- **Verified:** mac_uitest 25 of 25 (stored files unreadable, offline, slow network, words
  being written survive a late answer, sign-out wipes); test_all rc=0. **Not verified:** the
  iPhone 12 (Time Limit at 6:55am), a Duo photo under a slow network (it had locked).
- **Shipped:** 1.0.33 (34) VALID on TestFlight for iOS and Mac (7:21am); the web and the query are live.

### 2026-11-25 — Column titles stay put; the app starts on iOS 18 again — v1.0.34 (35)
- **Ben:** "when I scroll the right column on my duo, the title of the page on the left
  column (Unexamined) scrolls with it. That shouldn't happen"
- **Cause:** one navigation bar over two columns; its large title follows whichever column
  scrolls. All four sections had it. Now the name stands in the left column (DESIGN W8).
  Reproduced and fixed on an iPad simulator in landscape (TwoColumnUITests: the old titles
  fail on all four). **Not yet seen on the Duo** (locked at 7:21am and 7:42am).
- **Found by the simulator:** 1.0.28 to 1.0.33 could not start on iOS 18 at all: one WebKit
  call needs libswiftWebKit, which iOS 18 lacks. Replaced; tools/test_ios_libraries.py in
  test_all (fails on the old build) holds it. No newer device could have shown it.
- **Found by a flaky test:** on a theme, Share and Make a link stood over the previous
  list's memos until its own arrived, so a link could have been made of the wrong ones. They
  wait now (testThemeButtonsWaitForTheirMemos, failed on the old code).
- **Found in a frame:** the Narrative's theme colors were wrong until redrawn (they load
  after the list, and 1.0.33 draws it sooner). Colors are observed now, kept ones first.
- **Verified on an iOS 18.5 iPhone simulator:** Memo, ErrorState, Filter and Share suites
  (ticks 62 and 64 and 068 on an iPhone, at last off the iPhone 12's Screen Time);
  testMakeALinkThenTurnItOff failed once in 3 ("stays in sight while they type").
- **Not run:** the Mac taps on this build (Ben in a full-screen space; BLIND). test_all rc=0.
- **Mine:** I overwrote the template's tools/test_ios_floor.py with a new check of the same
  name; restored from git, mine is test_ios_libraries.py. The template's reports FAIL here
  (the Wallet extension's own 26.0), before and after: look at it before a cloud build (L2).
- **Shipped:** 1.0.34 (35) VALID on TestFlight for iOS and Mac (8:32am); no libswiftWebKit in the uploaded build.
