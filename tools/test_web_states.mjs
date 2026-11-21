// The web app's four states at 375px (universal-feature-states), in headless
// Chrome against the local files and the real backend:
//   empty   the stranger (no data) sees the empty Unexamined and Ledger states
//   happy   the owner sees rows (the control: proves "empty" is not just broken)
//   error   the owner with the REST API blocked sees an error and "Try again"
//   offline the owner gone offline sees the offline banner and "You're offline."
// Sessions come from the synthetic users' password sign-in, put where
// supabase-js keeps them, so Apple sign-in is not needed and Ben's own browser
// is untouched. Screenshots land in build/qa/web-states-<date>/.
//
// Needs ~/.centmemo/test-users.json. Run: node tools/test_web_states.mjs
import { spawn } from 'node:child_process';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const P = 'https://qucsmmazfalbyduxlavl.supabase.co', K = 'sb_publishable_XuubuEBTUKXkzttN2MUdzw_Aq7-q6YT';
const STORAGE_KEY = 'sb-qucsmmazfalbyduxlavl-auth-token';
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PORT = 8794, DEVTOOLS = 9294, SITE = `http://127.0.0.1:${PORT}/`;
const OUT = path.join(ROOT, 'build/qa', 'web-states-' + new Date().toISOString().slice(0, 10));
mkdirSync(OUT, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let failures = 0;
const ok = (c, m) => { console.log((c ? '  ok   ' : '  FAIL ') + m); if (!c) failures++; };

const users = JSON.parse(readFileSync(homedir() + '/.centmemo/test-users.json', 'utf8'));
async function sessionFor(who) {
  const s = await (await fetch(P + '/auth/v1/token?grant_type=password', { method: 'POST', headers: { apikey: K, 'content-type': 'application/json' }, body: JSON.stringify(users[who]) })).json();
  if (!s.access_token) throw new Error('sign-in failed for ' + who);
  return s;
}

const server = spawn('python3', ['-m', 'http.server', String(PORT), '--bind', '127.0.0.1'], { cwd: ROOT, stdio: 'ignore' });
const chrome = spawn(CHROME, ['--headless=new', `--remote-debugging-port=${DEVTOOLS}`, '--force-device-scale-factor=2',
  '--window-size=375,812', '--no-first-run', '--user-data-dir=' + path.join(OUT, 'profile'), 'about:blank'], { stdio: 'ignore' });
const cleanup = () => { try { chrome.kill(); } catch (_) {} try { server.kill(); } catch (_) {} };
process.on('exit', cleanup);

let target;
for (let i = 0; i < 40 && !target; i++) {
  await sleep(250);
  try { target = (await (await fetch(`http://127.0.0.1:${DEVTOOLS}/json`)).json()).find((t) => t.type === 'page'); } catch (_) {}
}
if (!target) { console.log('FAIL: headless Chrome did not start (this run covers NOTHING)'); process.exit(1); }
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r));
let id = 0; const waiting = new Map();
ws.addEventListener('message', (e) => { const m = JSON.parse(e.data); if (m.id && waiting.has(m.id)) { waiting.get(m.id)(m); waiting.delete(m.id); } });
const cdp = (method, params = {}) => new Promise((r) => { const n = ++id; waiting.set(n, r); ws.send(JSON.stringify({ id: n, method, params })); });
const evaluate = async (expr) => (await cdp('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })).result?.result?.value;
await cdp('Page.enable'); await cdp('Network.enable');
await cdp('Emulation.setDeviceMetricsOverride', { width: 375, height: 812, deviceScaleFactor: 2, mobile: true });

async function waitFor(expr, ms = 15000) {
  for (let t = 0; t < ms; t += 250) { if (await evaluate(expr)) return true; await sleep(250); }
  return false;
}
async function shot(name) {
  const r = await cdp('Page.captureScreenshot', { format: 'png' });
  writeFileSync(path.join(OUT, name + '.png'), Buffer.from(r.result.data, 'base64'));
}
async function openAs(who, route) {
  const s = await sessionFor(who);
  await cdp('Network.setBlockedURLs', { urls: [] });
  await cdp('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });
  await cdp('Page.navigate', { url: SITE });
  await waitFor('document.readyState === "complete"');
  await evaluate(`localStorage.setItem(${JSON.stringify(STORAGE_KEY)}, ${JSON.stringify(JSON.stringify(s))}); true`);
  await cdp('Page.navigate', { url: SITE + route });
  // A hash-only navigation keeps the document, so reload to make supabase-js read the session.
  await cdp('Page.reload', { ignoreCache: true });
  await sleep(500);
  await waitFor('document.readyState === "complete" && !document.getElementById("app-screen").hidden');
}
const visibleText = 'document.body.innerText';
// Only the view on screen counts: hidden sections keep the banners of earlier visits.
const VIS = 'section:not([hidden]) ';

console.log('empty (stranger)');
await openAs('stranger', '#/unexamined');
ok(await waitFor(`/No transactions yet/.test(${visibleText})`), 'Unexamined shows "No transactions yet."');
ok(await evaluate('!!document.querySelector(".state-empty a[href=\\"#/import\\"]")'), 'the empty state offers Import');
await shot('empty-unexamined');
await cdp('Page.navigate', { url: SITE + '#/ledger' });
ok(await waitFor(`/Nothing recorded in/.test(${visibleText})`), 'Ledger shows "Nothing recorded in <month>."');
await shot('empty-ledger');

console.log('happy (owner, the control)');
await openAs('owner', '#/unexamined');
ok(await waitFor('document.querySelectorAll(".row").length > 0'), 'owner sees rows on Unexamined');
ok(!(await evaluate('!!document.querySelector(".state-empty")')), 'and no empty state');
await shot('happy-unexamined');

console.log('error (REST blocked)');
await openAs('owner', '#/ledger');
await waitFor('document.querySelectorAll(".row").length > 0');
await cdp('Network.setBlockedURLs', { urls: ['*/rest/v1/*'] });
const t0 = Date.now();
await cdp('Page.navigate', { url: SITE + '#/story' });
ok(await waitFor(`!!document.querySelector("${VIS}.banner-error[role=alert]")`, 40000), `a failed load shows an error banner (after ${((Date.now() - t0) / 1000).toFixed(1)}s)`);
ok(await evaluate(`[...document.querySelectorAll("${VIS}.banner-error button")].some(b => b.textContent === "Try again")`), 'with "Try again"');
const said = await evaluate(`document.querySelector("${VIS}.banner-error span")?.textContent`);
ok(said === "CentMemo couldn't reach its server.", `in words a person reads (${said})`);
await shot('error-story');
await cdp('Network.setBlockedURLs', { urls: [] });
await evaluate(`[...document.querySelectorAll("${VIS}.banner-error button")].find(b => b.textContent === "Try again")?.click(); true`);
ok(await waitFor(`!document.querySelector("${VIS}.banner-error")`), '"Try again" recovers once the network is back');

console.log('offline');
await openAs('owner', '#/unexamined');
await waitFor('document.querySelectorAll(".row").length > 0');
await cdp('Network.emulateNetworkConditions', { offline: true, latency: 0, downloadThroughput: 0, uploadThroughput: 0 });
ok(await waitFor('!document.getElementById("offline-banner").hidden'), 'the offline banner appears');
await cdp('Page.navigate', { url: SITE + '#/ledger/2026-10' });
ok(await waitFor(`/You're offline/.test(document.querySelector("${VIS}.banner-error")?.innerText || "")`, 40000), 'a load while offline says "You\'re offline."');
await shot('offline-ledger');
await cdp('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });
ok(await waitFor('document.getElementById("offline-banner").hidden'), 'the banner clears when back online');

console.log('static pages');
for (const page of ['connect/', 'privacy/', 'terms/']) {
  await cdp('Page.navigate', { url: SITE + page });
  await waitFor('document.readyState === "complete" && !!document.querySelector("h1")');
  await sleep(300);
  const w = await evaluate('document.documentElement.scrollWidth');
  ok(w <= 375, `${page} fits 375px (${w})`);
  await shot('page-' + page.replace('/', ''));
}
ok(/never shared with Claude/.test(await (async () => { await cdp('Page.navigate', { url: SITE + 'connect/' }); await waitFor('!!document.querySelector("h1")'); return evaluate('document.body.innerText'); })()),
  'connect/ states that Wallet purchases are never shared with Claude');

ok(await evaluate('document.documentElement.scrollWidth <= 375'), `no horizontal scroll at 375 (${await evaluate('document.documentElement.scrollWidth')})`);
console.log(failures ? `FAIL: ${failures} web state check(s); frames in ${OUT}` : `PASS: four states at 375px; frames in ${OUT}`);
ws.close(); cleanup();
process.exit(failures ? 1 : 0);
