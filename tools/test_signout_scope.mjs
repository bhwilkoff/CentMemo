// Signing out ends this device's sign-in and no other (found 2026-11-24: the
// server's default is every device). Two sessions of the synthetic stranger, and
// the sources must ask for scope=local. The default scope is the control.
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
let failures = 0;
const ok = (c, m) => { console.log((c ? '  ok   ' : '  FAIL ') + m); if (!c) failures++; };
ok(/auth\.signOut\(\{ scope: 'local' \}\)/.test(readFileSync('js/api.js', 'utf8')) && !/auth\.signOut\(\)/.test(readFileSync('js/api.js', 'utf8')), 'the web signs out this browser only');
ok(/auth\/v1\/logout", query: \[\.init\(name: "scope", value: "local"\)\]/.test(readFileSync('apple/Core/Networking/APIClient.swift', 'utf8')), 'the Apple apps sign out this device only');
const src = readFileSync('tools/cleanup_stranger.mjs', 'utf8');
const base = src.match(/https:[^']+/)[0], pub = src.match(/sb_publishable_[^']+/)[0];
const { stranger } = JSON.parse(readFileSync(homedir() + '/.centmemo/test-users.json', 'utf8'));
const post = (p, body, t) => fetch(base + p, { method: 'POST', headers: { apikey: pub, 'content-type': 'application/json', ...(t ? { Authorization: 'Bearer ' + t } : {}) }, body: JSON.stringify(body) });
const signIn = async () => (await post('/auth/v1/token?grant_type=password', stranger)).json();
const refresh = async (s) => (await post('/auth/v1/token?grant_type=refresh_token', { refresh_token: s.refresh_token })).status;
for (const [q, other] of [['?scope=local', 200], ['', 400]]) {
  const a = await signIn(), b = await signIn();
  await post('/auth/v1/logout' + q, {}, a.access_token);
  ok(await refresh(a) === 400, `${q || 'default'}: the device that signed out is out`);
  ok(await refresh(b) === other, `${q || 'default (control)'}: the other device ${other === 200 ? 'stays in' : 'is signed out too'}`);
}
console.log(failures ? `FAIL: ${failures} check(s)` : 'PASS');
process.exit(failures ? 1 : 0);
