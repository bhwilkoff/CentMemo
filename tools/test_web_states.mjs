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
// Up to 30 s: a cold Chrome start once took longer than 10 s and left the run blind.
for (let i = 0; i < 120 && !target; i++) {
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
// Test the files on disk, never a cached copy from an earlier run (an unversioned
// HTML page was served stale from the reused profile, 2026-11-22).
await cdp('Network.setCacheDisabled', { cacheDisabled: true });
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
ok(await waitFor(`/Nothing in your Narrative yet/.test(${visibleText})`), 'Unexamined shows "Nothing in your Narrative yet."');
ok(await evaluate('!!document.querySelector(".state-empty a[href=\\"#/import\\"]")'), 'the empty state offers Import');
await shot('empty-unexamined');
await cdp('Page.navigate', { url: SITE + '#/ledger' });
ok(await waitFor(`/Nothing recorded in/.test(${visibleText})`), 'Ledger shows "Nothing recorded in <month>."');
await shot('empty-ledger');

console.log('happy (owner, the control)');
await openAs('owner', '#/unexamined');
ok(await waitFor('document.querySelectorAll(".row").length > 0'), 'owner sees rows on Unexamined');
ok(!(await evaluate('!!document.querySelector(".state-empty")')), 'and no empty state');
ok(await waitFor('document.querySelectorAll("#view-unexamined .suggestion").length > 0'), 'Unexamined suggests moments worth a memo (D7)');
ok(await evaluate('[...document.querySelectorAll("#view-unexamined .suggestion-reason")].every(r => /First time here|Biggest this month|Your busiest day|A year ago you wrote/.test(r.textContent))'), 'each suggestion says why it was picked');
ok(await evaluate('document.querySelectorAll("#view-unexamined .suggestion").length === 1'), 'one invitation at a time, not a list of cards (Ben, 2026-11-23)');
ok(await evaluate('[...document.querySelectorAll("#view-unexamined .suggestion-act")].every(a => /Write a memo|Read it again/.test(a.textContent))'), 'the card ends on the act of writing');
if (await evaluate('!!document.querySelector("#view-unexamined [data-another]")')) {
  const first = await evaluate('document.querySelector("#view-unexamined .suggestion").getAttribute("href")');
  await evaluate('document.querySelector("#view-unexamined [data-another]").click()');
  ok(await evaluate('document.querySelector("#view-unexamined .suggestion").getAttribute("href") !== ' + JSON.stringify(first)), 'Another shows a different moment');
}
ok(!(await evaluate('!!document.querySelector("#h-unexamined .pencil-circle")')), 'no count of what is left');
await shot('happy-unexamined');

console.log('skip (Decision 065): an event leaves Unexamined and the Narrative, then comes back');
{
  const first = await evaluate('(() => { const a = document.querySelector("#view-unexamined a.row"); return a && { href: a.getAttribute("href"), name: a.querySelector(".row-title").textContent }; })()');
  ok(!!first, `an Unexamined event to skip (${first && first.name})`);
  if (first) {
    const id = first.href.split('/').pop();
    const rowFor = `!!document.querySelector('#view-unexamined a.row[href="${first.href}"]')`;
    await evaluate(`location.hash = "${first.href}"; true`);
    ok(await waitFor('!!document.querySelector("[data-skip]") && document.querySelector("[data-skip]").textContent === "Skip"'), 'the event page offers Skip');
    await evaluate('document.querySelector("[data-skip]").click(); true');
    ok(await waitFor('document.querySelector("[data-skip]") && document.querySelector("[data-skip]").textContent === "Bring back"'), 'after Skip it offers Bring back');
    await evaluate('location.hash = "#/unexamined"; true');
    await waitFor('document.querySelectorAll("#view-unexamined a.row").length > 0');
    ok(!(await evaluate(rowFor)), `${first.name} is gone from Unexamined`);
    await evaluate('location.hash = "#/ledger"; true');
    ok(await waitFor('!!document.querySelector("details.skipped")'), 'the Narrative gathers it under "skipped"');
    await shot('skipped-narrative');
    await evaluate(`location.hash = "#/t/${id}"; true`);
    await waitFor('document.querySelector("[data-skip]") && document.querySelector("[data-skip]").textContent === "Bring back"');
    await evaluate('document.querySelector("[data-skip]").click(); true');
    ok(await waitFor('document.querySelector("[data-skip]").textContent === "Skip"'), 'Bring back restores it');
    await evaluate('location.hash = "#/unexamined"; true');
    ok(await waitFor(rowFor), `${first.name} is back in Unexamined (fixture left as found)`);
  }
}

console.log('Narrative thread (D10): written memos are marks with the memo as headline; waiting events are quiet');
{
  await evaluate('location.hash = "#/ledger/2026-11"; true');
  ok(await waitFor('document.querySelectorAll("#view-ledger .trow.is-written").length > 0'), 'written memos show as filled marks');
  ok(await evaluate('document.querySelectorAll("#view-ledger .trow.is-waiting").length > 0'), 'waiting events show as quiet marks');
  ok(await evaluate('/penguins/.test(document.querySelector("#view-ledger .thread").innerText)'), 'a memo is the headline');
  ok(await evaluate('getComputedStyle(document.querySelector(".trow.is-written .trow-mark")).backgroundColor !== getComputedStyle(document.querySelector(".trow.is-waiting .trow-mark")).backgroundColor'), 'written and waiting marks differ');
  ok(await evaluate('document.querySelectorAll("#view-ledger .strip-bar span").length >= 2 && document.querySelectorAll("#view-ledger .strip-legend li").length === document.querySelectorAll("#view-ledger .strip-bar span").length'), 'the month strip has a part per theme, each named in the legend (D11)');
  await shot('narrative-thread');
  // D9: Written only, then back to All.
  await evaluate('(() => { const s = document.getElementById("filter-show"); s.value = "written"; s.dispatchEvent(new Event("change")); return true; })()');
  ok(await waitFor('document.querySelectorAll("#view-ledger .trow.is-waiting").length === 0 && document.querySelectorAll("#view-ledger .trow.is-written").length > 0'), 'filter Written shows only written memos');
  await shot('narrative-written');
  await evaluate('(() => { const s = document.getElementById("filter-show"); s.value = "all"; s.dispatchEvent(new Event("change")); return true; })()');
  ok(await waitFor('document.querySelectorAll("#view-ledger .trow.is-waiting").length > 0'), 'back to All');
}

console.log('Themes as collections (D12)');
{
  await evaluate('location.hash = "#/story"; true');
  ok(await waitFor('document.querySelectorAll("#view-story .theme-row[data-theme]").length >= 2'), 'the Story lists themes as collections');
  await evaluate('document.querySelector("#view-story .theme-row[data-theme=\\"Great meals\\"]").click(); true');
  ok(await waitFor('/Anniversary/.test(document.querySelector("#view-story .story")?.innerText || "") && !/penguins/.test(document.querySelector("#view-story .story")?.innerText || "")'), 'a theme shows only its memos');
  await shot('story-theme');
  ok(await evaluate('document.querySelector("#view-story .story-entry")?.firstElementChild?.classList.contains("story-text")'), 'a Story entry leads with its memo (D6)');
  ok(await evaluate('!!document.querySelector("#view-story .theme-row.every")'), 'Every memo leads back');
}

console.log('event page (D6): the Setting and the memo lead; the money is a footnote');
{
  await evaluate('location.hash = "#/t/a3b8c10c-68b8-4bfe-9380-c87b7015a49d"; true');
  ok(await waitFor('!!document.querySelector("#memo-body") && document.querySelector("#memo-body").value.length > 0'), 'the written memo is in the editor');
  ok(await evaluate('!!document.querySelector(".txn-head .tile")'), 'the Setting tile heads the page');
  ok(await evaluate('(() => { const m = document.querySelector("#memo-body"), d = document.querySelector(".txn-details"); return !!(m && d && (m.compareDocumentPosition(d) & Node.DOCUMENT_POSITION_FOLLOWING)); })()'), 'the money footnote comes after the memo');
  ok(await evaluate('/\\$/.test(document.querySelector(".txn-details summary").textContent) && !document.querySelector(".txn-details").open'), 'the amount sits in the closed footnote');
  ok(!(await evaluate('/\\bnull\\b/.test(document.querySelector("#view-txn").innerText)')), 'no stray "null" text on the page');
  await shot('event-memo-first');
  // D12: the share card is private by default; Show where adds the place.
  await evaluate('document.querySelector(".share-panel").open = true; true');
  ok(await waitFor('document.querySelector(".share-line")?.textContent === "Nov 16, 2026"'), 'the share card shows only the date by default');
  ok(await evaluate('/penguins/.test(document.querySelector(".share-card blockquote").textContent) && !!document.querySelector(".share-theme")'), 'with the memo and its theme');
  await evaluate('document.getElementById("share-where").click(); true');
  ok(await waitFor('document.querySelector(".share-line").textContent === "Nov 16, 2026 · Denver Zoo"'), 'Show where adds the place');
  await shot('share-card');
  // D8: the Setting's page, every visit there; Back returns to the event.
  await evaluate('document.querySelector("[data-setting]").click(); true');
  ok(await waitFor('location.hash === "#/setting/Denver%20Zoo" && /\\bvisits?\\b/.test(document.querySelector("[data-setting-summary]")?.textContent || "")'), 'Every visit opens the Setting with its count');
  ok(await evaluate('/penguins/.test(document.querySelector("#view-setting .thread").innerText) && !/Denver Zoo/.test(document.querySelector("#view-setting .thread").innerText)'), 'with its memos, the place said once at the top');
  ok(!(await evaluate('/\\bnull\\b/.test(document.querySelector("#view-setting").innerText)')), 'no stray "null" on the Setting page');
  await shot('setting');
  // D8 renames: the person names the place; clearing the name brings the bank's back.
  const renameTo = async (v) => {
    await evaluate('document.querySelector("#view-setting [data-rename]").click(); true');
    await evaluate(`(() => { const i = document.querySelector("[data-rename-input]"); i.value = ${JSON.stringify(v)}; i.form.requestSubmit(); return true; })()`);
  };
  await renameTo('The Zoo');
  ok(await waitFor('document.querySelector("#h-setting")?.textContent === "The Zoo" && /On the statement: Denver Zoo/.test(document.querySelector("#view-setting").innerText)'), 'Rename names the Setting, the statement name kept beside it');
  await shot('setting-renamed');
  await renameTo('');
  ok(await waitFor('document.querySelector("#h-setting")?.textContent === "Denver Zoo" && !/On the statement/.test(document.querySelector("#view-setting").innerText)'), 'a cleared name brings the bank\'s name back');
  await evaluate('document.querySelector("#view-setting [data-back]").click(); true');
  ok(await waitFor('location.hash === "#/t/a3b8c10c-68b8-4bfe-9380-c87b7015a49d" && !document.getElementById("view-txn").hidden'), 'Back returns to the event');
}

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

console.log('import (stranger, through the real file input)');
{
  const s = await sessionFor('stranger');
  const hdr = { apikey: K, authorization: 'Bearer ' + s.access_token };
  const FIXTURE = path.join(ROOT, 'tests/fixtures/applecard-sample.csv');
  const choose = async () => {
    const doc = await cdp('DOM.getDocument', { depth: -1 });
    const q = await cdp('DOM.querySelector', { nodeId: doc.result.root.nodeId, selector: '#import-file' });
    await cdp('DOM.setFileInputFiles', { nodeId: q.result.nodeId, files: [FIXTURE] });
  };
  const clickImport = () => evaluate(`[...document.querySelectorAll("${VIS}button")].find(b => /^Import \\d+ Apple Card events$/.test(b.textContent))?.click(), true`);
  try {
    await openAs('stranger', '#/import');
    // A new, empty account lands on Unexamined; go to Import once the app has settled.
    await evaluate('location.hash = "#/import"; true');
    ok(await waitFor('!document.getElementById("view-import").hidden'), 'the Import view is on screen');
    await choose();
    ok(await waitFor(`[...document.querySelectorAll("${VIS}button")].some(b => /^Import \\d+ Apple Card events$/.test(b.textContent))`), 'choosing the export shows a preview and Import N Apple Card events');
    const n = await evaluate(`Number(([...document.querySelectorAll("${VIS}button")].find(b => /^Import \\d+/.test(b.textContent))?.textContent.match(/\\d+/) || [0])[0])`);
    await clickImport();
    const lines = 'document.querySelector("section:not([hidden]) [data-body]")?.innerText.split("\\n") || []';
    ok(await waitFor(`(${lines}).some(l => l.trim() === "${n} new.")`, 20000), `first import: ${n} new`);
    await shot('import-first');
    await evaluate('document.getElementById("import-file").value = ""; true');
    await choose();
    await waitFor(`[...document.querySelectorAll("${VIS}button")].some(b => /^Import \\d+ Apple Card events$/.test(b.textContent))`);
    await clickImport();
    ok(await waitFor(`(${lines}).some(l => l.trim() === "0 new, ${n} already in CentMemo.")`, 20000), `second import: 0 new, ${n} already in CentMemo (Decision 057)`);
    await cdp('Page.navigate', { url: SITE + '#/ledger' });
    ok(await waitFor('document.querySelectorAll("#view-ledger .trow").length > 0'), 'the imported purchases appear in the Narrative');
    // D14: with purchases and no themes, Unexamined asks which starter themes fit (all unticked).
    await evaluate('location.hash = "#/unexamined"; true');
    ok(await waitFor('!!document.querySelector("#view-unexamined .first-themes")'), 'first run asks "Which of these sound like you?"');
    ok(await evaluate('document.querySelectorAll("#view-unexamined .starter-pick input").length === 13 && ![...document.querySelectorAll("#view-unexamined .starter-pick input")].some(b => b.checked)'), 'all 13 starter themes, none ticked');
    await shot('first-themes');
    await evaluate('document.getElementById("starter-moss").click(); [...document.querySelectorAll(".first-themes button")].find(b => b.textContent === "Keep these").click(); true');
    ok(await waitFor('!document.querySelector("#view-unexamined .first-themes")'), 'Keep these closes the card');
    const kept = await (await fetch(P + '/rest/v1/life_values?select=name,color', { headers: hdr })).json();
    ok(Array.isArray(kept) && kept.length === 1 && kept[0].name === 'Health', 'and keeps exactly the ticked theme (Health)');
    ok(kept[0]?.color === 'moss', `which stores its own color at creation (moss; got ${kept[0]?.color})`);
    // S1: a Venmo statement through the same file input lands in its own account, with its notes.
    await evaluate('location.hash = "#/import"; true');
    await waitFor('!document.getElementById("view-import").hidden');
    ok(await evaluate('[...document.querySelectorAll("[data-export-paths] summary")].map(s => s.textContent).join() === "Apple Card,Venmo,PayPal,Cash App"'), 'the import page shows each source\'s documented export path');
    await evaluate('document.querySelectorAll("[data-export-paths] details")[1].open = true; true');
    await shot('import-paths');
    await evaluate('document.getElementById("import-file").value = ""; true');
    {
      const doc = await cdp('DOM.getDocument', { depth: -1 });
      const q = await cdp('DOM.querySelector', { nodeId: doc.result.root.nodeId, selector: '#import-file' });
      await cdp('DOM.setFileInputFiles', { nodeId: q.result.nodeId, files: [path.join(ROOT, 'tests/fixtures/venmo-sample.csv')] });
    }
    ok(await waitFor(`[...document.querySelectorAll("${VIS}button")].some(b => b.textContent === "Import 3 Venmo events")`), 'a Venmo statement is recognized: Import 3 Venmo events');
    await evaluate(`[...document.querySelectorAll("${VIS}button")].find(b => b.textContent === "Import 3 Venmo events").click(); true`);
    ok(await waitFor(`(${lines}).some(l => l.trim() === "3 new.")`, 20000), 'Venmo import: 3 new');
    const venmo = await (await fetch(P + '/rest/v1/transactions?select=description,accounts(display_name)&source_id=like.venmo*', { headers: hdr })).json();
    ok(venmo.length === 3 && venmo.every((t) => t.accounts?.display_name === 'Venmo') && venmo.some((t) => /Pizza night/.test(t.description)), 'in the Venmo account, with the person\'s notes');
  } finally {
    await fetch(P + '/rest/v1/accounts?source=eq.csv', { method: 'DELETE', headers: hdr });
    await fetch(P + '/rest/v1/life_values?id=not.is.null', { method: 'DELETE', headers: hdr });
    await fetch(P + '/rest/v1/import_batches?source=eq.csv', { method: 'DELETE', headers: hdr });
    const left = await (await fetch(P + '/rest/v1/transactions?select=id', { headers: hdr })).json();
    ok(Array.isArray(left) && left.length === 0, `stranger left empty (${Array.isArray(left) ? left.length : JSON.stringify(left).slice(0, 80)} transactions)`);
  }
}

console.log('photo attached on the iPhone');
{
  const s = await sessionFor('owner');
  const hdr = { apikey: K, authorization: 'Bearer ' + s.access_token, 'content-type': 'application/json', prefer: 'return=representation' };
  const TXN = 'a3b8c10c-68b8-4bfe-9380-c87b7015a49d';
  const made = await (await fetch(P + '/rest/v1/attachments', { method: 'POST', headers: hdr, body: JSON.stringify({ transaction_id: TXN, kind: 'photo', device_ref: 'web-test/L0/001' }) })).json();
  try {
    await openAs('owner', '#/t/' + TXN);
    // As with Import: set the route once the app has settled (sign-in can rewrite it).
    await evaluate(`location.hash = "#/t/${TXN}"; true`);
    await waitFor(`!!document.querySelector("${VIS}#memo-body")`);
    ok(await waitFor(`/1 photo attached in the CentMemo iPhone app/.test(document.querySelector("${VIS}.photos-note")?.textContent || "")`), 'the web says a photo is attached, and where');
    await shot('photo-note');
    await fetch(`${P}/rest/v1/attachments?id=eq.${made[0].id}`, { method: 'DELETE', headers: hdr });
    await cdp('Page.reload', { ignoreCache: true });
    await waitFor('document.readyState === "complete" && !document.getElementById("app-screen").hidden');
    await waitFor(`!!document.querySelector("${VIS}#memo-body")`);
    ok(!(await evaluate(`!!document.querySelector("${VIS}.photos-note")`)), 'and says nothing when there is none (control)');
  } finally {
    if (made?.[0]?.id) await fetch(`${P}/rest/v1/attachments?id=eq.${made[0].id}`, { method: 'DELETE', headers: hdr });
  }
}

console.log('Apple same-window return (the fallback when a popup is blocked)');
{
  const consent = SITE + 'oauth/consent/';
  const sentText = 'document.querySelector("[data-sent]")?.textContent || ""';
  // A real return from appleid.apple.com is a full page load; a hash-only
  // navigation would keep the document, so leave first, then arrive.
  const arrive = async (url) => { await cdp('Page.navigate', { url: 'about:blank' }); await cdp('Page.navigate', { url }); await waitFor('document.readyState === "complete"'); };
  await cdp('Page.navigate', { url: consent + '?authorization_id=test' });
  await waitFor('document.readyState === "complete"');
  await evaluate('localStorage.clear(); sessionStorage.clear(); true');
  await arrive(consent + '#error=user_cancelled_authorize&state=x');
  ok(await waitFor(`/canceled/.test(${sentText})`), 'a canceled Apple sign-in says so');
  ok(await evaluate('location.hash === ""'), 'and the token-bearing hash is cleared');
  await arrive(consent + '#id_token=abc&state=forged');
  ok(await waitFor(`/didn.t start on this page/.test(${sentText})`), 'a return this page did not start is refused (state check)');
  await evaluate(`sessionStorage.setItem("cm_apple_return", JSON.stringify({ raw: "r", state: "0123456789abcdef0123456789abcdef.c", back: "?authorization_id=test" })); true`);
  await arrive(consent + '#id_token=not.a.token&state=0123456789abcdef0123456789abcdef.c');
  ok(await waitFor(`${sentText}.length > 0 && !/didn.t start|canceled/.test(${sentText})`), 'a matching return reaches Supabase, which refuses a token Apple did not sign');
  // The whole chain as Apple drives it: POST to apple-return, follow its redirect.
  const st = '0123456789abcdef0123456789abcdef.c';
  const hop = await fetch(P + '/functions/v1/apple-return', { method: 'POST', redirect: 'manual',
    body: new URLSearchParams({ state: st, id_token: 'not.a.token' }) });
  const loc = hop.headers.get('location') || '';
  ok(hop.status === 303 && loc.startsWith('https://centmemo.com/oauth/consent/#'), `apple-return sends the browser back to the consent page (${hop.status})`);
  await arrive(consent + '?authorization_id=test');
  await evaluate(`sessionStorage.setItem("cm_apple_return", JSON.stringify({ raw: "r", state: "${st}", back: "?authorization_id=test" })); true`);
  await arrive(consent + loc.slice(loc.indexOf('#')));
  ok(await waitFor(`${sentText}.length > 0 && !/didn.t start|canceled/.test(${sentText})`), 'and the page takes it up: state matches, Supabase judges the token');
  await arrive(SITE + '#id_token=abc&state=forged');
  ok(await waitFor('!document.getElementById("auth-error").hidden'), 'the main site finishes the return before routing');
  ok(await evaluate('location.hash === ""'), 'and its router never sees the token');
}

console.log('reviewer sign-in (Decision 063): a real authorization, approved by the reviewer account');
{
  const { createHash, randomBytes } = await import('node:crypto');
  const b64 = (b) => b.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const REDIRECT = 'http://localhost:8799/callback';
  const reg = await (await fetch(P + '/auth/v1/oauth/clients/register', { method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ client_name: 'CentMemo reviewer-path test', redirect_uris: [REDIRECT], grant_types: ['authorization_code', 'refresh_token'], response_types: ['code'], token_endpoint_auth_method: 'none' }) })).json();
  const verifier = b64(randomBytes(32)), state = b64(randomBytes(9));
  const auth = new URL(P + '/auth/v1/oauth/authorize');
  for (const [k, v] of Object.entries({ response_type: 'code', client_id: reg.client_id, redirect_uri: REDIRECT, state,
    code_challenge: b64(createHash('sha256').update(verifier).digest()), code_challenge_method: 'S256' })) auth.searchParams.set(k, v);
  const loc = (await fetch(auth, { redirect: 'manual' })).headers.get('location') || '';
  const authId = new URL(loc, P).searchParams.get('authorization_id');
  ok(!!authId, 'an authorization opens on the consent page');
  await cdp('Page.navigate', { url: 'about:blank' });
  await cdp('Page.navigate', { url: SITE + 'oauth/consent/?authorization_id=' + authId });
  await waitFor('document.readyState === "complete"');
  await evaluate('localStorage.clear(); sessionStorage.clear(); location.reload(); true');
  await waitFor('!document.querySelector("[data-state=signed-out]").hidden');
  // Control: another account is turned back to Apple.
  await evaluate(`document.querySelector("details.reviewer").open = true; document.getElementById("rv-email").value = ${JSON.stringify(users.stranger.email)}; document.getElementById("rv-password").value = "x"; document.querySelector("[data-reviewer] button").click(); true`);
  ok(await waitFor('/Please use Sign in with Apple/.test(document.querySelector("[data-sent]").textContent)'), 'any other email is refused with a pointer to Apple');
  await evaluate(`document.getElementById("rv-email").value = ${JSON.stringify(users.reviewer.email)}; document.getElementById("rv-password").value = ${JSON.stringify(users.reviewer.password)}; document.querySelector("[data-reviewer] button").click(); true`);
  ok(await waitFor('!document.querySelector("[data-state=ask]").hidden', 20000), 'the reviewer signs in and is asked whether to connect');
  ok(/review@centmemo\.com/.test(await evaluate('document.querySelector("[data-who]").textContent')), 'as the reviewer account');
  // The callback has no listener, so read the browser's own record of the request.
  const seen = [];
  const onMsg = (e) => { const m = JSON.parse(e.data); if (m.method === 'Network.requestWillBeSent') seen.push(m.params.request.url); };
  ws.addEventListener('message', onMsg);
  await evaluate('document.querySelector("[data-approve]").click(); true');
  for (let t = 0; t < 20000 && !seen.some((u) => u.startsWith(REDIRECT)); t += 250) await sleep(250);
  ws.removeEventListener('message', onMsg);
  const back = seen.find((u) => u.startsWith(REDIRECT)) || '';
  ok(/[?&]code=/.test(back) && back.includes('state=' + state), `approving returns to the client with a code and the same state (${back ? 'callback requested' : 'no callback'})`);
}

console.log('connector address');
await openAs('owner', '#/settings');
await evaluate('location.hash = "#/settings"; true');
ok(await waitFor('/mcp\\.centmemo\\.com/.test(document.body.innerText)'), 'web Settings shows https://mcp.centmemo.com');
ok(!(await evaluate('/supabase\\.co\\/functions/.test(document.body.innerText)')), 'and never the Supabase address');
ok(await waitFor('document.querySelectorAll(".starters [data-starter]").length > 0 && !!document.querySelector(\'.starters [data-starter="People I love"]\')'), 'Settings offers the starter themes the person does not have yet');
ok(await evaluate('getComputedStyle(document.querySelector(\'.starters [data-starter="People I love"] .theme-mark\')).backgroundColor !== "rgba(0, 0, 0, 0)"'), 'each with its own color mark');
ok(await evaluate(`(() => { const home = document.querySelector('.starters [data-starter="Home"] .theme-mark')?.style.background; const used = [...document.querySelectorAll('#view-settings .list:not(.starters) .theme-mark')].map(i => getComputedStyle(i).backgroundColor); return !!home && !home.includes('clay') || !used.includes(getComputedStyle(document.querySelector('.starters [data-starter="Home"] .theme-mark')).backgroundColor); })()`), 'a starter previews a color no current theme shows, so adding it shifts nothing');
await shot('settings-starters');

console.log('static pages');
for (const page of ['connect/', 'support/', 'privacy/', 'terms/']) {
  await cdp('Page.navigate', { url: SITE + page });
  await waitFor('document.readyState === "complete" && !!document.querySelector("h1")');
  await sleep(300);
  const w = await evaluate('document.documentElement.scrollWidth');
  ok(w <= 375, `${page} fits 375px (${w})`);
  const face = await evaluate('getComputedStyle(document.querySelector("h1")).fontFamily');
  ok(/Newsreader/.test(face), `${page} heading in Newsreader (DESIGN T1)`);
  await shot('page-' + page.replace('/', ''));
}
ok(/never shared with Claude/.test(await (async () => { await cdp('Page.navigate', { url: SITE + 'connect/' }); await waitFor('!!document.querySelector("h1")'); return evaluate('document.body.innerText'); })()),
  'connect/ states that Wallet purchases are never shared with Claude');
ok(await evaluate('/https:\\/\\/mcp\\.centmemo\\.com/.test(document.body.innerText)'), 'connect/ gives the public address');

ok(await evaluate('document.documentElement.scrollWidth <= 375'), `no horizontal scroll at 375 (${await evaluate('document.documentElement.scrollWidth')})`);
console.log(failures ? `FAIL: ${failures} web state check(s); frames in ${OUT}` : `PASS: four states at 375px; frames in ${OUT}`);
ws.close(); cleanup();
process.exit(failures ? 1 : 0);
