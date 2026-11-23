#!/bin/sh
# Deploy CentMemo's mcp Edge Function with the shared money core beside it,
# so the server and the web app format money with one copy of the code.
# The token is Ben's Supabase personal access token, read from the login
# Keychain (centmemo:SUPABASE_ACCESS_TOKEN, stored by
# `tools/secrets.sh keychain-paste SUPABASE_ACCESS_TOKEN`) or the environment;
# never from a file or this repo.
set -e
cd "$(dirname "$0")/.."
F=supabase/functions/mcp
cp js/money/money.js "$F/money.js"
trap 'rm -f "$F/money.js"' EXIT
TOKEN="${SUPABASE_ACCESS_TOKEN:-}"
[ -n "$TOKEN" ] || TOKEN="$(security find-generic-password -a centmemo -s centmemo:SUPABASE_ACCESS_TOKEN -w 2>/dev/null || true)"
[ -n "$TOKEN" ] || { echo "No Supabase access token: copy one from supabase.com/dashboard/account/tokens, then run tools/secrets.sh keychain-paste SUPABASE_ACCESS_TOKEN"; exit 1; }
SUPABASE_ACCESS_TOKEN="$TOKEN" \
  npx -y supabase@latest functions deploy mcp --project-ref qucsmmazfalbyduxlavl --no-verify-jwt --use-api --yes
