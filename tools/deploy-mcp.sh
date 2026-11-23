#!/bin/sh
# Deploy CentMemo's mcp Edge Function with the shared money core beside it,
# so the server and the web app format money with one copy of the code.
# The normal deploy needs no token: the agent deploys through the signed-in
# Supabase connector (deploy_edge_function, verify_jwt false, with money.js
# beside index.ts). The owner never creates or manages tokens (Ben, 2026-11-23).
# This script is only for a CLI that is already signed in (environment token).
set -e
cd "$(dirname "$0")/.."
F=supabase/functions/mcp
cp js/money/money.js "$F/money.js"
trap 'rm -f "$F/money.js"' EXIT
TOKEN="${SUPABASE_ACCESS_TOKEN:-}"
[ -n "$TOKEN" ] || { echo "No Supabase token in the environment: deploy through the Supabase connector (deploy_edge_function) instead."; exit 1; }
SUPABASE_ACCESS_TOKEN="$TOKEN" \
  npx -y supabase@latest functions deploy mcp --project-ref qucsmmazfalbyduxlavl --no-verify-jwt --use-api --yes
