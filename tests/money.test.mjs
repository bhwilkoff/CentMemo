// Golden tests for js/money/money.js. Run: node --test tests/*.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const M = createRequire(import.meta.url)('../js/money/money.js');
const fixture = readFileSync(new URL('./fixtures/applecard-sample.csv', import.meta.url), 'utf8');

test('toMinor parses money without floats', () => {
  assert.equal(M.toMinor('64.37'), 6437);
  assert.equal(M.toMinor('1,082.00'), 108200);
  assert.equal(M.toMinor('-500.00'), -50000);
  assert.equal(M.toMinor('0.07'), 7);
  assert.equal(M.toMinor('7'), 700);
  assert.equal(M.toMinor('0.1'), 10);
  assert.throws(() => M.toMinor('1.234'));
  assert.throws(() => M.toMinor('abc'));
});

test('formatMinor', () => {
  assert.equal(M.formatMinor(-108200, 'USD'), '-$1,082.00');
  assert.equal(M.formatMinor(7, 'USD'), '$0.07');
});

test('Apple Card export: signs, dates, status, golden totals', async () => {
  const rows = await M.parseAppleCardCsv(fixture);
  assert.equal(rows.length, 7);
  assert.deepEqual(rows.map(r => r.amount_minor), [-6437, -6437, -108200, 50000, -999, -4158, -7]);
  assert.equal(rows.reduce((a, r) => a + r.amount_minor, 0), -76238);
  assert.equal(rows[0].txn_date, '2026-11-18');
  assert.equal(rows[0].posted_date, '2026-11-19');
  assert.equal(rows[4].status, 'pending');
  assert.equal(rows[4].posted_date, null);
  assert.equal(rows[0].merchant, 'Blue Pan Pizza');
});

test('source_id is stable and separates identical same-day rows', async () => {
  const a = await M.parseAppleCardCsv(fixture);
  const b = await M.parseAppleCardCsv(fixture);
  assert.deepEqual(a.map(r => r.source_id), b.map(r => r.source_id));
  assert.equal(new Set(a.map(r => r.source_id)).size, 7);
  assert.match(a[0].source_id, /:0$/);
  assert.match(a[1].source_id, /:1$/);
  assert.equal(a[0].source_id.split(':')[1], a[1].source_id.split(':')[1]);
});

test('refuses a file that is not an Apple Card export', async () => {
  await assert.rejects(M.parseAppleCardCsv('Date,Amount\n1/1/2026,5'), /not an Apple Card export/);
});

test('store names: cleaned, initials, hue match the golden (D8; Swift reads the same file)', () => {
  const golden = JSON.parse(readFileSync(new URL('./fixtures/merchant-names.json', import.meta.url), 'utf8'));
  assert.ok(golden.length >= 12);
  for (const g of golden) {
    const name = M.cleanMerchant(g.raw);
    assert.equal(name, g.name, g.raw);
    assert.equal(M.merchantInitials(name), g.initials, g.raw);
    assert.equal(M.merchantHue(name, 6), g.hue, g.raw);
  }
});
