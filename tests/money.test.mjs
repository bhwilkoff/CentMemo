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

const fx = (f) => readFileSync(new URL('./fixtures/' + f, import.meta.url), 'utf8');
test('detectExport names each source by its header, and refuses others', () => {
  assert.equal(M.detectExport(fixture), 'applecard');
  assert.equal(M.detectExport(fx('venmo-sample.csv')), 'venmo');
  assert.equal(M.detectExport(fx('paypal-sample.csv')), 'paypal');
  assert.equal(M.detectExport(fx('cashapp-sample.csv')), 'cashapp');
  assert.equal(M.detectExport('Name,Amount\nCoffee,3.00\n'), null);
});
test('Venmo: skips title, balance, and disclaimer rows; keeps notes; signs money out', () => {
  const r = M.parseVenmoCsv(fx('venmo-sample.csv'));
  assert.deepEqual(r.map((x) => [x.source_id, x.txn_date, x.amount_minor, x.merchant, x.description]), [
    ['venmo:3912345678901234567', '2026-11-03', -1850, 'Alex Rivera', 'Pizza night 🍕, my half'],
    ['venmo:3912345678901234568', '2026-11-05', 4000, 'Jordan Lee', 'Concert tickets'],
    ['venmo:3912345678901234569', '2026-11-09', -102150, '', ''],
  ]);
});
test('PayPal: maps by header, drops Memo (hold) rows, keeps the note', () => {
  const r = M.parsePayPalCsv(fx('paypal-sample.csv'));
  assert.deepEqual(r.map((x) => [x.source_id, x.txn_date, x.amount_minor, x.merchant, x.description]), [
    ['paypal:8AB12345CD678901E', '2026-11-02', -2399, 'Riverside Bookshop', 'Used poetry book'],
    ['paypal:9XY12345CD678901F', '2026-11-02', 2399, '', ''],
    ['paypal:1ZZ12345CD678901G', '2026-11-04', -125000, 'Sam Okafor', 'November rent, thank you!'],
  ]);
});
test('Cash App: drops FAILED; a card purchase has the store as merchant and no note', () => {
  const r = M.parseCashAppCsv(fx('cashapp-sample.csv'));
  assert.deepEqual(r.map((x) => [x.source_id, x.amount_minor, x.merchant, x.description]), [
    ['cashapp:rmgsrz', -290, 'MTA*NYCT PAYGO', ''],
    ['cashapp:7jdb8q', -1500, 'Dana Park', 'Lunch with Dana'],
    ['cashapp:4pp9tt', 100000, 'Mom', 'Birthday gift 🎂'],
  ]);
});
test('looseMinor reads every sign style the three apps use', () => {
  for (const [t, v] of [['- $65.00', -6500], ['+ $10.00', 1000], ['-$2.90', -290], ['($2.90)', -290], ['$1', 100], ['-6.99', -699], ['"1,234.50"'.replace(/"/g, ''), 123450]]) assert.equal(M.looseMinor(t), v, t);
});
