#!/bin/sh
# Every check that needs no device, in one run (docs/TESTING.md). Exit 1 on
# any failure. Device tiers (tools/ios_uitest.py, tools/ios_run.py) run
# separately because they hold a device lease.
set -u
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
fail=0
# On a failure, every failing line first (a long suite's culprit can sit far
# above its last 15 lines), then the tail for context.
run() { name="$1"; shift; if out=$("$@" 2>&1); then echo "PASS $name"; else echo "FAIL $name"; echo "$out" | grep -E "^\s*FAIL|Error|error:" | head -10; echo "  ..."; echo "$out" | tail -8; fail=1; fi; }

run "money core + connector guard (node)" node --test tests/money.test.mjs tests/themes.test.mjs tests/connector_guard.test.mjs tests/connector_policy.test.mjs
run "design tokens: drift + contrast" node tools/test_design_tokens.mjs
run "grounds: contrast + web/Apple parity" node tools/test_grounds.mjs
run "US English" python3 tools/test_us_english.py
run "agent files" python3 tools/test_agent_files.py
run "app identity" python3 tools/test_app_identity.py
if [ -r "$HOME/.centmemo/test-users.json" ]; then
  run "row-level security (deployed)" node tools/test_rls.mjs
  run "Claude connector end to end (OAuth + six tools)" node tools/test_connector.mjs
  run "Directory reviewer path, live (consent page + reviewer credentials)" node tools/test_reviewer_live.mjs
  run "web: four states at 375px (headless Chrome)" node tools/test_web_states.mjs
else
  echo "SKIP row-level security: ~/.centmemo/test-users.json missing (says so, never a silent pass)"
fi
xcodegen generate -q >/dev/null 2>&1
run "Swift Core tests (macOS)" xcodebuild test -project CentMemo.xcodeproj -scheme CentMemoTests \
  -destination platform=macOS CODE_SIGNING_ALLOWED=NO -jobs 2 -quiet
run "iOS app builds" xcodebuild build -project CentMemo.xcodeproj -scheme CentMemoUITests \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -jobs 2 -quiet
[ $fail -eq 0 ] && echo "ALL PASS" || echo "SOME CHECKS FAILED"
exit $fail
