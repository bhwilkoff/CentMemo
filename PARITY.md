# CentMemo: Cross-Platform Feature Parity

> **Single source of truth** for what's shipping where. Updated in
> the SAME change set as any user-facing feature.
>
> Companion to `AGENTS.md` (project context), `SCRATCHPAD.md` (active
> milestone), `DECISIONS.md` (architecture decisions). Per-platform
> design rules live in `iOS-DESIGN.md` (iOS), `macOS-DESIGN.md` (macOS),
> `tvOS-DESIGN.md` (tvOS), `WEB-DESIGN.md` (web), `ANDROID-DESIGN.md`
> (Android) when those binding docs exist. The full workflow
> (including the periodic parity audit) is the
> `cross-platform-parity-discipline` skill.

Base platforms: **web · iOS/iPadOS · macOS · tvOS · Android.** The three
Apple platforms (iOS · macOS · tvOS) are adjacent in every table because
they share one Swift Core. A Core change usually moves all three columns
at once, so verify each still builds.

Extended surfaces, added as COLUMNS when adopted (each is a form factor
of an existing build, not a new codebase; see Decision 028): **Android TV /
Fire TV** (the Android app's TV form factor) and **Web-TV** (webOS /
Tizen / Cast, the web app's additive TV layer). **Windows** (Decision
029) is an optional sixth full platform with its own column and its own
authoritative parity doc (`docs/windows/` pattern: a WINDOWS-PARITY.md
mirroring this file's rows). A feature that ships on phone/desktop but
not its TV form factor gets ⏳ with a reason, never silence. The
recurring audit finding is parity that lands on new platforms without
returning to the platform it started on.

> **Last audit: YYYY-MM-DD**: <what was walked + which false cells it
> caught, e.g. "walked every shipped feature; found 3 cells claiming ✅
> that were actually stubs">. Run the periodic audit from the
> `cross-platform-parity-discipline` skill and record the date + findings
> here every time. Day-to-day updates miss silently-false cells; only a
> deliberate sweep catches them.

---

## 0. Platform set

Decision 055. Audited 2026-11-22 (tick 16): every ✅ below has a test or an
observation from 2026-11-21/22 behind it; built-but-unseen is 🚧.

- **Web** (centmemo.com): import, write, ledger, story, connector consent.
- **iOS/iPadOS**: TestFlight 1.0 (5). The only FinanceKit source.
- **macOS** 🚧: on TestFlight through the universal target (1.0.26 (27)); no FinanceKit on Mac; sign-in not yet pressed there.
- **tvOS** 🚫: writing and reflection, not lean-back.
- **Android** 🚫: FinanceKit is Apple-only; a CSV-only app only if asked.

macOS, tvOS, and Android columns are left out of the tables below until a
platform is added; their status is the line above.

## Legend

- ✅ **Shipped**: live in production on this platform
- 🚧 **In progress**: being built; some parts may already be in main
- ⏳ **Planned**: committed; targeted for an upcoming milestone
- 🔮 **Future**: agreed direction; no timeline yet
- 🚫 **Out of scope**: explicitly not built on this platform (with reason)
- n/a: platform-inapplicable (e.g., lock-screen controls on tvOS)

n/a and 🚫 are different claims. n/a means the verb does not apply to
this platform at all. 🚫 means it could apply and we chose not to build
it, and the Notes say why.

A ⏳ or 🚫 cell carries its reason in Notes. "Deliberately deferred,
because X" is a healthy cell; a silent blank is drift.

---

## Parity rule

When shipping any user-facing feature:

1. **Confirm the verb is identical across platforms.**
   Find = explore, Profile = identify, etc. Don't let one platform
   own a different verb for the same surface.
2. **Pick the native idiom per platform**: `<dialog showModal>` on
   web, `.sheet` on iOS, `NavigationSplitView` + AppKit on macOS,
   focus-driven full-screen on tvOS, `ModalBottomSheet` on Android.
   *Same verb, native idiom.* An inversion of another platform's rule
   (e.g. `.buttonStyle(.plain)` is wrong on tvOS but correct on
   iOS/macOS) is deliberate. Never harmonize it away.
3. **Update this table** in the SAME PR. Drift here is what causes
   "the web has X but iOS doesn't" complaints six months later.
4. **Cross-link to the binding design doc** for each platform that
   has one.

---

## 1. Navigation and views

| Verb | Web | iOS | Notes |
|---|---|---|---|
| Unexamined (home) | ✅ | ✅ | Web: test_web_states. iOS: tap tier (iPhone 12), glass tier (iPhone 12, iPad Pro) |
| Ledger by month | ✅ | ✅ | |
| Story (month or value) | ✅ | ✅ | |
| Purchase detail | ✅ | ✅ | |
| Settings (color, values, connect Claude, account) | ✅ | ✅ | iOS color choice persists across devices (GroundUITests). At regular width (the open Duo) a sidebar of sections with the chosen one on the right (Ben, 2026-11-23), seen on the Duo; the web keeps one page |
| iPad layout | n/a | 🚧 | Native top tab bar seen; rows span full landscape width, a readable-width rule waits on Ben |

## 2. Money in

| Feature | Web | iOS | Notes |
|---|---|---|---|
| Import Apple Card CSV export | ✅ | ✅ | Web: real file input, re-import adds 0 (test_web_states). Same source IDs on both (golden parity test). iOS: ImportUITests on the iPhone 12 as the empty stranger: "3 new", then "0 new, 3 already in CentMemo" (DEBUG door APP_IMPORT_SAMPLE feeds the same import code; tools/cleanup_stranger.mjs empties it after). The Files picker itself is the system's. |
| Import Venmo, PayPal, Cash App CSV (S1/S2) | ✅ | ✅ | Web: auto-detected by header, own account per source, documented export paths; end-to-end import test. iOS: same parsers (Swift goldens read the same fixtures), Settings shows the paths (testExportPaths); ImportUITests.testVenmoImport on the iPhone 12: "Venmo: 3 new." (DEBUG door feeds tests/fixtures/venmo-sample.csv). PayPal and Cash App ride the same detector, golden-tested. |
| Narrative filters (D9) | ✅ | ✅ | All / Written / Unwritten, theme, deposits and interest on request. iOS toolbar menu (FilterUITests), web selects (test_web_states) |
| Month strip by theme (D11) | ✅ | ✅ | ThemeStrip (Core) / themeStrip (web); named legend; colors collide until D14 |
| Themes as collections (D12) | ✅ | ✅ | Story shelf with counts; tap a theme to read only its memos; ThemesUITests, test_web_states |
| Design your share (N4, DESIGN S) | ✅ | ✅ | Four looks, three papers, three shapes, underlined words, a PNG. iPhone 12, iPad and Mac seen; the open Duo not yet |
| A Setting's page, every visit (D8) | ✅ | ✅ | Web #/setting/<name> (test_web_states). iOS SettingPageView from the event header's "Every visit"; one ilike pattern (settingPattern, golden in JS + Swift) plus an exact cleaned-name match. seen on the open Duo with build 16 (Apple Store, 107 visits; the long-name header whole). The iPhone 12 tap test is still blocked by a Screen Time limit |
| Rename a Setting (D8) | ✅ | ✅ | One `setting_names` row per place, keyed by the cleaned name; every visit shows the person's name, the statement's kept beside it; cleared, the bank's returns. Agents refused in SQL; test_rls covers it. Web: Rename on the Setting page (test_web_states renames and clears). iOS: pencil in the Setting page toolbar, an alert with the name; the page seen on the open Duo, the save not yet pressed on a device (Ben's real account). Connector (mcp v9): a renamed place reads `place: <name> (statement: ...)`, and search finds it by the person's name (test_connector) |
| Place of a Setting (D15) | ✅ | ✅ | iOS 26: guessed from the statement (street, city, ZIP) with an on-device Apple Maps search, confirmed once per Setting (`setting_places`), small map that opens Maps; SettingUITests on the iPhone 12. Web: the confirmed place on the Setting and event pages, linked to Apple Maps (test_web_states). iOS event page: the map under the memo. No location permission. |
| Starter themes and theme colors (D14) | ✅ | ✅ | Ben's 13 (tests/fixtures/starter-themes.json), in Settings only (Ben, 2026-11-24); each theme its own color by one rule (js/money/themes.js = Themes.swift, golden on both). A new theme stores its color at creation (nextColor), so nothing already shown shifts. Web: test_web_states. iOS: ThemesStarterUITests on the iPhone 12. Duo (Ben's data) when it is back. |
| Story links (N4, DESIGN S7, Decision 067) | ✅ | ✅ | Make, list and turn off on web, iPhone, iPad and Mac; a link always opens the web page at /s/ |
| Pencil choices on share cards (DESIGN S8) | ✅ | ✅ | Underline, two lines, circle, highlighter |
| Share a whole theme (N4, DESIGN S6) | ✅ | ✅ | Cover, Pages, Lines; any memo left out; the same papers, shapes and underlines; never an amount |
| Suggestions on Unexamined (D7) | ✅ | ✅ | memo_suggestions() in the database: bills never suggested (bill MCCs, or the same charge in two earlier months), three different places, a moment per pick so the question fits (SuggestionWords / MOMENTS). One invitation card at a time with Another; no count. Seen on the open Duo and web; the iPhone 12 tap tier is blocked by Screen Time |
| Connect Apple Wallet (FinanceKit sync, history tokens) | n/a | 🚧 | Entitlement granted 2026-11-22 and signed into build 10; the iPhone 12 offers Connect (WalletAvailabilityUITests). Sync path verified with the sample source; the real sync is Ben's to run on his own phone |
| FinanceKit background delivery | n/a | 🚧 | iOS 26 extension, granted 2026-11-24; signed and on the Duo; a delivery not yet seen |

## 3. Telling the story

| Feature | Web | iOS | Notes |
|---|---|---|---|
| Write and remove a memo | ✅ | ✅ | Only the person writes (Decision 056). iOS: MemoUITests, read back after relaunch |
| Values the person names, tagged on memos | ✅ | ✅ | |
| Attach a photo | 🟡 | ✅ | iOS: by PhotoKit reference (PhotoAttachUITests; denied path). Web says how many are attached in the iPhone app; it cannot draw one |
| Keep a copy of a photo in CentMemo (item 10) | ✅ | 🚧 | Opt-in per photo ("Keep a copy in CentMemo"): a resized JPEG with no location or camera metadata, private bucket `attachments/<user id>/` (owner-only policies, agents refused; test_rls checks stranger and public reads). Web shows copies through hour-long signed links (test_web_states). iOS menu and the no-access message seen on the iPhone 12; the upload itself waits on a phone with Photos access (the bench declines it). Copies go with the photo and with the account. |
| Attach a file (item 10) | ✅ | ✅ | iOS "Add a file" (PDF or image; images re-encoded as JPEG, no metadata), kept as a private copy since a file reference works only on one device; opens through an hour-long signed link; web lists files by name with signed links. FileAttachUITests (iPhone 12, DEBUG door APP_ATTACH_SAMPLE_FILE) + test_web_states. |
| Share one story | 🔮 | 🔮 | Opt-in, per story |
| Delete account | ✅ | ✅ | `delete_my_account` proven (supabase/tests/delete_my_account.sql); pressed for real on the Duo 2026-11-24 (DeleteAccountUITests): every row gone, other users untouched |

## 4. Claude connector

| Feature | Server | Notes |
|---|---|---|
| Read-only MCP, OAuth 2.1, six tools | ✅ | tools/test_connector.mjs end to end; agent writes refused in SQL |
| Wallet (FinanceKit) rows never shared | ✅ | FinanceKit Addendum 3.2; `SHARE_FINANCEKIT = false` |
| Public docs | ✅ | centmemo.com/connect/ |
| Live in Claude Duet (chat and scheduled task) | 🚧 | Waits on Ben adding the connector |

## 5. States (universal-feature-states)

| Surface | Web | iOS | Notes |
|---|---|---|---|
| Empty state with a next action | ✅ | ✅ | Both seen with the empty stranger account: test_web_states, EmptyStateUITests (iPhone 12) |
| Error with Try again | ✅ | ✅ | iOS: ErrorStateUITests on the iPhone 12 (2026-11-23): unreachable and offline each say so in plain words with Try again, retry stays alive, never URLSession's words; the control loads. |
| Offline | ✅ | ✅ | Web banner and message tested. iOS: "Couldn't load / You're offline." with Try again (ErrorStateUITests.testOffline, frame read); no separate always-on banner. |
| Hints and walkthroughs | 🚫 | 🚫 | The Unexamined count is the only prompt CentMemo needs (DESIGN C4) |

## 6. Sign-in

| Feature | Web | iOS | Notes |
|---|---|---|---|
| Sign in with Apple (only method, Decision 058) | ✅ | 🚧 | Web verified by Ben. iOS not yet signed in on a real Apple ID (TestFlight) |

## 7. Not built, on purpose or not yet

| Feature | Status | Notes |
|---|---|---|
| Universal links / deep links | 🔮 | Web routes are hash links; iOS has DEBUG launch doors only |
| Notifications | 🔮 | Never with transaction details (Apple Developer Program License Agreement); only if a real need appears |
| Payments, subscriptions | 🚫 | Not scoped |

## 8. Platform reach

| | Web | iOS |
|---|---|---|
| Oldest served | Evergreen browsers (Safari, Chrome, Firefox) | iOS 18 (iPhone XS/XR and newer); FinanceKit needs iOS 17.4+ |
| Bench devices | Headless Chrome at 375 px | iPhone 12 (tap and glass tiers), iPad Pro 12.9 (glass tier; UI Automation waits on Ben) |

---

## Maintenance protocol

When you ship a feature:

1. Find the row in this table. Add new rows under the right section
   if needed.
2. Update each platform's status with one of the legend symbols.
3. Link to the relevant section of the platform's binding design doc.
4. Note any platform-specific deltas in the Notes column.
5. A shared-Core change usually moves all THREE Apple columns (iOS ·
   macOS · tvOS). Verify each still builds before you tick them.

When a feature ships on one platform but is meaningfully different
elsewhere, add an entry to §9 / §10 / §11 / §12 / §13.

When a platform explicitly rejects a feature, add an "Out of scope"
row in the relevant design doc and link from this table.

Keep the matrix readable, or it stops being true:

- **A cell is one sentence plus a link.** Put the evidence in the cell
  ("✅ verified on iPhone 12, YYYY-MM-DD"). Put the story in the ledger,
  design doc or DECISIONS entry the cell links to. A matrix that
  becomes a journal stops being read.
- **Name the parity test** in Notes for every row a mechanical guard
  enforces (for example `tools/test_<rule>_parity.py`).
- **One summary row per ported platform** (§7d). Never keep a second
  per-surface copy here once the port has its own ledger.
- **Scripts read columns by header name.** `line.split("|")` returns a
  leading empty element, so a fixed index lands in the wrong column
  and the table still renders. Build the index from the header row.
- **Keep §7b and §7c current** when a floor moves or a capability
  changes.

**Run a parity audit** (the `cross-platform-parity-discipline` skill,
"audit" mode) before any launch wave and roughly once per milestone:
walk the shipped feature list per platform and verify every cell is
honest. Real audits on shipped apps have found both missing rows
(features nobody recorded) AND false cells (a "synced" claim that
never actually synced). The audit is what keeps this file true.
