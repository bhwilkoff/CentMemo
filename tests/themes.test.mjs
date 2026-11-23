import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const T = require('../js/money/themes.js');
const source = JSON.parse(readFileSync(new URL('./fixtures/starter-themes.json', import.meta.url)));

test('the starter list is the approved data, word for word', () => {
  assert.deepEqual(T.PALETTE, source.palette);
  assert.deepEqual(T.STARTERS, source.starters);
});

// Golden: the same inputs and answers live in apple/Tests/ThemesTests.swift.
export const GOLDEN_IN = [
  { name: 'Time with my kids', created_at: '2026-11-21T10:00:00Z' },
  { name: 'Great meals', created_at: '2026-11-21T10:01:00Z' },
  { name: 'Being outside', created_at: '2026-11-21T10:02:00Z' },
  { name: 'Clay pot', color: 'clay', created_at: '2026-11-22T09:00:00Z' },
  { name: 'Home', created_at: '2026-11-22T09:01:00Z' },
];
export const GOLDEN_OUT = { 'clay pot': 'clay', 'great meals': 'persimmon', 'time with my kids': 'ochre', 'being outside': 'olive', home: 'moss' };

test('every theme gets its own color by the rule', () => {
  assert.deepEqual(T.assignColors(GOLDEN_IN), GOLDEN_OUT);
});

test('no two of 13 themes share a color; the 14th repeats', () => {
  const many = Array.from({ length: 14 }, (_, i) => ({ name: 'T' + i, created_at: '2026-01-' + String(i + 10) }));
  const colors = Object.values(T.assignColors(many));
  assert.equal(new Set(colors.slice(0, 13)).size, 13);
  assert.equal(colors.length, 14);
});

test('a new theme stores a color nobody shows, so nothing shifts', () => {
  // Golden twin in ThemesTests.nextColor.
  assert.equal(T.nextColor(GOLDEN_IN.slice(0, 4), 'Home'), 'moss'); // clay chosen by Clay pot
  assert.equal(T.nextColor(GOLDEN_IN.slice(0, 3), 'Home'), 'olive'); // clay is shown by Time with my kids
  const before = T.assignColors(GOLDEN_IN.slice(0, 3));
  const after = T.assignColors([...GOLDEN_IN.slice(0, 3), { name: 'People I love', color: T.nextColor(GOLDEN_IN.slice(0, 3), 'People I love'), created_at: '2026-11-23' }]);
  for (const k of Object.keys(before)) assert.equal(after[k], before[k], k + ' kept its color');
});
