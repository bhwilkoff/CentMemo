/**
 * CentThemes (D14): the starter themes Ben approved (tests/fixtures/
 * starter-themes.json is the source; tests/themes.test.mjs holds this copy to
 * it) and the rule that gives each theme its own color. Same rule in Swift
 * (apple/Core/Models/Themes.swift), golden-tested on both.
 */
(function (root) {
  'use strict';

  const PALETTE = ['clay', 'persimmon', 'ochre', 'olive', 'moss', 'sage', 'teal', 'sky', 'slate', 'iris', 'plum', 'rose', 'stone'];
  const STARTERS = [
    { name: 'People I love', meaning: 'Time and care for family and friends.', color: 'rose' },
    { name: 'Great meals', meaning: 'Food worth remembering, alone or shared.', color: 'persimmon' },
    { name: 'Home', meaning: 'The place I live and the comfort in it.', color: 'clay' },
    { name: 'Health', meaning: 'My body, rest, movement, and care.', color: 'moss' },
    { name: 'Learning', meaning: 'Books, classes, tools that grow a skill.', color: 'slate' },
    { name: 'Making', meaning: 'Materials and tools for things I create.', color: 'ochre' },
    { name: 'Adventure', meaning: 'Trips, firsts, and getting out of routine.', color: 'sky' },
    { name: 'Joy', meaning: 'Small treats and beautiful things that make a day better.', color: 'plum' },
    { name: 'Generosity', meaning: 'Gifts, tips, and giving to causes.', color: 'iris' },
    { name: 'Time back', meaning: 'Paying so I can spend time on what matters.', color: 'teal' },
    { name: 'Work I care about', meaning: 'Tools and costs of my work or craft.', color: 'olive' },
    { name: 'Community', meaning: 'Local places, events, and belonging.', color: 'sage' },
    { name: 'Taking care of things', meaning: 'The steady costs that keep life running.', color: 'stone' },
  ];
  const key = (name) => String(name || '').trim().toLowerCase();

  // themes: [{ name, color?, created_at? }]. Returns { lowercased name: color }.
  // 1. A color the person chose stays. 2. A starter theme's name takes the
  // starter's color. 3. Everything else, oldest first, takes the first palette
  // color no theme holds yet. Past 13 themes, colors repeat in palette order.
  function assignColors(themes) {
    const list = [...themes].sort((a, b) => String(a.created_at || '').localeCompare(String(b.created_at || '')) || key(a.name).localeCompare(key(b.name)));
    const out = {};
    const used = new Set();
    const take = (t, c) => { out[key(t.name)] = c; used.add(c); };
    for (const t of list) if (t.color && PALETTE.includes(t.color) && !(key(t.name) in out)) take(t, t.color);
    for (const t of list) {
      if (key(t.name) in out) continue;
      const s = STARTERS.find((x) => key(x.name) === key(t.name));
      if (s && !used.has(s.color)) take(t, s.color);
    }
    let spill = 0;
    for (const t of list) {
      if (key(t.name) in out) continue;
      const free = PALETTE.find((c) => !used.has(c));
      take(t, free || PALETTE[spill++ % PALETTE.length]);
    }
    return out;
  }

  const api = { PALETTE, STARTERS, assignColors };
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.CentThemes = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
