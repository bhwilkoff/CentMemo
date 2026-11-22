// Test fixture repair: un-skip every event of the synthetic owner (a Skip test
// that failed midway leaves one skipped). Run: node tools/restore_skips.mjs
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
const u = JSON.parse(readFileSync(homedir() + '/.centmemo/test-users.json', 'utf8')).owner;
const P = 'https://qucsmmazfalbyduxlavl.supabase.co', K = 'sb_publishable_XuubuEBTUKXkzttN2MUdzw_Aq7-q6YT';
const s = await (await fetch(P + '/auth/v1/token?grant_type=password', { method: 'POST', headers: { apikey: K, 'content-type': 'application/json' }, body: JSON.stringify(u) })).json();
const r = await (await fetch(P + '/rest/v1/transactions?skipped_at=not.is.null', { method: 'PATCH',
  headers: { apikey: K, authorization: 'Bearer ' + s.access_token, 'content-type': 'application/json', prefer: 'return=representation' },
  body: JSON.stringify({ skipped_at: null }) })).json();
console.log(`restored ${r.length}${r.length ? ': ' + r.map((x) => x.merchant).join(', ') : ''}`);
