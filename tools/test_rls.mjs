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
const TABLES = ['accounts', 'balances', 'import_batches', 'transactions', 'memos', 'life_values', 'memo_values', 'attachments', 'unexamined_transactions', 'profiles', 'setting_names', 'setting_places'];
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

// A negative control (stranger set to the owner) must never run the write
// probes: they would really change the owner's rows. Same account means
// read checks only, which should then FAIL.
const control = users.owner.email === users.stranger.email;
if (control) console.log('negative control: stranger is the owner; read checks only, expect FAIL');
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

if (control) { console.log(failures ? `control FAILED as expected (${failures})` : 'control PASSED: the test is blind'); process.exit(failures ? 0 : 1); }
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

// Synthetic accounts hold only fake data (Ben, 2026-11-22: "The test account should
// only have fake data."). A real Wallet once synced into the test owner from a test
// build left signed in on a personal phone; any Wallet row here must be the app's
// own sample (sample-…), never a real FinanceKit id.
console.log('synthetic accounts hold only fake data');
export const realRows = (list) => list.filter((t) => !String(t.source_id).startsWith('sample-'));
for (const [who, token] of [['owner', owner], ['stranger', stranger]]) {
  const fk = await rows(token, 'transactions?select=source_id&source=eq.financekit&limit=2000');
  ok(Array.isArray(fk) && realRows(fk).length === 0, `${who}: no real Wallet rows (${Array.isArray(fk) ? realRows(fk).length : '?'})`);
}
ok(realRows([{ source_id: 'sample-1' }, { source_id: '7F3A-real' }]).length === 1, 'negative control: a real id is caught');

console.log('photo copies (storage bucket "attachments")');
if (!control) {
  const sub = (t) => JSON.parse(Buffer.from(t.split('.')[1], 'base64url').toString()).sub;
  const store = (token, path, init = {}) => fetch(URL_ + '/storage/v1/object/' + path, { ...init, headers: { apikey: KEY, authorization: 'Bearer ' + token, ...(init.headers || {}) } });
  const jpeg = Buffer.from('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==', 'base64');
  const mine = 'attachments/' + sub(owner) + '/rls-check.jpg';
  try {
    const up = await store(owner, mine, { method: 'POST', body: jpeg, headers: { 'content-type': 'image/jpeg', 'x-upsert': 'true' } });
    ok(up.ok, 'owner uploads a copy into their own folder (' + up.status + ')');
    const peek = await store(stranger, 'authenticated/' + mine);
    ok(!peek.ok, 'a stranger cannot read the owner\'s copy (' + peek.status + ')');
    const plant = await store(stranger, 'attachments/' + sub(owner) + '/planted.jpg', { method: 'POST', body: jpeg, headers: { 'content-type': 'image/jpeg' } });
    ok(!plant.ok, 'a stranger cannot write into the owner\'s folder (' + plant.status + ')');
    const anon = await fetch(URL_ + '/storage/v1/object/public/' + mine);
    ok(!anon.ok, 'the bucket is not public (' + anon.status + ')');
    const own = await store(owner, 'authenticated/' + mine);
    ok(own.ok, 'the owner reads their own copy (' + own.status + ')');
  } finally {
    await store(owner, 'attachments', { method: 'DELETE', body: JSON.stringify({ prefixes: [mine.slice('attachments/'.length)] }), headers: { 'content-type': 'application/json' } });
  }
}

console.log('a link\'s pictures (storage bucket "shared", W7)');
if (!control) {
  const store = (token, path, init = {}) => fetch(URL_ + '/storage/v1/object/' + path, { ...init, headers: { apikey: KEY, authorization: 'Bearer ' + token, ...(init.headers || {}) } });
  const rpc = (token, fn, body) => fetch(URL_ + '/rest/v1/rpc/' + fn, { method: 'POST', body: JSON.stringify(body), headers: { apikey: KEY, authorization: 'Bearer ' + token, 'content-type': 'application/json' } });
  const jpeg = Buffer.from('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==', 'base64');
  const made = await rpc(owner, 'make_share', { p_kind: 'memo', p_items: [{ txn: 'a3b8c10c-68b8-4bfe-9380-c87b7015a49d' }] });
  const code = made.ok ? await made.json() : null;
  ok(typeof code === 'string' && code.length === 22, 'owner makes a memo link (' + made.status + ')');
  if (code) {
    try {
      const up = await store(owner, 'shared/' + code + '/0.jpg', { method: 'POST', body: jpeg, headers: { 'content-type': 'image/jpeg', 'cache-control': 'max-age=60' } });
      ok(up.ok, 'owner adds a picture under their link (' + up.status + ')');
      const plant = await store(stranger, 'shared/' + code + '/1.jpg', { method: 'POST', body: jpeg, headers: { 'content-type': 'image/jpeg' } });
      ok(!plant.ok, 'a stranger cannot add a picture to the owner\'s link (' + plant.status + ')');
      const gone = await store(stranger, 'shared', { method: 'DELETE', body: JSON.stringify({ prefixes: [code + '/0.jpg'] }), headers: { 'content-type': 'application/json' } });
      const still = await fetch(URL_ + '/storage/v1/object/public/shared/' + code + '/0.jpg');
      ok(still.ok, 'a stranger cannot remove it (' + gone.status + ', still ' + still.status + ')');
      const theirs = await rpc(stranger, 'set_share_pictures', { p_code: code, p_count: 1 });
      ok(!theirs.ok, 'a stranger cannot set its pictures (' + theirs.status + ')');
      const set = await rpc(owner, 'set_share_pictures', { p_code: code, p_count: 1, p_looks: ['mounted', 'whole'] });
      ok(set.ok, 'the owner sets the count once (' + set.status + ')');
      const twice = await rpc(owner, 'set_share_pictures', { p_code: code, p_count: 3 });
      ok(!twice.ok, 'and only once (' + twice.status + ')');
      const page = await (await rpc(stranger, 'get_share', { p_code: code })).json();
      ok(page && page.pictures === 1 && !JSON.stringify(page).includes('$'), 'the page says one picture, and no amount');
      ok(page && JSON.stringify(page.looks) === '["mounted"]', 'its look is kept, one per picture (' + JSON.stringify(page && page.looks) + ')');
    } finally {
      await store(owner, 'shared', { method: 'DELETE', body: JSON.stringify({ prefixes: [code + '/0.jpg'] }), headers: { 'content-type': 'application/json' } });
      await fetch(URL_ + '/rest/v1/shares?code=eq.' + code, { method: 'DELETE', headers: { apikey: KEY, authorization: 'Bearer ' + owner } });
    }
    // The file itself is gone at once; the public copy at a fresh address is gone too. (A
    // CDN may answer the old address for up to the 60 s the upload allows.)
    const kept = await store(owner, 'authenticated/shared/' + code + '/0.jpg');
    const fresh = await fetch(URL_ + '/storage/v1/object/public/shared/' + code + '/0.jpg?gone=' + Date.now());
    ok(!kept.ok && !fresh.ok, 'turned off, the picture is gone (' + kept.status + ', ' + fresh.status + ')');
  }
}

console.log(failures ? `FAIL: ${failures} check(s)` : 'PASS: row-level security holds on the deployed project');
process.exit(failures ? 1 : 0);
