// Seeds the synthetic test owner's ledger through the same parser and
// upsert the web app uses, so seeding also exercises the import path.
// Idempotent: re-running inserts nothing new (Decision 057). The account
// doubles as the Connectors Directory's reviewer test account.
// Run: node tools/seed_demo.mjs
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { createRequire } from 'node:module';
const M = createRequire(import.meta.url)('../js/money/money.js');
const URL_ = 'https://qucsmmazfalbyduxlavl.supabase.co';
const KEY = 'sb_publishable_XuubuEBTUKXkzttN2MUdzw_Aq7-q6YT';
const { owner } = JSON.parse(readFileSync(homedir() + '/.centmemo/test-users.json', 'utf8'));

const tok = (await (await fetch(URL_ + '/auth/v1/token?grant_type=password', {
  method: 'POST', headers: { apikey: KEY, 'content-type': 'application/json' }, body: JSON.stringify(owner) })).json()).access_token;
if (!tok) throw new Error('owner sign-in failed');
async function rest(path, method, body, prefer = 'return=representation') {
  const r = await fetch(URL_ + '/rest/v1/' + path, { method, headers: { apikey: KEY, authorization: 'Bearer ' + tok, 'content-type': 'application/json', prefer }, body: body && JSON.stringify(body) });
  const t = await r.text();
  if (!r.ok) throw new Error(path + ' ' + r.status + ' ' + t);
  return t ? JSON.parse(t) : null;
}

const rows = await M.parseAppleCardCsv(readFileSync(new URL('../tests/fixtures/applecard-demo.csv', import.meta.url), 'utf8'));
const [acct] = await rest('accounts?on_conflict=user_id,source,source_id', 'POST',
  { source: 'csv', source_id: 'applecard', kind: 'liability', display_name: 'Apple Card', institution: 'Apple' },
  'return=representation,resolution=merge-duplicates');
const [batch] = await rest('import_batches', 'POST', { source: 'csv', filename: 'applecard-demo.csv', row_count: rows.length });
const got = await rest('transactions?on_conflict=user_id,source,source_id&select=id', 'POST',
  rows.map(r => ({ ...r, account_id: acct.id, import_batch_id: batch.id })), 'return=representation,resolution=ignore-duplicates');
await rest('import_batches?id=eq.' + batch.id, 'PATCH', { inserted_count: got.length });
console.log(`import: ${rows.length} parsed, ${got.length} new`);

// A few memos and values, as a person would write them (synthetic).
const values = ['Time with my kids', 'Great meals', 'Being outside'];
for (const name of values) {
  // The unique index is on lower(btrim(name)), so only a 409 duplicate is
  // expected on a re-run; anything else must surface.
  await rest('life_values', 'POST', { name }).catch((e) => { if (!/ 409 /.test(e.message)) throw e; });
}
const vals = await rest('life_values?select=id,name', 'GET');
const vid = Object.fromEntries(vals.map(v => [v.name, v.id]));
const txns = await rest('transactions?select=id,merchant,txn_date', 'GET');
const find = (m, d) => txns.find(t => t.merchant === m && t.txn_date === d);
const memos = [
  ['Denver Zoo', '2026-11-16', 'First cold Sunday of the year. The kids raced to the penguins and we stayed until closing.', ['Time with my kids', 'Being outside']],
  ['Blue Pan Pizza', '2026-11-18', 'Birthday dinner. Ordered two pies because nobody could agree.', ['Great meals', 'Time with my kids']],
  ['Water Grill', '2026-11-07', 'Anniversary. Worth every cent; we should do this more than once a year.', ['Great meals']],
  ['Snowbird', '2026-11-08', 'Opening weekend lift ticket. Three runs before the wind closed the top.', ['Being outside']],
];
for (const [m, d, body, vs] of memos) {
  const t = find(m, d); if (!t) continue;
  await rest('memos?on_conflict=transaction_id', 'POST', { transaction_id: t.id, body }, 'resolution=merge-duplicates');
  for (const v of vs) await rest('memo_values?on_conflict=transaction_id,value_id', 'POST', { transaction_id: t.id, value_id: vid[v] }, 'resolution=ignore-duplicates');
}
console.log('memos written:', memos.length);
