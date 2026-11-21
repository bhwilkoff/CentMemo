// Every ground a person can choose (Decision 059) must (1) pass every text
// pair at WCAG AA in both modes with the brand tokens, and (2) match across
// design-tokens.json, css/styles.css, and apple/Core/Ground.swift.
// Run: node tools/test_grounds.mjs
import { readFileSync } from 'node:fs';
import { contrast } from './design_tokens.mjs';

const root = new URL('..', import.meta.url);
const read = (p) => readFileSync(new URL(p, root), 'utf8');

export function checkGrounds(tokens, css, swift) {
  const fails = [];
  const b = tokens.color.brand, s = tokens.color.semantic;
  for (const [id, g] of Object.entries(tokens.grounds)) {
    if (id.startsWith('$')) continue;
    const modes = { light: { bg: g.light, paper: b.surface.light }, dark: { bg: g.dark, paper: g.darkSurface } };
    for (const [mode, { bg, paper }] of Object.entries(modes)) {
      for (const [name, fg, on, min] of [
        ['text', b.text[mode], bg, 4.5], ['textMuted', b.textMuted[mode], bg, 4.5],
        ['text on paper', b.text[mode], paper, 4.5], ['textMuted on paper', b.textMuted[mode], paper, 4.5],
        ['success', s.success[mode], bg, 4.5], ['error', s.error[mode], bg, 4.5], ['warning', s.warning[mode], bg, 4.5],
        ['primary', b.primary[mode], bg, 3],
      ]) {
        const r = contrast(fg, on);
        if (r < min) fails.push(`${id} ${mode}: ${name} ${r.toFixed(2)} < ${min}`);
      }
    }
    const hx = (h) => h.replace('#', '').toUpperCase();
    for (const h of [g.light, g.dark, g.darkSurface]) {
      if (!swift.toUpperCase().includes('0X' + hx(h))) fails.push(`${id}: ${h} missing from Ground.swift`);
    }
    if (!g.default) {
      const lightRule = new RegExp(`data-ground="${id}"\\]\\s*\\{\\s*--color-background:\\s*${g.light}`, 'i');
      if (!lightRule.test(css)) fails.push(`${id}: light ${g.light} missing from styles.css`);
      const darkCount = (css.match(new RegExp(`data-ground="${id}"\\]\\s*\\{\\s*--color-background:\\s*${g.dark};\\s*--color-surface:\\s*${g.darkSurface}`, 'gi')) || []).length;
      if (darkCount < 2) fails.push(`${id}: dark ${g.dark}/${g.darkSurface} not in both dark blocks of styles.css`);
    } else if (g.light.toUpperCase() !== tokens.color.brand.background.light.toUpperCase()) {
      fails.push(`${id}: default ground must equal brand.background`);
    }
  }
  return fails;
}

const tokens = JSON.parse(read('design-tokens.json'));
const css = read('css/styles.css'), swift = read('apple/Core/Ground.swift');
const fails = checkGrounds(tokens, css, swift);
for (const f of fails) console.log('  FAIL ' + f);

// Negative control: a planted drift must be caught.
const planted = structuredClone(tokens);
planted.grounds.sky.light = '#123456';
const caught = checkGrounds(planted, css, swift).length > 0;
console.log(caught ? '  ok   control: a drifted ground is caught' : '  FAIL control: drift went unnoticed');

const n = Object.keys(tokens.grounds).filter((k) => !k.startsWith('$')).length;
if (fails.length || !caught) { console.log(`FAIL: ${fails.length} ground check(s)`); process.exit(1); }
console.log(`PASS: ${n} grounds hold AA in light and dark, and match on web and Apple`);
