// Story links (N4) on the deployed project: what a stranger, a signed-out reader and
// the Claude connector can and cannot do, and that nothing hidden is published.
// Runs as the two synthetic users; leaves nothing behind.
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
const src = readFileSync('tools/cleanup_stranger.mjs', 'utf8');
const base = src.match(/https:[^']+/)[0], pub = src.match(/sb_publishable_[^']+/)[0];
const users = JSON.parse(readFileSync(homedir() + '/.centmemo/test-users.json', 'utf8'));
let failures = 0;
const ok = (c, m) => { console.log((c ? '  ok   ' : '  FAIL ') + m); if (!c) failures++; };
const call = (path, token, init = {}) => fetch(base + path, { ...init, headers: { apikey: pub, 'content-type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}), ...(init.headers || {}) } });
const signIn = async (u) => (await (await call('/auth/v1/token?grant_type=password', null, { method: 'POST', body: JSON.stringify(u) })).json()).access_token;
const rpc = async (name, body, token) => { const r = await call('/rest/v1/rpc/' + name, token, { method: 'POST', body: JSON.stringify(body) }); return { status: r.status, body: await r.json().catch(() => null) }; };
const rows = async (path, token) => { const r = await call('/rest/v1/' + path, token); return r.ok ? r.json() : { status: r.status }; };
const owner = await signIn(users.owner), stranger = await signIn(users.stranger);
const ZOO = 'a3b8c10c-68b8-4bfe-9380-c87b7015a49d';
const memo = (await rows('memos?select=body&transaction_id=eq.' + ZOO, owner))[0].body;
const theme = (await rows('memo_values?select=value_id,transaction_id,life_values(name)&transaction_id=eq.' + ZOO, owner))[0];
const inTheme = (await rows('memo_values?select=transaction_id&value_id=eq.' + theme.value_id, owner)).map((r) => r.transaction_id);
const read = async (code, token) => (await rpc('get_share', { p_code: code }, token)).body;
const made = [];
const make = async (body, token = owner) => { const r = await rpc('make_share', body, token); if (r.status === 200) made.push(r.body); return r; };
try {
  console.log('a person makes a link to one memo');
  const one = await make({ p_kind: 'memo', p_value: theme.value_id, p_from: 'Ben', p_design: { lead: 'setting', paper: 'night', pencil: 'circle' }, p_items: [{ txn: ZOO, place: 'The zoo', when: 'November', mark: [16, 13] }] });
  ok(one.status === 200 && /^[A-Za-z0-9_-]{22}$/.test(one.body), 'and gets a 22-character code');
  const page = await read(one.body);
  ok(page && page.items[0].memo === memo && page.items[0].place === 'The zoo' && page.items[0].when === 'November', 'a signed-out reader with the code sees the memo, the place and the time as typed');
  ok(JSON.stringify(page.items[0].mark) === '[13,16]' && page.design.pencil === 'circle' && page.design.paper === 'night' && page.from === 'Ben', 'and the marked words and the look');
  const raw = JSON.stringify(page);
  ok(!/amount|\$|account|email|user|merchant|source|txn|memo_ids|[0-9a-f]{8}-[0-9a-f]{4}/i.test(raw.replace(memo, '')), 'and no amount, account, person or id of any kind');

  console.log('nobody else can do anything with it');
  ok((await read(one.body.slice(0, 21) + (one.body.endsWith('A') ? 'B' : 'A'))) === null, 'a wrong code gets nothing');
  ok((await read('')) === null && (await read('%')) === null, 'nor an empty one or a wildcard');
  for (const [who, token] of [['signed out', null], ['a stranger', stranger]]) {
    const list = await rows('shares?select=*', token);
    ok(!Array.isArray(list) || list.length === 0, `${who} cannot list links`);
  }
  ok((await make({ p_kind: 'memo', p_items: [{ txn: ZOO }] }, stranger)).status !== 200, 'a stranger cannot make a link to the owner\'s memo');
  ok((await make({ p_kind: 'memo', p_items: [{ txn: ZOO }] }, null)).status !== 200, 'nor can anyone signed out');
  ok((await make({ p_kind: 'theme', p_value: theme.value_id, p_items: [{ txn: ZOO }] }, stranger)).status !== 200, 'nor to the owner\'s theme');
  const gone = await call('/rest/v1/shares?code=eq.' + one.body, stranger, { method: 'DELETE', headers: { Prefer: 'return=representation' } });
  ok(gone.ok && (await gone.json()).length === 0 && (await read(one.body)) !== null, 'a stranger cannot turn it off');
  ok(!(await call('/rest/v1/shares', owner, { method: 'POST', body: JSON.stringify({ code: 'A'.repeat(22), kind: 'memo', memo_ids: [ZOO], title: 'x', payload: { items: [{ memo: 'Not my words, $5' }] } }) })).ok, 'even the owner cannot publish words that are not a memo');
  const edit = await call('/rest/v1/shares?code=eq.' + one.body, owner, { method: 'PATCH', body: JSON.stringify({ title: 'x' }) });
  ok(!edit.ok, 'and a link never changes after it is made');

  console.log('what the page hides is not published');
  const bare = await make({ p_kind: 'memo', p_value: theme.value_id, p_design: { place: false, when: false, theme: false }, p_items: [{ txn: ZOO, place: 'SECRETPLACE', when: 'SECRETTIME' }] });
  const bareRaw = JSON.stringify(await read(bare.body));
  ok(!/SECRET/.test(bareRaw) && !bareRaw.includes(theme.life_values.name), 'a hidden place, time and theme name are not in the page at all');
  const lines = await make({ p_kind: 'theme', p_value: theme.value_id, p_design: { cover: false, lines: true, mems: false }, p_items: inTheme.map((t) => ({ txn: t, place: 'SECRETPLACE', when: 'SECRETTIME', mark: t === ZOO ? [13, 16] : null })) });
  const linesRaw = JSON.stringify(await read(lines.body));
  ok(lines.status === 200 && /we stayed until closing/.test(linesRaw) && !/penguins/.test(linesRaw) && !/SECRET/.test(linesRaw), 'a lines-only theme page carries the marked words and not the rest of the memos');
  const cover = await make({ p_kind: 'theme', p_value: theme.value_id, p_design: { cover: true, lines: false, mems: false }, p_items: inTheme.map((t) => ({ txn: t, place: 'Here' })) });
  ok(!/penguins|closing/.test(JSON.stringify(await read(cover.body))), 'a cover-only page carries no memo');
  ok((await make({ p_kind: 'theme', p_value: theme.value_id, p_design: { cover: false, lines: false, mems: false }, p_items: [{ txn: ZOO }] })).status !== 200, 'a page with no parts is refused');
  const other = (await rows('memos?select=transaction_id&transaction_id=not.in.(' + inTheme.join(',') + ')&limit=1', owner))[0];
  if (other) ok((await make({ p_kind: 'theme', p_value: theme.value_id, p_items: [{ txn: other.transaction_id }] })).status !== 200, 'a memo without the theme cannot ride on its link');
  const odd = await make({ p_kind: 'memo', p_from: 'x'.repeat(500), p_design: { lead: '<script>', paper: 7, pencil: null }, p_items: [{ txn: ZOO, place: '<b>' + 'p'.repeat(300), mark: ['a', -4] }] });
  const oddPage = await read(odd.body);
  ok(oddPage.design.lead === 'memory' && oddPage.design.paper === 'bold' && oddPage.from.length === 60 && oddPage.items[0].place.length === 80 && !('mark' in oddPage.items[0]), 'odd choices fall back to plain ones, and long words are cut');

  console.log('turning it off');
  await call('/rest/v1/shares?code=eq.' + one.body, owner, { method: 'DELETE' });
  ok((await read(one.body)) === null, 'the owner turns it off and it is gone at once, for everyone');
} finally {
  await call('/rest/v1/shares?id=not.is.null', owner, { method: 'DELETE' });
  ok((await rows('shares?select=id', owner)).length === 0, 'nothing is left behind');
}
// A memo deleted takes its links with it: the stranger writes one of its own and removes it.
{
  const acc = await (await call('/rest/v1/accounts', stranger, { method: 'POST', headers: { Prefer: 'return=representation' }, body: JSON.stringify({ kind: 'liability', display_name: 'probe', institution: 'probe', currency: 'USD', source: 'csv', source_id: 'share-probe' }) })).json();
  const tx = await (await call('/rest/v1/transactions', stranger, { method: 'POST', headers: { Prefer: 'return=representation' }, body: JSON.stringify({ account_id: acc[0]?.id, source: 'csv', source_id: 'share-probe', txn_date: '2026-11-01', amount_minor: -100, currency: 'USD', description: 'probe', merchant: 'probe' }) })).json();
  await call('/rest/v1/memos', stranger, { method: 'POST', body: JSON.stringify({ transaction_id: tx[0]?.id, body: 'A probe memo.' }) });
  const r = await rpc('make_share', { p_kind: 'memo', p_items: [{ txn: tx[0]?.id }] }, stranger);
  ok(r.status === 200 && (await read(r.body)) !== null, 'a link to a memo works');
  await call('/rest/v1/memos?transaction_id=eq.' + tx[0]?.id, stranger, { method: 'DELETE' });
  ok((await read(r.body)) === null, 'and deleting the memo turns its link off');
  await call('/rest/v1/accounts?source_id=eq.share-probe', stranger, { method: 'DELETE' });
}
console.log(failures ? `FAIL: ${failures} check(s)` : 'PASS: story links');
process.exit(failures ? 1 : 0);
