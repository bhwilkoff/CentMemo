// Every ground a person can choose (Decision 059) must (1) pass every text
// pair at WCAG AA in both modes with the brand tokens, and (2) match across
// design-tokens.json, css/styles.css, and apple/Core/Ground.swift.
// Run: node tools/test_grounds.mjs
import { readFileSync } from 'node:fs';
import { contrast } from './design_tokens.mjs';

const root = new URL('..', import.meta.url);
const read = (p) => readFileSync(new URL(p, root), 'utf8');

export function checkGrounds(tokens, css, swift) {
  // The person's color is a mark, never a ground (docs/DESIGN.md C3-C5):
  // ink text on it at 4.5:1, and visible against the dark page at 3:1.
  const fails = [];
  const b = tokens.color.brand, ink = b.text.light;
  for (const [id, g] of Object.entries(tokens.grounds)) {
    if (id.startsWith('$')) continue;
    const onIt = contrast(ink, g.hex);
    if (onIt < 4.5) fails.push(`${id}: ink on it ${onIt.toFixed(2)} < 4.5`);
    const onDark = contrast(g.hex, b.background.dark);
    if (onDark < 3) fails.push(`${id}: against the dark page ${onDark.toFixed(2)} < 3`);
    const hx = g.hex.replace('#', '').toUpperCase();
    if (!swift.toUpperCase().includes('0X' + hx)) fails.push(`${id}: ${g.hex} missing from Ground.swift`);
    if (g.default) {
      if (!new RegExp(`--color-yours:\\s*${g.hex}`, 'i').test(css)) fails.push(`${id}: default ${g.hex} is not --color-yours in styles.css`);
    } else if (!new RegExp(`data-ground="${id}"\\]\\s*\\{\\s*--color-yours:\\s*${g.hex}`, 'i').test(css)) {
      fails.push(`${id}: ${g.hex} missing from styles.css`);
    }
  }
  // C1: no ground may be the page background.
  const grounds = Object.entries(tokens.grounds).filter(([k]) => !k.startsWith('$')).map(([, g]) => g.hex.toUpperCase());
  for (const mode of ['light', 'dark']) if (grounds.includes(b.background[mode].toUpperCase())) fails.push(`page background (${mode}) is a ground: DESIGN C1`);
  if (/data-ground="[a-z]+"\]\s*\{[^}]*--color-background/i.test(css)) fails.push('styles.css sets --color-background from a ground: DESIGN C1');
  return fails;
}

const tokens = JSON.parse(read('design-tokens.json'));
const css = read('css/styles.css'), swift = read('apple/Core/Ground.swift');
const fails = checkGrounds(tokens, css, swift);
for (const f of fails) console.log('  FAIL ' + f);

// Negative control: a planted drift must be caught.
const planted = structuredClone(tokens);
planted.grounds.sky.hex = '#123456';
const caught = checkGrounds(planted, css, swift).length > 0;
console.log(caught ? '  ok   control: a drifted ground is caught' : '  FAIL control: drift went unnoticed');

const n = Object.keys(tokens.grounds).filter((k) => !k.startsWith('$')).length;
if (fails.length || !caught) { console.log(`FAIL: ${fails.length} ground check(s)`); process.exit(1); }
console.log(`PASS: ${n} colors: ink reads on each, each shows on the dark page, none is a page background, web and Apple match`);
