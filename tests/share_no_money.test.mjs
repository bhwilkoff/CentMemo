// Ben, 2026-11-24: "No amount of money should ever be shared."
// Every share surface's source names no amount; a planted one is caught.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const MONEY = /amount_?minor|money\s*\(|(?<!Cent)Money\.(?!merchantInitials)|CentMoney\.(format|parse)|MoneyText|showAmount|share-(theme-)?amount/i;
const strip = (s) => s.replace(/\/\/.*$/gm, '');
function webPanel(name) {
  const src = readFileSync('js/app.js', 'utf8');
  const start = src.indexOf('function ' + name + '(');
  assert.ok(start > 0, name + ' exists');
  return src.slice(start, src.indexOf('\n  }\n', start));
}
const surfaces = {
  'web memo card': webPanel('sharePanel'),
  'the card itself': readFileSync('js/money/share-card.js', 'utf8'),
  'web theme card': webPanel('shareThemePanel'),
  'Apple memo card': readFileSync('apple/iOS/Components/ShareMemo.swift', 'utf8'),
  'the Apple card itself': readFileSync('apple/Core/ShareCard.swift', 'utf8'),
  'Apple theme card': readFileSync('apple/iOS/Components/ShareTheme.swift', 'utf8'),
};
for (const [name, src] of Object.entries(surfaces)) {
  test(name + ' shares no amount', () => assert.doesNotMatch(strip(src), MONEY));
}
test('negative control: a planted amount is caught', () => {
  for (const bad of ['money(-t.amount_minor)', 'Money.format(-entry.amountMinor)', '@State var showAmount']) assert.match(bad, MONEY);
});

// The card draws off the page, so it carries its own theme colors: the tokens', exactly.
test('the share card uses the theme tokens', () => {
  const css = readFileSync('css/styles.css', 'utf8'), app = readFileSync('js/app.js', 'utf8');
  const hex = app.slice(app.indexOf('const THEME_HEX'), app.indexOf('};', app.indexOf('const THEME_HEX')));
  const seen = {};
  for (const [, k, v] of css.matchAll(/--color-theme-(\w+): (#[0-9A-F]{6})/g)) (seen[k] ||= []).push(v);
  const keys = Object.keys(seen);
  assert.equal(keys.length, 13);
  for (const k of keys) assert.ok(hex.includes(`${k}: ['${seen[k][0]}', '${seen[k][1]}']`), k + ' ' + seen[k].slice(0, 2));
});
