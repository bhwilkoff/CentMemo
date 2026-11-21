#!/bin/sh
# Deploy CentMemo's mcp Edge Function with the shared money core beside it,
# so the server and the web app format money with one copy of the code.
# The token is Ben's Supabase personal access token, read from a file only
# his account can read (or SUPABASE_ACCESS_TOKEN), never from this repo.
set -e
cd "$(dirname "$0")/.."
F=supabase/functions/mcp
cp js/money/money.js "$F/money.js"
trap 'rm -f "$F/money.js"' EXIT
TOKEN="${SUPABASE_ACCESS_TOKEN:-}"
for f in "$HOME/.centmemo/supabase-token" "$HOME/.humanshaped/supabase-token"; do
  [ -z "$TOKEN" ] && [ -r "$f" ] && TOKEN="$(tr -d '\n\r ' < "$f")"
done
[ -n "$TOKEN" ] || { echo "No Supabase access token (set SUPABASE_ACCESS_TOKEN)"; exit 1; }
SUPABASE_ACCESS_TOKEN="$TOKEN" \
  npx -y supabase@latest functions deploy mcp --project-ref qucsmmazfalbyduxlavl --no-verify-jwt --use-api --yes
