// Row-level security, checked against the DEPLOYED CentMemo project, not
// the migration file (finance-app-foundations section 5).
//
// Needs ~/.centmemo/test-users.json (outside the repo, mode 600):
//   { "owner":    { "email": "...", "password": "..." },
//     "stranger": { "email": "...", "password": "..." } }
// Two synthetic users; the owner holds the synthetic sample ledger.
// The agent rule (client_id tokens cannot write) is checked in SQL by
// supabase/tests/agents_cannot_write.sql, because minting an OAuth token
// needs the browser consent flow.
//
// Run: node tools/test_rls.mjs
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';

const URL_ = 'https://qucsmmazfalbyduxlavl.supabase.co';
const KEY = 'sb_publishable_XuubuEBTUKXkzttN2MUdzw_Aq7-q6YT';
const users = JSON.parse(readFileSync(homedir() + '/.centmemo/test-users.json', 'utf8'));
const TABLES = ['accounts', 'balances', 'import_batches', 'transactions', 'memos', 'life_values', 'memo_values', 'attachments', 'unexamined_transactions'];
let failures = 0;
const ok = (cond, msg) => { console.log((cond ? '  ok   ' : '  FAIL ') + msg); if (!cond) failures++; };

async function signIn(u) {
  const r = await fetch(URL_ + '/auth/v1/token?grant_type=password', {
    method: 'POST', headers: { apikey: KEY, 'content-type': 'application/json' }, body: JSON.stringify(u),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error('sign-in failed for ' + u.email + ': ' + JSON.stringify(j));
  return j.access_token;
}
function rest(token, path, init = {}) {
  return fetch(URL_ + '/rest/v1/' + path, {
    ...init,
    headers: { apikey: KEY, authorization: 'Bearer ' + (token || KEY), 'content-type': 'application/json', prefer: 'return=representation', ...(init.headers || {}) },
  });
}
async function rows(token, path) { const r = await rest(token, path); return r.ok ? r.json() : { status: r.status, body: await r.text() }; }

const owner = await signIn(users.owner);
const stranger = await signIn(users.stranger);

console.log('owner sees their own data');
const ownTx = await rows(owner, 'transactions?select=id,account_id&limit=5');
ok(Array.isArray(ownTx) && ownTx.length > 0, 'owner reads transactions (' + (ownTx.length ?? ownTx.status) + ')');
const ownMemos = await rows(owner, 'memos?select=transaction_id&limit=5');
ok(Array.isArray(ownMemos) && ownMemos.length > 0, 'owner reads memos');

console.log('a stranger sees nothing');
for (const t of TABLES) {
  const r = await rows(stranger, t + '?select=*&limit=5');
  ok(Array.isArray(r) && r.length === 0, 'stranger reads 0 rows from ' + t);
}
const sum = await rest(stranger, 'rpc/spending_summary', { method: 'POST', body: JSON.stringify({ from_date: '2000-01-01', to_date: '2100-01-01', group_by: 'category' }) });
ok(sum.ok && (await sum.json()).length === 0, 'stranger spending_summary is empty');

console.log('a stranger cannot write into the owner\'s ledger');
const target = ownTx[0];
const ins = await rest(stranger, 'transactions', { method: 'POST', body: JSON.stringify({
  account_id: target.account_id, source: 'csv', source_id: 'rls-probe', txn_date: '2026-01-01', amount_minor: -1, currency: 'USD' }) });
ok(!ins.ok, 'stranger cannot hang a transaction on the owner\'s account (' + ins.status + ')');
const memoIns = await rest(stranger, 'memos', { method: 'POST', body: JSON.stringify({ transaction_id: target.id, body: 'probe' }) });
ok(!memoIns.ok, 'stranger cannot write a memo on the owner\'s transaction (' + memoIns.status + ')');
const upd = await rest(stranger, 'transactions?id=eq.' + target.id, { method: 'PATCH', body: JSON.stringify({ merchant: 'probe' }) });
ok(upd.ok && (await upd.json()).length === 0, 'stranger update touches 0 rows');
const del = await rest(stranger, 'transactions?id=eq.' + target.id, { method: 'DELETE' });
ok(del.ok && (await del.json()).length === 0, 'stranger delete touches 0 rows');

console.log('signed out sees nothing (negative control on the key alone)');
for (const t of ['transactions', 'memos']) {
  const r = await rows(null, t + '?select=*&limit=1');
  ok(!Array.isArray(r) || r.length === 0, 'anon reads nothing from ' + t + (Array.isArray(r) ? '' : ' (' + r.status + ')'));
}

const still = await rows(owner, 'transactions?select=merchant&id=eq.' + target.id);
ok(still.length === 1 && still[0].merchant !== 'probe', 'owner row unchanged after the probes');

console.log(failures ? `FAIL: ${failures} check(s)` : 'PASS: row-level security holds on the deployed project');
process.exit(failures ? 1 : 0);
