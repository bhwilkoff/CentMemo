# Testing CentMemo

The agent is never the tester of record (AGENTS.md): Ben plays with it on
his own devices. These tiers exist so that what reaches him already works.
Each check shows it can fail: a negative control, a planted drift, or a
mutation seen failing.

## Off-device: `tools/test_all.sh`

One command, about two minutes, no device needed:

| Check | What it holds |
|---|---|
| `tests/money.test.mjs` | Money core goldens (integer cents, Apple Card CSV signs, stable source IDs) |
| `tests/connector_guard.test.mjs` | The Claude connector never reads FinanceKit rows (Addendum 3.2) |
| `tools/test_design_tokens.mjs` | Every platform's tokens match the JSON; text pairs pass AA |
| `tools/test_grounds.mjs` | Every color a person can choose: ink reads on it, it is never a page background, web and Apple agree |
| `tools/test_web_states.mjs` | The web app at 375px in headless Chrome: empty (stranger), rows (owner, the control), error with Try again and recovery (REST blocked), offline banner and message; no horizontal scroll. Frames in `build/qa/web-states-<date>/` |
| `supabase/tests/delete_my_account.sql` | Account deletion removes the person and their rows and nothing else; run as the stranger, always rolled back |
| `tools/test_connector.mjs` | The Claude connector end to end, as Claude drives it: discovery, registration, PKCE, consent, token, all six tools, refresh. The agent token gets 403 on writes; a control shows the owner's token can write |
| `tools/test_rls.mjs` | Deployed row-level security: a stranger sees and changes nothing; a read-only control proves the test can fail |
| `CentMemoTests` (Swift) | The same money goldens as the web, plus calendar dates in any time zone |
| iOS build | The app and its UI tests compile |

## On a real iPhone (the bench)

The bench is shared with Ben's other apps (Ear Drama, Archive Watch).
Every run takes a device lease (`tools/devlease.py`) so two sessions never
drive one phone. Devices are listed in `tools/app_config.py` DEVICES: the
**iPhone 12** first, and the iPad Pro as its stand-in. The phone stays awake
and unlocked on a charger. A locked phone installs the app but refuses to
launch it.

- **Tap tier**: `python3 tools/ios_uitest.py --device iphone [--only Suite/test]`
  - Builds a team-signed app and installs it, then confirms the installed
    build.
  - Runs XCUITest (`apple/UITests`) as the synthetic test owner, who is
    signed in by the DEBUG door.
  - Exports every screenshot, reads each one for system overlays, and fails
    on any new crash log.
  - Leaves the phone as found.
  - Suites:
    - `TabSmokeUITests`: every tab, plus tapping through the bar.
    - `MemoUITests`: a memo with its values; write, save, read back after a
      relaunch, then remove.
    - `ErrorStateUITests/testOfflineRefreshKeepsTheSignIn`: an expired session
      with no signal (APP_EXPIRE_SESSION=1, APP_FAIL_NETWORK=offline) stays signed in.
    - `GroundUITests`: choosing a color saves and survives a relaunch.
- **Glass tier**: `python3 tools/ios_run.py --device iphone --scenario <name>`
  - Launches through a test door and grades screenshots by OCR against text
    only that screen draws.
  - Scenarios: `unexamined`, `ledger`, `story`, `settings`, `item`.

Test data is synthetic (`tools/seed_demo.mjs`, `~/.centmemo/test-users.json`,
mode 600, outside the repo). Tests that change data put it back.

## No simulators (Ben, 2026-11-26)

"WE DON'T USE SIMULATORS. WE TEST ON REAL DEVICES." The tap tier runs on the iPhone 12
(`tools/ios_uitest.py`), the iPad when its passcode allows, debug installs on the Duo, and
the Mac (`tools/mac_uitest.py`). A simulator result is never verification. When a device
is blocked (Screen Time, locked), say so and try again later; never substitute a simulator.

## On this Mac

- **Tap tier**: `/usr/bin/python3 tools/mac_uitest.py [--only part-of-a-name]` after a
  Debug Mac build. Presses the app's real buttons through accessibility, in the
  background, as the synthetic owner (the stranger for the empty state), and leaves the
  data as found. BLIND means the app had not answered yet, usually a busy Mac.
- BLIND with "no windows (AXError 0)" while someone works in a full-screen space: new
  windows open on another space, unseen. Other apps read the same way. Wait; never switch it.
- Pictures of a covered window are stale; read the control tree (`mac_ax <pid> dump`).

## Web

The web app runs locally (`python3 -m http.server 8765`). Chrome checks it
signed in as the synthetic owner, at 375px (`tools/phone-frame.html`) and
1440px, in light and dark. Apple sign-in works only on centmemo.com.

## Found by these tiers so far

- Dates showed a day early west of UTC. Fixed, with a test.
- Unsigned simulator builds can't keep the session in the Keychain. Sign
  even simulator builds.
- On iPhone, the keyboard covered the memo's Save button. Save moved to the
  navigation bar, with a keyboard Done button.
- The "Saved." confirmation was off-screen. It now sits under the memo.
- The first RLS negative control wrote to the owner's rows. Controls are now
  read-only.

## Lessons from the bench (2026-11-21, tick 11)

- **An unanswered permission prompt outlives the test.** If a run ends while a
  system prompt (Photos) is up, iOS shows it again at the next launch, before
  the app asks for anything. A later "prompt appeared too early" failure can
  be that leftover, not the code. Answer prompts in the test that causes them.
- **Never place a caret by tapping text.** On the iPhone 12 a tap put the
  caret at the start or mid-text, so backspaces deleted nothing and leftover
  test memos grew. Select instead (`tap(withNumberOfTaps: 3, ...)` on the
  element), then delete.
- **The floating tab bar takes taps** in the bottom ~80 pt, including over
  form content. Tap above it.
- **A Form renders lazily**: swipe the Form's collection view, not the app,
  until the element exists.
- **Three repeat failures now handled by the tools (2026-11-23):**
  - Homebrew's `python3` has no Pillow, so `frame_blind` re-runs the tool
    under `/usr/bin/python3`.
  - `design_shots` and `ios_uitest` ask devicectl whether the phone wants
    its passcode, and stop with `LOCKED <device>` before building.
  - `ios_uitest` copies each frame to its readable name
    (`attachments/<run>/setting-door.png`) beside xcresulttool's UUID
    file.
  - Screen Time limits the iPhone 12 only at some hours, so try it before
    calling it blocked. Observed blocked 9:20pm to past midnight.
  - A test that fails before its first shot leaves only the failure
    recording. `ios_uitest` checks that recording's last frame for system
    overlays too, because behind a Time Limit screen the app looks signed
    out, not blocked.
- **A test that fails mid-way leaves data.** Check the server after a failure
  (memos, attachments) and clean it before the next run.

## Is Wallet background delivery running?

Supabase edge logs, read only (`query_logs`, source `edge_logs`): look for user
agents starting `CentMemoWalletDelivery/`. The app is `CentMemo/`. Each wake
with Wallet access posts to `/rest/v1/accounts`. No rows means either no wake or
no new Wallet data: hourly is a minimum interval, and no change means no wake.
