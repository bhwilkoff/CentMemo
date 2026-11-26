import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const M = require('../js/money/memo-text.js');
const { cases } = JSON.parse(readFileSync(new URL('./fixtures/memo-text.json', import.meta.url)));

test('memo text reads the shared cases as the Swift reader does', () => {
  for (const c of cases) assert.equal(M.plain(c.md), c.plain, c.md);
});

test('styles become escaped HTML, and nothing the person typed becomes markup', () => {
  assert.equal(M.html('We **went**, *all*\n- one\n- two\n> said'),
    '<p>We <strong>went</strong>, <em>all</em></p><ul class="memo-list"><li>one</li><li>two</li></ul><blockquote class="memo-quote">said</blockquote>');
  assert.equal(M.html('<img src=x onerror=alert(1)>'), '<p>&lt;img src=x onerror=alert(1)&gt;</p>');
  assert.equal(M.html('# Day'), '<p class="memo-heading"><strong>Day</strong></p>');
});
