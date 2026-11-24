// Ben, 2026-11-24: "No amount of money should ever be shared."
// Every share surface's source names no amount; a planted one is caught.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const MONEY = /amount_?minor|money\s*\(|Money\.|MoneyText|showAmount|share-(theme-)?amount/i;
const strip = (s) => s.replace(/\/\/.*$/gm, '');
function webPanel(name) {
  const src = readFileSync('js/app.js', 'utf8');
  const start = src.indexOf('function ' + name + '(');
  assert.ok(start > 0, name + ' exists');
  return src.slice(start, src.indexOf('\n  }\n', start));
}
const surfaces = {
  'web memo card': webPanel('sharePanel'),
  'web theme card': webPanel('shareThemePanel'),
  'Apple memo card': readFileSync('apple/iOS/Components/ShareMemo.swift', 'utf8'),
  'Apple theme card': readFileSync('apple/iOS/Components/ShareTheme.swift', 'utf8'),
};
for (const [name, src] of Object.entries(surfaces)) {
  test(name + ' shares no amount', () => assert.doesNotMatch(strip(src), MONEY));
}
test('negative control: a planted amount is caught', () => {
  for (const bad of ['money(-t.amount_minor)', 'Money.format(-entry.amountMinor)', '@State var showAmount']) assert.match(bad, MONEY);
});
