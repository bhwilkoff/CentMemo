// The Claude connector, end to end, the way Claude's connector client drives it
// (claude-connector-mcp skill): discovery from a 401, dynamic client
// registration, authorization with PKCE, the person's consent (approved through
// the same Supabase calls js/consent.js makes, as the SYNTHETIC owner), the code
// exchange, every MCP tool over Streamable HTTP, and a refresh. Then the agent's
// real token is shown to read but never write (Decision 056).
//
// Needs ~/.centmemo/test-users.json. Run: node tools/test_connector.mjs
// (public address by default; CONNECTOR_MCP_URL=<direct Supabase URL> checks the old one).
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { createHash, randomBytes } from 'node:crypto';

const PROJECT = 'https://qucsmmazfalbyduxlavl.supabase.co';
const KEY = 'sb_publishable_XuubuEBTUKXkzttN2MUdzw_Aq7-q6YT';
const MCP = process.env.CONNECTOR_MCP_URL || 'https://mcp.centmemo.com';
const REDIRECT = 'http://localhost:8799/callback';
const { owner } = JSON.parse(readFileSync(homedir() + '/.centmemo/test-users.json', 'utf8'));
let failures = 0;
const ok = (c, m) => { console.log((c ? '  ok   ' : '  FAIL ') + m); if (!c) failures++; return c; };
const b64url = (b) => b.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

// 1. Discovery
console.log('discovery');
const first = await fetch(MCP, { method: 'POST', headers: { 'content-type': 'application/json', accept: 'application/json, text/event-stream' }, body: '{}' });
const www = first.headers.get('www-authenticate') || '';
ok(first.status === 401 && /resource_metadata=/.test(www), `unauthenticated call is 401 with resource_metadata (${first.status})`);
const rmUrl = (www.match(/resource_metadata="([^"]+)"/) || [])[1];
const rm = await (await fetch(rmUrl)).json();
ok(rm.resource && rm.authorization_servers?.length, `protected resource metadata names an authorization server`);
const asBase = rm.authorization_servers[0];
const asMeta = await (await fetch(PROJECT + '/.well-known/oauth-authorization-server/auth/v1')).json();
ok(asMeta.issuer?.startsWith(asBase.replace(/\/$/, '')) || asMeta.issuer === asBase, `authorization server metadata (${asMeta.issuer})`);
ok((asMeta.code_challenge_methods_supported || []).includes('S256'), 'PKCE S256 supported');

// 2. Dynamic client registration
console.log('registration');
const reg = await (await fetch(asMeta.registration_endpoint, { method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ client_name: 'CentMemo connector test', redirect_uris: [REDIRECT], grant_types: ['authorization_code', 'refresh_token'],
    response_types: ['code'], token_endpoint_auth_method: 'none' }) })).json();
ok(!!reg.client_id, `client registered (${reg.client_id ? 'client_id issued' : JSON.stringify(reg).slice(0, 120)})`);

// 3. Authorization with PKCE
console.log('authorization');
const verifier = b64url(randomBytes(32)), challenge = b64url(createHash('sha256').update(verifier).digest()), state = b64url(randomBytes(12));
const auth = new URL(asMeta.authorization_endpoint);
for (const [k, v] of Object.entries({ response_type: 'code', client_id: reg.client_id, redirect_uri: REDIRECT, code_challenge: challenge,
  code_challenge_method: 'S256', state, resource: rm.resource })) auth.searchParams.set(k, v);
const a = await fetch(auth, { redirect: 'manual' });
const toConsent = new URL(a.headers.get('location') || 'about:blank', PROJECT);
const authorizationId = toConsent.searchParams.get('authorization_id');
ok(toConsent.href.startsWith('https://centmemo.com/oauth/consent') && !!authorizationId, `redirected to CentMemo's consent page (${toConsent.origin}${toConsent.pathname})`);

// 4. Consent, as the synthetic owner (the calls js/consent.js makes)
console.log('consent');
const sess = await (await fetch(PROJECT + '/auth/v1/token?grant_type=password', { method: 'POST', headers: { apikey: KEY, 'content-type': 'application/json' }, body: JSON.stringify(owner) })).json();
const asOwner = { apikey: KEY, authorization: 'Bearer ' + sess.access_token, 'content-type': 'application/json' };
const details = await (await fetch(`${PROJECT}/auth/v1/oauth/authorizations/${authorizationId}`, { headers: asOwner })).json();
ok(details.client?.name === 'CentMemo connector test' || !!details.authorization_id, `consent details name the client (${details.client?.name || '?'})`);
const consent = await (await fetch(`${PROJECT}/auth/v1/oauth/authorizations/${authorizationId}/consent`, { method: 'POST', headers: asOwner, body: JSON.stringify({ action: 'approve' }) })).json();
const back = new URL(consent.redirect_url || 'about:blank');
ok(back.href.startsWith(REDIRECT) && back.searchParams.get('state') === state && !!back.searchParams.get('code'), 'approval returns to the client with a code and the same state');

// 5. Code exchange
console.log('token');
const form = (o) => new URLSearchParams(o).toString();
const tok = await (await fetch(asMeta.token_endpoint, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
  body: form({ grant_type: 'authorization_code', code: back.searchParams.get('code'), redirect_uri: REDIRECT, client_id: reg.client_id, code_verifier: verifier }) })).json();
ok(!!tok.access_token && !!tok.refresh_token, 'code exchanged for access and refresh tokens');
const claims = JSON.parse(Buffer.from((tok.access_token || 'a.e30.b').split('.')[1], 'base64url').toString());
ok(claims.client_id === reg.client_id, 'the token carries the client_id claim (what makes it an agent token)');

// 6. MCP over Streamable HTTP
console.log('tools');
let rpcId = 0, sessionId = null;
async function rpc(method, params) {
  const h = { authorization: 'Bearer ' + tok.access_token, 'content-type': 'application/json', accept: 'application/json, text/event-stream' };
  if (sessionId) h['mcp-session-id'] = sessionId;
  const r = await fetch(MCP, { method: 'POST', headers: h, body: JSON.stringify({ jsonrpc: '2.0', id: ++rpcId, method, params }) });
  sessionId = r.headers.get('mcp-session-id') || sessionId;
  const text = await r.text();
  const json = text.trim().startsWith('{') ? JSON.parse(text) : JSON.parse((text.match(/^data: (.*)$/m) || [])[1] || '{}');
  return { status: r.status, json };
}
const init = await rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'centmemo-test', version: '1' } });
ok(init.status === 200 && init.json.result?.serverInfo?.name === 'centmemo', `initialize (${init.status}, ${init.json.result?.serverInfo?.name})`);
const list = await rpc('tools/list', {});
const tools = list.json.result?.tools || [];
const names = tools.map((t) => t.name).sort();
ok(names.join() === 'get_balances,get_memos,list_accounts,search_transactions,spending_summary,unexamined_transactions', `six tools listed (${names.join(', ')})`);
ok(tools.every((t) => t.annotations?.readOnlyHint === true && t.title && t.annotations?.title === t.title), 'every tool has a title (also in annotations, for the directory) and readOnlyHint');
// Directory policy: descriptions carry no instructions about model behavior.
const instructing = tools.filter((t) => /\b(use it|do not|don't|never|always|you should|you must|ignore)\b/i.test(t.description || ''));
ok(!instructing.length, `no tool description instructs the model (${instructing.map((t) => t.name).join(', ') || 'none'})`);
const calls = {
  list_accounts: {}, get_balances: {},
  search_transactions: { from: '2026-10-01', to: '2026-11-30', merchant: 'Zoo' },
  spending_summary: { from: '2026-11-01', to: '2026-11-30', group_by: 'value' },
  unexamined_transactions: { from: '2026-10-01', limit: 5 },
  get_memos: { from: '2026-11-01', to: '2026-11-30' },
};
const expect = { list_accounts: /Apple Card/, get_balances: /No balances recorded/, search_transactions: /Denver Zoo[\s\S]*penguins/,
  spending_summary: /Time with my kids/, unexamined_transactions: /without a memo/, get_memos: /memo\(s\)[\s\S]*Water Grill/ };
for (const [name, args] of Object.entries(calls)) {
  const r = await rpc('tools/call', { name, arguments: args });
  const text = (r.json.result?.content || []).map((c) => c.text).join('\n');
  ok(!r.json.result?.isError && expect[name].test(text), `${name}: ${text.split('\n')[0].slice(0, 90)}`);
}

// 6b. Skip (Decision 065): an event the person skipped never reaches Claude's
// list of purchases without a memo. The owner skips one, then restores it.
{
  const unexamined = async () => ((await rpc('tools/call', { name: 'unexamined_transactions', arguments: { from: '2025-01-01', limit: 100 } })).json.result?.content || []).map((c) => c.text).join('\n');
  const before = await unexamined();
  const m = before.match(/id: ([0-9a-f-]{36})/);
  ok(!!m, 'an unexamined event to skip');
  if (m) {
    const patch = (v) => fetch(`${PROJECT}/rest/v1/transactions?id=eq.${m[1]}`, { method: 'PATCH', headers: asOwner, body: JSON.stringify({ skipped_at: v }) });
    await patch(new Date().toISOString());
    try {
      ok(!(await unexamined()).includes(m[1]), 'a skipped event is left out of unexamined_transactions');
    } finally {
      await patch(null);
    }
    ok((await unexamined()).includes(m[1]), 'and comes back when the person brings it back');
  }
}

// 6c. D8 renames: the person's name for a place leads, the statement beside it,
// and Claude finds the place by that name. The owner renames, then clears it.
{
  const put = await fetch(`${PROJECT}/rest/v1/setting_names?on_conflict=user_id,setting`, { method: 'POST', headers: { ...asOwner, Prefer: 'resolution=merge-duplicates' }, body: JSON.stringify({ setting: 'Denver Zoo', name: 'The Zoo' }) });
  ok(put.ok, `the owner names a Setting (${put.status})`);
  try {
    const r = await rpc('tools/call', { name: 'search_transactions', arguments: { from: '2026-10-01', to: '2026-11-30', merchant: 'The Zoo' } });
    const text = (r.json.result?.content || []).map((c) => c.text).join('\n');
    ok(/place: The Zoo \(statement: [^)]*Zoo/.test(text), 'search by the person\'s name finds the place, shown with the statement text');
  } finally {
    await fetch(`${PROJECT}/rest/v1/setting_names?setting=eq.Denver%20Zoo`, { method: 'DELETE', headers: asOwner });
  }
}

// 7. The agent's real token reads but never writes (Decision 056)
console.log('agent token');
const asAgent = { apikey: KEY, authorization: 'Bearer ' + tok.access_token, 'content-type': 'application/json', prefer: 'return=representation' };
const read = await fetch(PROJECT + '/rest/v1/transactions?select=id&limit=1', { headers: asAgent });
ok(read.ok && (await read.json()).length === 1, 'agent token can read through REST');
const write = await fetch(PROJECT + '/rest/v1/life_values', { method: 'POST', headers: asAgent, body: JSON.stringify({ name: 'agent probe ' + Date.now() }) });
ok(!write.ok, `agent token cannot insert (${write.status})`);
const upd = await fetch(PROJECT + '/rest/v1/memos?transaction_id=not.is.null', { method: 'PATCH', headers: asAgent, body: JSON.stringify({ body: 'agent edit' }) });
ok(!upd.ok || (await upd.json()).length === 0, `agent token changes no memo (${upd.status})`);
// Control: the same insert with the person's own token succeeds, so the 403 above
// comes from the token being an agent's, not from inserts being broken.
// Addendum 3.2 at the database, not only in the connector's code: the token itself
// reaches nothing from Wallet (Decision 068). A made-up Wallet purchase, every direct way in.
console.log('the token cannot reach Wallet');
{
  const post = async (table, body) => (await (await fetch(`${PROJECT}/rest/v1/${table}`, { method: 'POST', headers: { ...asOwner, prefer: 'return=representation' }, body: JSON.stringify(body) })).json())[0];
  const get = async (path, headers) => { const r = await fetch(`${PROJECT}/rest/v1/${path}`, { headers }); return r.ok ? r.json() : []; };
  const acc = await post('accounts', { kind: 'liability', display_name: 'Wallet probe', institution: 'probe', currency: 'USD', source: 'financekit', source_id: 'agent-probe' });
  try {
    const tx = await post('transactions', { account_id: acc.id, source: 'financekit', source_id: 'agent-probe', txn_date: '2019-01-02', amount_minor: -123, currency: 'USD', description: 'WALLETPROBE', merchant: 'Walletprobe Cafe' });
    await post('memos', { transaction_id: tx.id, body: 'A Wallet probe memo.' });
    const val = (await get('life_values?select=id&limit=1', asOwner))[0];
    await post('memo_values', { transaction_id: tx.id, value_id: val.id });
    await post('balances', { account_id: acc.id, as_of: '2019-01-02T00:00:00Z', booked_minor: 5, currency: 'USD' });
    await post('attachments', { transaction_id: tx.id, kind: 'photo', device_ref: 'agent-probe' });
    await post('import_batches', { source: 'financekit', filename: 'agent-probe', row_count: 1 });
    await post('setting_names', { setting: 'Walletprobe Cafe', name: 'Probe' });
    await post('setting_places', { setting: 'Walletprobe Cafe', name: 'Probe', lat: 1, lon: 1 });
    const ways = [['transactions', `transactions?select=id&id=eq.${tx.id}`], ['accounts', `accounts?select=id&id=eq.${acc.id}`], ['balances', `balances?select=id&account_id=eq.${acc.id}`],
      ['memos', `memos?select=body&transaction_id=eq.${tx.id}`], ['memo themes', `memo_values?select=value_id&transaction_id=eq.${tx.id}`], ['attachments', `attachments?select=id&transaction_id=eq.${tx.id}`],
      ['imports', 'import_batches?select=id&filename=eq.agent-probe'], ['setting names', 'setting_names?select=name&setting=eq.Walletprobe%20Cafe'], ['setting places', 'setting_places?select=name&setting=eq.Walletprobe%20Cafe']];
    for (const [what, path] of ways) {
      ok((await get(path, asOwner)).length === 1, `control: the person reads their Wallet ${what}`);
      ok((await get(path, asAgent)).length === 0, `the agent's token reads no Wallet ${what}`);
    }
    const call = async (fn, body, headers) => { const r = await fetch(`${PROJECT}/rest/v1/rpc/${fn}`, { method: 'POST', headers, body: JSON.stringify(body) }); return JSON.stringify(r.ok ? await r.json() : null); };
    const range = { from_date: '2019-01-01', to_date: '2019-01-31', group_by: 'month', exclude_financekit: false };
    ok(/123/.test(await call('spending_summary', range, asOwner)) && !/123/.test(await call('spending_summary', range, asAgent)), 'nor a total of it, even when it asks for one');
    await fetch(`${PROJECT}/rest/v1/memos?transaction_id=eq.${tx.id}`, { method: 'DELETE', headers: asOwner });
    ok((await get(`unexamined_transactions?select=id&id=eq.${tx.id}`, asOwner)).length === 1 && (await get(`unexamined_transactions?select=id&id=eq.${tx.id}`, asAgent)).length === 0, 'nor as unexamined');
    ok((await get('transactions?select=id&source=eq.csv&limit=1', asAgent)).length === 1 && (await get('memos?select=body&limit=1', asAgent)).length === 1 && (await get('memo_values?select=value_id&limit=1', asAgent)).length === 1, 'control: imported purchases, their memos and themes are still shared');
  } finally {
    for (const p of [`accounts?id=eq.${acc.id}`, 'import_batches?filename=eq.agent-probe', 'setting_names?setting=eq.Walletprobe%20Cafe', 'setting_places?setting=eq.Walletprobe%20Cafe']) await fetch(`${PROJECT}/rest/v1/${p}`, { method: 'DELETE', headers: asOwner });
  }
}
// Story links: made by the person only, and never read by an agent, whose page could
// hold a memo on a Wallet purchase (Addendum 3.2).
{
  const ZOO = 'a3b8c10c-68b8-4bfe-9380-c87b7015a49d';
  const link = (headers) => fetch(PROJECT + '/rest/v1/rpc/make_share', { method: 'POST', headers, body: JSON.stringify({ p_kind: 'memo', p_items: [{ txn: ZOO }] }) });
  ok(!(await link(asAgent)).ok, 'the agent cannot make a story link');
  const byOwner = await link(asOwner), code = byOwner.ok ? await byOwner.json() : null;
  ok(!!code, 'control: the person can');
  const seen = await fetch(PROJECT + '/rest/v1/shares?select=*', { headers: asAgent });
  ok(!seen.ok || (await seen.json()).length === 0, 'the agent cannot read the person\'s links');
  const off = await fetch(PROJECT + '/rest/v1/shares?code=eq.' + code, { method: 'DELETE', headers: asAgent });
  ok(!off.ok || (await off.json()).length === 0, 'nor turn one off');
  const still = await (await fetch(PROJECT + '/rest/v1/shares?select=code&code=eq.' + code, { headers: asOwner })).json();
  ok(still.length === 1, 'control: the person still has it');
  if (code) await fetch(PROJECT + '/rest/v1/shares?code=eq.' + code, { method: 'DELETE', headers: asOwner });
}
const ownerWrite = await fetch(PROJECT + '/rest/v1/life_values', { method: 'POST', headers: { ...asOwner, prefer: 'return=representation' }, body: JSON.stringify({ name: 'control probe ' + Date.now() }) });
const made = ownerWrite.ok ? await ownerWrite.json() : [];
ok(ownerWrite.ok && made.length === 1, `control: the person's own token can insert (${ownerWrite.status})`);
if (made[0]) await fetch(`${PROJECT}/rest/v1/life_values?id=eq.${made[0].id}`, { method: 'DELETE', headers: asOwner });

// 8. Refresh
console.log('refresh');
const ref = await (await fetch(asMeta.token_endpoint, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
  body: form({ grant_type: 'refresh_token', refresh_token: tok.refresh_token, client_id: reg.client_id }) })).json();
ok(!!ref.access_token, 'refresh token yields a new access token');

console.log(failures ? `FAIL: ${failures} connector check(s)` : 'PASS: the connector works end to end, read-only');
process.exit(failures ? 1 : 0);
