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
- Verify with `tools/test_all.sh`, plus the device tiers on the iPhone 12
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
2. ⏳ **App Store Connect app record**: name CentMemo, bundle
   `com.learningischange.centmemo`, category Finance, SKU, primary language
   English (US).
3. ⏳ **TestFlight**:
   - Archive, export, and upload with the API key.
   - An internal testing group with Ben.
   - Export compliance is already declared (`ITSAppUsesNonExemptEncryption NO`).
   - Bump both version numbers.
   - Note: the dev Mac's Xcode works for TestFlight. An App Store submission
     later goes through the cloud build (`cloud-appstore-submission`).

### Documented work
4. ⏳ iOS parity with the web's drawn marks: the circled Unexamined count and
   the Ledger rule (PARITY / DESIGN M1).
5. ⏳ Connector end to end:
   - Connect the MCP server in Claude Code through the real OAuth consent
     page as the synthetic owner.
   - Call all six tools.
   - Record the results.
6. ⏳ Connector documentation page on centmemo.com. The Connectors Directory
   requires public docs and a privacy policy (the policy exists).
7. ⏳ iOS FinanceKit sync path wired end to end with the DEBUG sample source:
   - Settings: Connect Apple Wallet.
   - Accounts and transactions upsert as `source = 'financekit'`.
   - History tokens are kept per account.
   - The connector excludes these rows (already in code).
8. ⏳ Web: verify account deletion, plus the empty, error, and offline
   states at 375px.
9. ⏳ The iPad Pro on the bench: run the tap tier there (the stand-in
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
