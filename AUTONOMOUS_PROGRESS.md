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
  skipped it and missed a manifest drift), plus the device tiers on the iPhone 12
  (`tools/ios_uitest.py`, `tools/ios_run.py`) for iOS work.
- One commit per tick. Bump both iOS version numbers on iOS-touching ticks.
- The agent is never the tester of record: Ben plays.
- No handwriting fonts; color is a mark, never a ground (memories).

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

### Documented work
4. ✅ (tick 3) iOS parity with the web's drawn marks: the circled Unexamined count and
   the Ledger rule (PARITY / DESIGN M1).
5. ✅ (tick 4) Connector end to end:
   - Connect the MCP server in Claude Code through the real OAuth consent
     page as the synthetic owner.
   - Call all six tools.
   - Record the results.
6. ⏳ Connector documentation page on centmemo.com. The Connectors Directory
   requires public docs and a privacy policy (the policy exists).
7. ✅ (tick 6) iOS FinanceKit sync path wired end to end with the DEBUG sample source:
   - Settings: Connect Apple Wallet.
   - Accounts and transactions upsert as `source = 'financekit'`.
   - History tokens are kept per account.
   - The connector excludes these rows (already in code).
8. ✅ (tick 7) Web: verify account deletion, plus the empty, error, and offline
   states at 375px.
9. 🟡 (tick 8: glass tier 5/5; tap tier blocked on Ben) The iPad Pro on the bench: run the tap tier there (the stand-in
   device, never yet run).
10. ⏳ Photos and files attached to a memo by reference (M2, Decision 055
    attachments table; `money-story-design`).
11. ⏳ Upstream to UniversalAppTemplate:
    - The three new skills.
    - The color-search tools.
    - The test_grounds pattern.
    - The device-harness lessons from docs/PROVENANCE.md.
12. 🔮 Shared stories at a public URL (opt-in per story).
13. 🔮 macOS through the universal target.

### Blocked on Ben (not loop work)
- iPad Pro UI automation: unlock the iPad, then Settings > Developer >
  Enable UI Automation (and allow it if a prompt appears). The tap tier
  times out with "Timed out while enabling automation mode" until then.
- Sign in with Apple on the iPhone: sign out of the test account in
  Settings, then sign in.
- The Claude Duet test: add the connector on claude.ai, then ask once live
  and once in a scheduled task.
- The FinanceKit entitlement: waiting on Apple.

## Pending asks
(none)

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
