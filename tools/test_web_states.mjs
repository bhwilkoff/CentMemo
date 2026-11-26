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
let OUT_DIR = OUT;
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
  writeFileSync(path.join(OUT_DIR, name + '.png'), Buffer.from(r.result.data, 'base64'));
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

// node tools/test_web_states.mjs --widths [375,768,...]: every screen at every
// width, frames to read (DESIGN W7), in build/qa/web-states-<date>/widths/.
if (process.argv[2] === '--widths') {
  OUT_DIR = path.join(OUT, 'widths');
  mkdirSync(OUT_DIR, { recursive: true });
  const WIDTHS = (process.argv[3] || '375,768,1024,1440').split(',').map(Number);
  const item = 'a3b8c10c-68b8-4bfe-9380-c87b7015a49d';
  const SCREENS = { unexamined: '#/unexamined', narrative: '#/ledger', story: '#/story', event: '#/t/' + item, setting: '#/setting/Denver%20Zoo', settings: '#/settings', import: '#/import', share: '#/t/' + item, link: '#/t/' + item, themelink: '#/story/value:THEME' };
  await openAs('owner', '#/unexamined');
  for (const w of WIDTHS) {
    await cdp('Emulation.setDeviceMetricsOverride', { width: w, height: w < 600 ? 812 : w < 900 ? 1024 : 900, deviceScaleFactor: 1, mobile: w < 600 });
    SCREENS.themelink = '#/story/' + (await evaluate('(async () => "value:" + (await API.values()).find((v) => v.name === "Great meals").id)()'));
  for (const [name, hash] of Object.entries(SCREENS)) {
      await evaluate(`location.hash = ${JSON.stringify(hash)}; true`);
      await sleep(1800);
      if (name.endsWith('link')) { await evaluate(`(() => { const p = document.querySelector('section:not([hidden]) .link-panel'); const o = p.closest('.one-share'); if (o) { o.open = true; o.querySelector('input[value=link]').click(); } else p.open = true; p.scrollIntoView(); return true; })()`); await sleep(1800); }
      if (name === 'share') { await evaluate('(() => { const p = document.querySelector(".share-panel"), o = p.closest(".one-share"); if (o) o.open = true; p.open = true; p.scrollIntoView(); return true; })()'); await sleep(600); }
      await shot(`${w}-${name}`);
      const over = await evaluate('document.documentElement.scrollWidth - innerWidth');
      if (over > 0) ok(false, `${name} scrolls sideways by ${over} at ${w}`);
    }
  }
  console.log(failures ? 'FAIL: sideways scroll above' : 'frames in ' + OUT_DIR);
  process.exit(failures ? 1 : 0);
}

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

console.log('no screen prints a stray value, and the Story can change months');
for (const route of ['unexamined', 'ledger', 'story', 'settings', 'import', 't/a3b8c10c-68b8-4bfe-9380-c87b7015a49d', 'setting/Denver%20Zoo']) {
  await evaluate(`location.hash = "#/${route}"; true`);
  await sleep(1500);
  ok(await evaluate('!document.body.innerText.split("\\n").some((l) => /^(null|undefined|false|\\[object .*)$/.test(l.trim()))'), `${route} prints no null`);
}
await evaluate('location.hash = "#/story"; true');
ok(await waitFor('document.querySelectorAll("#story-scope option").length === 24 && !!document.getElementById("story-scope").value'), 'the Story offers 24 months and shows the current one');
await evaluate('location.hash = "#/unexamined"; true');
await waitFor('document.querySelectorAll("#view-unexamined a.row").length > 0');

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
  // N4: the whole theme, designed by the person; any memo can be left out.
  await evaluate('document.querySelector("#view-story [data-share-theme] summary").click(); true');
  const tcard = '#view-story [data-share-theme] .share-canvas', label = `document.querySelector("${tcard}")?.getAttribute("aria-label") || ""`;
  ok(await waitFor(`/Anniversary/.test(${label})`), 'Share this theme makes one card of the theme\'s memos');
  ok(!(await evaluate('/[$]|amount/i.test(document.querySelector("#view-story [data-share-theme]").innerText)')), 'and offers no amount');
  for (const look of ['pages', 'lines', 'cover']) {
    const was = await evaluate(`document.querySelector("${tcard}").toDataURL().length`);
    await evaluate(`document.getElementById("share-theme-look-${look}").click(); true`);
    ok(await waitFor(`document.querySelector("${tcard}").toDataURL().length !== ${was}`), `the theme's ${look} look draws`);
  }
  await evaluate('document.getElementById("share-theme-look-lines").click(); document.querySelectorAll("#view-story .share-memo-words")[0].querySelectorAll("button")[1].click(); true');
  await shot('share-theme');
  await evaluate('document.getElementById("share-theme-0").click(); true');
  ok(await waitFor(`!(${label}).includes(document.querySelectorAll("#view-story .story-text")[0].textContent)`), 'a memo the person unticks leaves the card');
  ok(await evaluate('!!document.querySelector("#view-story .theme-row.every")'), 'Every memo leads back');
}

console.log('a memo saves itself (W3), and can be shared in the words just written');
{
  const page = '#/t/e5626ed0-b9f2-48a0-8df7-672ae6016a40';
  await evaluate(`location.hash = "${page}"; true`);
  await waitFor('document.querySelector("#view-txn #memo-body")?.value === "" && /King Soopers/.test(document.querySelector("#h-txn")?.textContent || "")');
  ok(await evaluate('![...document.querySelectorAll("#view-txn button")].some((b) => b.textContent === "Save")'), 'there is no Save button');
  const write = (words) => evaluate(`(() => { const a = document.querySelector("#view-txn #memo-body"); a.value = ${JSON.stringify(words)}; a.dispatchEvent(new Event("input")); return true; })()`);
  const said = '[...document.querySelectorAll("#view-txn .share-panel:not(.link-panel) .share-words")].map((n) => n.textContent).join(" ")';
  ok(await evaluate('!document.querySelector("#view-txn .share-panel")'), 'with no memo there is nothing to share');
  try {
    await write('Apples for the pie.');
    ok(await waitFor(`/Apples/.test(${said}) && !!document.querySelector("#view-txn .link-panel")`), 'after a pause it is sent, and Share and Make a link are there');
    // W4: the format bar marks the selection; the share shows words, never the marks.
    await evaluate('(() => { const a = document.querySelector("#view-txn #memo-body"); a.setSelectionRange(0, 6); document.querySelector("#view-txn .format-bar .fmt-b").click(); return true; })()');
    ok(await evaluate('document.querySelector("#view-txn #memo-body").value === "**Apples** for the pie."'), 'Bold wraps the chosen words in the memo\'s marks');
    ok(await evaluate('!document.querySelector("#view-txn .format-bar [aria-label^=Underline]")'), 'and there is no underline');
    ok(await waitFor(`/Apples for the pie/.test(${said}) && !/\\*/.test(${said})`), 'the share shows the words without marks');
    await write('Pears for the tart.');
    ok(await waitFor(`/Pears/.test(${said}) && !/Apples/.test(${said})`), 'after an edit, they hold the new words');
    await evaluate('location.hash = "#/unexamined"; true');
    await waitFor('!document.querySelector("#view-txn:not([hidden])")');
    await evaluate(`location.hash = "${page}"; true`);
    ok(await waitFor('document.querySelector("#view-txn #memo-body")?.value === "Pears for the tart."'), 'and it is there when the page opens again');
    ok(await evaluate('!Object.keys(localStorage).some((k) => k.startsWith("centmemo-unsent-"))'), 'nothing is left waiting in the browser');
  } finally {
    await write('');
    await evaluate('location.hash = "#/unexamined"; true');
    await waitFor('!document.querySelector("#view-txn:not([hidden])")');
    await evaluate(`location.hash = "${page}"; true`);
  }
  ok(await waitFor('document.querySelector("#view-txn #memo-body")?.value === "" && /King Soopers/.test(document.querySelector("#h-txn")?.textContent || "") && !document.querySelector("#view-txn .share-panel")'), 'an emptied memo is removed on leaving, and Share with it');
}

console.log('a drawing made on the iPhone shows on the web memo page (W5)');
{
  const page = '#/t/e5626ed0-b9f2-48a0-8df7-672ae6016a40';
  // Made here as the iPhone makes one: a row of kind "ink" and a PNG in the person's folder.
  const made = await evaluate(`(async () => {
    const db = API.client(), { data: { user } } = await db.auth.getUser();
    const { data: row, error } = await db.from('attachments').insert({ transaction_id: 'e5626ed0-b9f2-48a0-8df7-672ae6016a40', kind: 'ink', caption: 'Drawing' }).select('id').single();
    if (error) return 'insert: ' + error.message;
    const c = document.createElement('canvas'); c.width = 200; c.height = 120;
    const g = c.getContext('2d'); g.fillStyle = '#FBFAF7'; g.fillRect(0, 0, 200, 120); g.strokeStyle = '#4A1520'; g.lineWidth = 4; g.beginPath(); g.moveTo(20, 60); g.lineTo(180, 70); g.stroke();
    const png = await new Promise((r) => c.toBlob(r, 'image/png'));
    const path = user.id + '/' + row.id + '.png';
    const up = await db.storage.from('attachments').upload(path, png, { contentType: 'image/png', upsert: true });
    if (up.error) return 'upload: ' + up.error.message;
    await db.from('attachments').update({ storage_path: path }).eq('id', row.id);
    window.__ink = { id: row.id, path };
    return 'ok';
  })()`);
  ok(made === 'ok', 'a drawing is kept in the person\'s folder (' + made + ')');
  try {
    await evaluate('location.hash = "#/unexamined"; true');
    await waitFor('!document.querySelector("#view-txn:not([hidden])")');
    await evaluate(`location.hash = "${page}"; true`);
    ok(await waitFor('(() => { const i = document.querySelector("#view-txn .ink-picture"); return !!(i && i.complete && i.naturalWidth === 200); })()'), 'the drawing shows under the memo');
    await shot('memo-with-drawing');
  } finally {
    await evaluate(`(async () => { const db = API.client(); await db.storage.from('attachments').remove([window.__ink.path]); await db.from('attachments').delete().eq('id', window.__ink.id); return true; })()`);
  }
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
  // W2 (Ben, 2026-11-26: "they are not color-coded as they should be"): each theme
  // chip carries its own color, not the person's one color.
  const dots = await evaluate('JSON.stringify([...document.querySelectorAll("#view-txn .chips .chip")].map((c) => getComputedStyle(c, "::before").backgroundColor))');
  ok(JSON.parse(dots).length > 1 && new Set(JSON.parse(dots)).size > 1, 'theme chips wear their own colors');
  // N4: the person designs the share; nothing on it or in it is an amount.
  // W6: one Share, with Picture and Link inside it, and what each keeps.
  ok(await evaluate('document.querySelectorAll("#view-txn .one-share").length === 1 && document.querySelectorAll("#view-txn .one-share .share-kinds input").length === 2'), 'one Share, with Picture and Link inside');
  await evaluate('document.querySelector("#view-txn .one-share").open = true; document.querySelector("#view-txn .one-share").scrollIntoView(); true');
  await sleep(500);
  await shot('one-share');
  ok(await evaluate('/Nothing is kept online/.test(document.querySelector("#view-txn .share-fact").textContent) && !document.querySelector("#view-txn .share-panel:not(.link-panel)").hidden && document.querySelector("#view-txn .link-panel").hidden'), 'a picture first, and it says nothing is kept online');
  ok(await waitFor('document.querySelector("#view-txn .share-canvas")?.width === 1080'), 'the share studio draws a square card');
  const inked = 'new Set(document.querySelector("#view-txn .share-canvas").getContext("2d").getImageData(0, 0, 1080, 600).data).size > 20';
  ok(await waitFor(inked), 'with the memo drawn on it');
  ok(await evaluate('!/\\$|amount/i.test(document.querySelector("#view-txn .share-panel").innerText)'), 'and no amount is offered');
  await evaluate('document.querySelector("#view-txn .share-panel").scrollIntoView(); document.querySelectorAll("#view-txn .share-words button")[13].click(); document.querySelectorAll("#view-txn .share-words button")[16].click(); true');
  ok(await evaluate('document.querySelectorAll("#view-txn .share-words button[aria-pressed=true]").length === 4'), 'the person underlines the words that matter');
  for (const look of ['setting', 'theme', 'words', 'page']) {
    const was = await evaluate('document.querySelector("#view-txn .share-canvas").toDataURL().length');
    await evaluate(`document.getElementById("share-look-${look}").click(); true`);
    ok(await waitFor(`document.querySelector("#view-txn .share-canvas").toDataURL().length !== ${was}`), `the ${look} look draws`);
  }
  await evaluate('document.getElementById("share-shape-tall").click(); true');
  ok(await waitFor('document.querySelector("#view-txn .share-canvas").height === 1920'), 'and the tall shape');
  await evaluate('document.getElementById("share-shape-square").click(); true');
  await shot('share-card');
  // N4: a link, made and opened and turned off.
  await evaluate('document.querySelector("#view-txn .one-share input[value=link]").click(); true');
  ok(await evaluate('document.querySelector("#view-txn .link-panel").open && !document.querySelector("#view-txn .link-panel").hidden && /turn it off/.test(document.querySelector("#view-txn .share-fact").textContent)'), 'Link opens the page maker in the same Share');
  ok(await waitFor('/penguins/.test(document.querySelector("#view-txn .link-panel .sp blockquote")?.textContent || "")'), 'Make a link shows the reader\'s page, live');
  ok(await waitFor('document.getElementById("link-place-0")?.value === "Denver Zoo"'), 'an imported purchase may start with its place');
  await evaluate('(() => { const b = document.querySelectorAll("#view-txn .link-panel .share-words button"); b[13].click(); document.querySelectorAll("#view-txn .link-panel .share-words button")[16].click(); document.getElementById("link-pencil-circle").click(); const p = document.getElementById("link-place-0"); p.value = "The zoo"; p.dispatchEvent(new Event("input")); return true; })()');
  ok(await waitFor('document.querySelector("#view-txn .link-panel .sp mark")?.textContent === "we stayed until closing." && document.querySelectorAll("#view-txn .link-panel svg.sp-ink path").length > 0'), 'the writer chooses the marked words, and the pencil draws them');
  ok(await evaluate('document.querySelector("#view-txn .link-panel .sp-place").textContent === "The zoo" && document.querySelector("#view-txn .link-panel .sp").classList.contains("bold")'), 'the place is in their words, and bold is where it starts');
  ok(!(await evaluate('/[$]/.test(document.querySelector("#view-txn .link-panel").innerText)')), 'and no amount anywhere in it');
  await evaluate('document.querySelector("#view-txn .link-panel").scrollIntoView(); true');
  await shot('link-maker');
  await evaluate('[...document.querySelectorAll("#view-txn .link-panel button")].find((b) => b.textContent === "Make the link").click(); true');
  ok(await waitFor('!!document.querySelector("#view-txn .link-url")', 20000), 'Make the link gives an address');
  await evaluate('(() => { const i = document.getElementById("link-from"); i.value = "Sam"; i.dispatchEvent(new Event("input")); return true; })()');
  ok(await evaluate('document.querySelector("label[for=link-from]").textContent === "Shared by" && document.querySelector("#view-txn .sp-end").textContent.includes("Shared by Sam.") && document.querySelector("#view-txn .sp-place").textContent === "The zoo"'), 'Shared by is the person, named as the page names them; Where is the place');
  const linkColor = await evaluate('getComputedStyle(document.querySelector("#view-txn .link-panel .sp")).backgroundColor');
  const linkHash = await evaluate('new URL(document.querySelector("#view-txn .link-url").href).hash');
  await cdp('Page.navigate', { url: SITE + 's/' + linkHash });
  ok(await waitFor('document.querySelector("#page blockquote")?.textContent.includes("penguins")', 20000), 'the address opens the page');
  ok(await evaluate('document.querySelector("#page mark").textContent === "we stayed until closing." && document.querySelector(".sp-place").textContent === "The zoo"'), 'with the words, the mark and the place they chose');
  ok(await evaluate('document.querySelector(\'meta[name=robots]\').content.includes("noindex") && !!document.querySelector(\'.sp-end a[href*="report"]\')'), 'unlisted, with a way to report it');
  ok(await evaluate('getComputedStyle(document.getElementById("page")).backgroundColor') === linkColor, 'in the color the writer saw');
  ok(await evaluate('document.documentElement.scrollWidth <= innerWidth'), 'and it fits a phone');
  await waitFor('document.fonts.check("600 20px Newsreader")');
  await shot('link-page');
  await openAs('owner', '#/settings');
  await evaluate('location.hash = "#/settings"; true');
  ok(await waitFor('!!document.querySelector("#view-settings .link-row button")'), 'Settings lists the link');
  await shot('link-settings');
  await evaluate('document.querySelector("#view-settings .link-row button").click(); true');
  ok(await waitFor('/Off/.test(document.querySelector("#view-settings .link-row").innerText)'), 'and turns it off');
  await cdp('Page.navigate', { url: SITE + 's/' + linkHash });
  ok(await waitFor('/This link was turned off/.test(document.body.innerText)', 20000), 'after which the address says so');
  // Only the part after the # changes, and the page reloads itself; a second reload here raced it.
  await cdp('Page.navigate', { url: SITE + 's/#nope' });
  ok(await waitFor('/no page at this address/.test(document.body.innerText)'), 'and a wrong address says that');
  await openAs('owner', '#/t/a3b8c10c-68b8-4bfe-9380-c87b7015a49d');
  await evaluate('location.hash = "#/t/a3b8c10c-68b8-4bfe-9380-c87b7015a49d"; true');
  await waitFor('!!document.getElementById("memo-body")');
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
  // D15: a place confirmed on the iPhone shows on the web's Setting and event pages.
  const os = await sessionFor('owner');
  const oh = { apikey: K, Authorization: 'Bearer ' + os.access_token, 'content-type': 'application/json' };
  try {
    await fetch(P + '/rest/v1/setting_places', { method: 'POST', headers: oh, body: JSON.stringify({ setting: 'Denver Zoo', name: 'Denver Zoo', address: '2300 Steele St, Denver', lat: 39.7496, lon: -104.9508 }) });
    // A fresh openAs to a deep route lands on Unexamined in this harness (as #/settings does
    // above); open the app, then go to the Setting the way a tap does.
    await openAs('owner', '#/ledger');
    await evaluate('location.hash = "#/setting/Denver%20Zoo"; true');
    const sawPlace = await waitFor('/Denver Zoo · 2300 Steele St, Denver/.test(document.querySelector("#view-setting [data-place]")?.innerText || "")');
    ok(sawPlace, 'the Setting page names the confirmed place' + (sawPlace ? '' : ' (saw: ' + String(await evaluate('location.hash + " | " + (document.querySelector("#view-setting")?.innerText || "").slice(0, 200)')).replace(/\n/g, ' / ') + ')'));
    ok(await evaluate('document.querySelector("#view-setting [data-place] a").href.startsWith("https://maps.apple.com/?ll=39.749600,-104.950800")'), 'and links to it in Apple Maps');
    await shot('setting-place');
    await evaluate('location.hash = "#/t/a3b8c10c-68b8-4bfe-9380-c87b7015a49d"; true');
    ok(await waitFor('/Denver Zoo · 2300 Steele St/.test(document.querySelector("#view-txn [data-place]")?.innerText || "")'), 'every visit there carries the place (event page)');
  } finally {
    await fetch(P + '/rest/v1/setting_places?setting=eq.Denver%20Zoo', { method: 'DELETE', headers: oh });
  }
  // Item 10: a photo copy the person kept shows on the web, from a private bucket.
  const uid = JSON.parse(Buffer.from(os.access_token.split('.')[1], 'base64url').toString()).sub;
  const jpeg = Buffer.from('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==', 'base64');
  let att;
  try {
    att = (await (await fetch(P + '/rest/v1/attachments?select=id', { method: 'POST', headers: { ...oh, prefer: 'return=representation' },
      body: JSON.stringify({ transaction_id: 'a3b8c10c-68b8-4bfe-9380-c87b7015a49d', kind: 'photo', device_ref: 'web-test' }) })).json())[0];
    const path = uid + '/' + att.id + '.jpg';
    await fetch(P + '/storage/v1/object/attachments/' + path, { method: 'POST', headers: { apikey: K, Authorization: 'Bearer ' + os.access_token, 'content-type': 'image/jpeg' }, body: jpeg });
    await fetch(P + '/rest/v1/attachments?id=eq.' + att.id, { method: 'PATCH', headers: oh, body: JSON.stringify({ storage_path: path }) });
    await openAs('owner', '#/ledger');
    await evaluate('location.hash = "#/t/a3b8c10c-68b8-4bfe-9380-c87b7015a49d"; true');
    ok(await waitFor('[...document.querySelectorAll("#view-txn [data-photo-copies] img")].some(i => i.complete && i.naturalWidth > 0 && /token=/.test(i.src))'), 'a kept photo copy shows on the web, through a signed link');
    // A file (kind file, caption its name) lists by name and links privately.
    await fetch(P + '/rest/v1/attachments?id=eq.' + att.id, { method: 'PATCH', headers: oh, body: JSON.stringify({ kind: 'file', caption: 'Receipt.jpg' }) });
    await openAs('owner', '#/ledger');
    await evaluate('location.hash = "#/t/a3b8c10c-68b8-4bfe-9380-c87b7015a49d"; true');
    ok(await waitFor('[...document.querySelectorAll("#view-txn [data-files] a")].some(a => a.textContent === "Receipt.jpg" && /token=/.test(a.href))'), 'a kept file lists by its name with a signed link');
  } finally {
    if (att) {
      await fetch(P + '/storage/v1/object/attachments', { method: 'DELETE', headers: { apikey: K, Authorization: 'Bearer ' + os.access_token, 'content-type': 'application/json' }, body: JSON.stringify({ prefixes: [uid + '/' + att.id + '.jpg'] }) });
      await fetch(P + '/rest/v1/attachments?id=eq.' + att.id, { method: 'DELETE', headers: oh });
    }
  }
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
    // D14: the starters are in Settings; Unexamined never asks (Ben, 2026-11-24).
    await evaluate('location.hash = "#/unexamined"; true');
    ok(await waitFor('document.querySelectorAll("#view-unexamined .list > *").length > 0'), 'Unexamined lists purchases');
    ok(await evaluate('!document.querySelector("#view-unexamined .starter, #view-unexamined [data-starter]") && !/sound like you/.test(document.getElementById("view-unexamined").innerText)'), 'and offers no starter themes');
    await evaluate('location.hash = "#/settings"; true');
    ok(await waitFor('document.querySelectorAll("#view-settings [data-starter]").length === 13'), 'Settings offers all 13 starter themes');
    await shot('settings-starters');
    await evaluate('document.querySelector(\'#view-settings [data-starter="Health"] button\').click(); true');
    ok(await waitFor('document.querySelectorAll("#view-settings [data-starter]").length === 12'), 'adding one takes it off the list');
    const kept = await (await fetch(P + '/rest/v1/life_values?select=name,color', { headers: hdr })).json();
    ok(Array.isArray(kept) && kept.length === 1 && kept[0].name === 'Health', 'and keeps exactly the added theme (Health)');
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
await openAs('owner', '#/');
await evaluate('API.shares = () => new Promise(() => {}); location.hash = "#/settings"; true');
ok(await waitFor('/Sign out/.test(document.querySelector("#view-settings").innerText) && /Loading/.test(document.getElementById("your-links")?.innerText || "")'), 'Settings draws even while the list of links never answers');
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
