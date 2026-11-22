// The Connectors Directory reviewer's whole path, live, as their Claude drives
// it (Decisions 063-064): discovery at https://mcp.centmemo.com, client
// registration, the LIVE consent page at centmemo.com in headless Chrome,
// "Reviewer sign-in" typed with the exact credentials we hand over, approval,
// the code exchanged for a token, and every tool answering with the sample data.
//
// Needs ~/.centmemo/test-users.json ("reviewer"). Run: node tools/test_reviewer_live.mjs
import { spawn } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import path from 'node:path';

const MCP = process.env.CONNECTOR_MCP_URL || 'https://mcp.centmemo.com';
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const DEVTOOLS = 9296, REDIRECT = 'https://claude.ai/api/mcp/auth_callback';
const reviewer = JSON.parse(readFileSync(homedir() + '/.centmemo/test-users.json', 'utf8')).reviewer;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const b64 = (b) => b.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
let failures = 0;
const ok = (c, m) => { console.log((c ? '  ok   ' : '  FAIL ') + m); if (!c) failures++; return c; };

console.log('discovery and registration, from the public address');
const first = await fetch(MCP, { method: 'POST', headers: { 'content-type': 'application/json', accept: 'application/json, text/event-stream' }, body: '{}' });
const rmUrl = ((first.headers.get('www-authenticate') || '').match(/resource_metadata="([^"]+)"/) || [])[1];
ok(first.status === 401 && !!rmUrl, `401 names its metadata (${rmUrl})`);
const rm = await (await fetch(rmUrl)).json();
const asMeta = await (await fetch(rm.authorization_servers[0].replace(/\/auth\/v1\/?$/, '') + '/.well-known/oauth-authorization-server/auth/v1')).json();
const reg = await (await fetch(asMeta.registration_endpoint, { method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ client_name: 'Claude', redirect_uris: [REDIRECT], grant_types: ['authorization_code', 'refresh_token'], response_types: ['code'], token_endpoint_auth_method: 'none' }) })).json();
ok(!!reg.client_id, 'a client registers the way Claude does');
const verifier = b64(randomBytes(32)), state = b64(randomBytes(12));
const auth = new URL(asMeta.authorization_endpoint);
for (const [k, v] of Object.entries({ response_type: 'code', client_id: reg.client_id, redirect_uri: REDIRECT, state, resource: rm.resource,
  code_challenge: b64(createHash('sha256').update(verifier).digest()), code_challenge_method: 'S256' })) auth.searchParams.set(k, v);
const consentUrl = new URL((await fetch(auth, { redirect: 'manual' })).headers.get('location') || 'about:blank', asMeta.issuer);
ok(consentUrl.href.startsWith('https://centmemo.com/oauth/consent/'), `sent to the live consent page (${consentUrl.origin}${consentUrl.pathname})`);

console.log('the live consent page, in a browser with no CentMemo session');
const profile = path.join(tmpdir(), 'centmemo-reviewer-' + Date.now());
mkdirSync(profile, { recursive: true });
const chrome = spawn(CHROME, ['--headless=new', `--remote-debugging-port=${DEVTOOLS}`, '--no-first-run', '--user-data-dir=' + profile, 'about:blank'], { stdio: 'ignore' });
process.on('exit', () => { try { chrome.kill(); } catch (_) {} });
let target;
for (let i = 0; i < 120 && !target; i++) { await sleep(250); try { target = (await (await fetch(`http://127.0.0.1:${DEVTOOLS}/json`)).json()).find((t) => t.type === 'page'); } catch (_) {} }
if (!target) { console.log('FAIL: headless Chrome did not start (this run covers NOTHING)'); process.exit(1); }
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r));
let id = 0; const waiting = new Map(), requested = [];
ws.addEventListener('message', (e) => { const m = JSON.parse(e.data);
  if (m.id && waiting.has(m.id)) { waiting.get(m.id)(m); waiting.delete(m.id); }
  if (m.method === 'Network.requestWillBeSent') requested.push(m.params.request.url); });
const cdp = (method, params = {}) => new Promise((r) => { const n = ++id; waiting.set(n, r); ws.send(JSON.stringify({ id: n, method, params })); });
const evaluate = async (expr) => (await cdp('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })).result?.result?.value;
const waitFor = async (expr, ms = 20000) => { for (let t = 0; t < ms; t += 250) { if (await evaluate(expr)) return true; await sleep(250); } return false; };
await cdp('Page.enable'); await cdp('Network.enable'); await cdp('Network.setCacheDisabled', { cacheDisabled: true });
// Stop at Claude's callback instead of loading claude.ai.
await cdp('Network.setBlockedURLs', { urls: [REDIRECT + '*'] });
await cdp('Page.navigate', { url: consentUrl.href });
ok(await waitFor('!!document.querySelector("[data-state=signed-out]") && !document.querySelector("[data-state=signed-out]").hidden'), 'signed out: Sign in with Apple, and Reviewer sign-in below it');
ok(await evaluate('/Reviewer sign-in/.test(document.querySelector("details.reviewer summary").textContent)'), 'the "Reviewer sign-in" the notes name is there');
// Control: the right email with a wrong password stays out (a pass must mean the password matters).
await evaluate(`document.querySelector("details.reviewer").open = true; document.getElementById("rv-email").value = ${JSON.stringify(reviewer.email)}; document.getElementById("rv-password").value = "wrong-" + Date.now(); document.querySelector("[data-reviewer] button").click(); true`);
await sleep(4000);
ok(await evaluate('document.querySelector("[data-state=ask]").hidden && !!document.querySelector("[data-sent]").textContent.trim()'), `a wrong password is refused ("${(await evaluate('document.querySelector("[data-sent]").textContent')).trim()}")`);
await evaluate(`document.querySelector("details.reviewer").open = true; document.getElementById("rv-email").value = ${JSON.stringify(reviewer.email)}; document.getElementById("rv-password").value = ${JSON.stringify(reviewer.password)}; document.querySelector("[data-reviewer] button").click(); true`);
ok(await waitFor('!document.querySelector("[data-state=ask]").hidden'), 'the reviewer credentials sign in and the page asks whether to connect');
ok(/review@centmemo\.com/.test(await evaluate('document.querySelector("[data-who]").textContent')), 'signed in as review@centmemo.com');
await evaluate('document.querySelector("[data-approve]").click(); true');
for (let t = 0; t < 20000 && !requested.some((u) => u.startsWith(REDIRECT)); t += 250) await sleep(250);
const back = new URL(requested.find((u) => u.startsWith(REDIRECT)) || 'about:blank');
ok(back.searchParams.get('state') === state && !!back.searchParams.get('code'), 'Allow reading returns to Claude with a code and the same state');

console.log('token and tools, as the reviewer');
const tok = await (await fetch(asMeta.token_endpoint, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({ grant_type: 'authorization_code', code: back.searchParams.get('code') || '', redirect_uri: REDIRECT, client_id: reg.client_id, code_verifier: verifier }) })).json();
ok(!!tok.access_token, 'the code becomes a token');
let rpcId = 0, sessionId = null;
async function rpc(method, params) {
  const h = { authorization: 'Bearer ' + tok.access_token, 'content-type': 'application/json', accept: 'application/json, text/event-stream' };
  if (sessionId) h['mcp-session-id'] = sessionId;
  const r = await fetch(MCP, { method: 'POST', headers: h, body: JSON.stringify({ jsonrpc: '2.0', id: ++rpcId, method, params }) });
  sessionId = r.headers.get('mcp-session-id') || sessionId;
  const text = await r.text();
  return text.trim().startsWith('{') ? JSON.parse(text) : JSON.parse((text.match(/^data: (.*)$/m) || [])[1] || '{}');
}
ok((await rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'claude-ai', version: '1' } })).result?.serverInfo?.name === 'centmemo', 'initialize');
ok(((await rpc('tools/list', {})).result?.tools || []).length === 6, 'six tools');
// The reviewer's three use cases from the form, plus the rest; wide dates so the sample is found whenever this runs.
const calls = [
  ['list_accounts', {}, /Apple Card/],
  ['get_balances', {}, /balance|No balances/i],
  ['unexamined_transactions', { from: '2025-01-01', limit: 5 }, /without a memo|Every purchase/],
  ['spending_summary', { from: '2025-01-01', to: '2027-12-31', group_by: 'value' }, /spent \$/],
  ['get_memos', { from: '2025-01-01', to: '2027-12-31' }, /memo\(s\)[\s\S]*memo: /],
  ['search_transactions', { from: '2025-01-01', to: '2027-12-31', has_memo: true, limit: 3 }, /transaction\(s\)/],
];
for (const [name, args, rx] of calls) {
  const r = await rpc('tools/call', { name, arguments: args });
  const text = (r.result?.content || []).map((c) => c.text).join('\n');
  ok(!r.result?.isError && rx.test(text), `${name}: ${text.split('\n')[0].slice(0, 90)}`);
}
console.log(failures ? `FAIL: ${failures} reviewer check(s)` : 'PASS: the reviewer credentials work end to end, live');
process.exit(failures ? 1 : 0);
