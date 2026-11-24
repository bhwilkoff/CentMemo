#!/usr/bin/env node
// Empties the synthetic stranger account after a device test that imported
// into it (ImportUITests). Deletes only rows the stranger owns, as the
// stranger, through RLS. tools/test_rls.mjs asserts it is empty.
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
const URL_ = 'https://qucsmmazfalbyduxlavl.supabase.co';
const KEY = 'sb_publishable_XuubuEBTUKXkzttN2MUdzw_Aq7-q6YT';
const { stranger } = JSON.parse(readFileSync(homedir() + '/.centmemo/test-users.json', 'utf8'));
const s = await (await fetch(URL_ + '/auth/v1/token?grant_type=password', { method: 'POST', headers: { apikey: KEY, 'content-type': 'application/json' }, body: JSON.stringify(stranger) })).json();
if (!s.access_token) { console.error('stranger sign-in failed'); process.exit(1); }
const h = { apikey: KEY, Authorization: 'Bearer ' + s.access_token };
for (const t of ['accounts?id=not.is.null', 'import_batches?id=not.is.null', 'life_values?id=not.is.null']) {
  const r = await fetch(URL_ + '/rest/v1/' + t, { method: 'DELETE', headers: h });
  if (!r.ok) { console.error('delete failed: ' + t + ' ' + r.status); process.exit(1); }
}
const left = await (await fetch(URL_ + '/rest/v1/transactions?select=id', { headers: h })).json();
console.log(Array.isArray(left) && left.length === 0 ? 'stranger is empty' : 'stranger still has ' + JSON.stringify(left).slice(0, 80));
process.exit(Array.isArray(left) && left.length === 0 ? 0 : 1);
