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
    - `GroundUITests`: choosing a color saves and survives a relaunch.
- **Glass tier**: `python3 tools/ios_run.py --device iphone --scenario <name>`
  - Launches through a test door and grades screenshots by OCR against text
    only that screen draws.
  - Scenarios: `unexamined`, `ledger`, `story`, `settings`, `item`.

Test data is synthetic (`tools/seed_demo.mjs`, `~/.centmemo/test-users.json`,
mode 600, outside the repo). Tests that change data put it back.

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
