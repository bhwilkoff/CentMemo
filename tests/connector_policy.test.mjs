// One switch, every promise (Decision 066): the server's SHARE_FINANCEKIT, the
// iPhone's ConnectorPolicy.sharesWallet, and every page that tells people
// whether Claude sees Apple Wallet data must agree. Turning sharing on is one
// commit that flips both switches and rewrites these promises together.
// Run: node --test tests/*.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (p) => readFileSync(new URL('../' + p, import.meta.url), 'utf8');

export function serverShares(src) {
  const m = src.match(/const SHARE_FINANCEKIT = (true|false);/);
  if (!m) throw new Error('SHARE_FINANCEKIT not found');
  return m[1] === 'true';
}
export function appShares(src) {
  const m = src.match(/static let sharesWallet = (true|false)/);
  if (!m) throw new Error('sharesWallet not found');
  return m[1] === 'true';
}
// Pages that promise Wallet data stays away from Claude, and the words that promise it.
export const PROMISES = [
  ['connect/index.html', /never shared with Claude/],
  ['support/index.html', /never sees Apple Wallet/],
  ['docs/store/REVIEW-NOTES.md', /never includes Apple Wallet/],
];
export function contradictions(shares, files) {
  return PROMISES.filter(([p, rx]) => rx.test(files[p]) === shares).map(([p]) => p);
}

const files = Object.fromEntries(PROMISES.map(([p]) => [p, read(p)]));
const server = serverShares(read('supabase/functions/mcp/index.ts'));
const app = appShares(read('apple/Core/Finance/ConnectorPolicy.swift'));

test('the server and the iPhone agree on sharing Wallet data', () => {
  assert.equal(app, server);
});

test('every page tells the truth about the switch', () => {
  assert.deepEqual(contradictions(server, files), []);
});

test('negative control: a page that still promises "never" after the switch flips is caught', () => {
  assert.deepEqual(contradictions(true, files), PROMISES.map(([p]) => p));
});
