// The Claude connector must never read FinanceKit rows until Apple permits
// it (FinanceKit APIs Addendum 3.2). Every data read in the MCP function
// must go through guarded()/txns(), and the switch must stay off.
// Run: node --test tests/*.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const src = readFileSync(new URL('../supabase/functions/mcp/index.ts', import.meta.url), 'utf8');

export function unguardedReads(code) {
  const bad = [];
  for (const m of code.matchAll(/supabase\.from\('(transactions|accounts|balances)'\)/g)) {
    const before = code.slice(Math.max(0, m.index - 30), m.index);
    if (!/guarded\($/.test(before)) bad.push(m[0]);
  }
  return bad;
}

test('FinanceKit sharing switch is off', () => {
  assert.match(src, /const SHARE_FINANCEKIT = false;/);
});

test('every transactions/accounts/balances read is guarded', () => {
  assert.deepEqual(unguardedReads(src), []);
});

test('spending_summary asks the database to exclude FinanceKit', () => {
  assert.match(src, /exclude_financekit: !SHARE_FINANCEKIT/);
});

test('negative control: an unguarded read is caught', () => {
  assert.deepEqual(unguardedReads("const r = await supabase.from('transactions').select('*');"), ["supabase.from('transactions')"]);
});
