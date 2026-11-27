/* Draws the page a story link shows (DESIGN S7) from what the server publishes
 * (make_share, Decision 067). The same code draws the writer's live preview. Text is
 * only ever set as text, never as HTML. */
(function (root) {
  'use strict';
  const COLORS = { clay: ['#A33E25', '#FCA48D'], persimmon: ['#964D09', '#FEA668'], ochre: ['#815C0A', '#E9B452'], olive: ['#686800', '#C3C55A'], moss: ['#2F751D', '#90D281'], sage: ['#1B735B', '#54D8B1'], teal: ['#157171', '#2AD7D7'], sky: ['#006D91', '#60CCFC'], slate: ['#2F60B2', '#98BFFE'], iris: ['#6451AC', '#BCB3FA'], plum: ['#8A428E', '#E8A0EC'], rose: ['#9D3A67', '#FF99C2'], stone: ['#6F6964', '#B3ACA6'] };
  const wordsOf = (s) => String(s || '').trim().split(/\s+/).filter(Boolean);
  function el(tag, attrs, ...kids) {
    const e = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) if (v != null && v !== false) { if (k === 'class') e.className = v; else e.setAttribute(k, v === true ? '' : v); }
    e.append(...kids.flat().filter((x) => x != null && x !== false));
    return e;
  }
  const initials = (s) => wordsOf(s).slice(0, 2).map((w) => Array.from(w)[0]).join('').toUpperCase();
  function lineOf(memo, mark) {
    const w = wordsOf(memo);
    if (mark) return w.slice(mark[0], mark[1] + 1).join(' ');
    const end = w.findIndex((x) => /[.!?]$/.test(x));
    return (end < 0 ? w : w.slice(0, end + 1)).join(' ');
  }
  function quote(m) {
    const q = el('blockquote'), w = wordsOf(m.memo);
    if (!m.mark) { q.append(m.memo); return q; }
    const [a, b] = m.mark;
    q.append(w.slice(0, a).join(' ') + (a ? ' ' : ''), el('mark', {}, w.slice(a, b + 1).join(' ')), b < w.length - 1 ? ' ' + w.slice(b + 1).join(' ') : '');
    return q;
  }
  function where(m, big) {
    if (!m.place && !m.when) return null;
    return el('div', { class: 'sp-where' }, m.place ? el('span', { class: 'sp-tile', 'aria-hidden': 'true' }, initials(m.place)) : null,
      el('div', {}, m.place ? el('div', { class: big ? 'sp-big' : 'sp-place' }, m.place) : null, m.when ? el('div', { class: 'sp-date' }, m.when) : null));
  }
  /* The pencil: drawn over the marked words, line by line, the same every time. */
  function ink(page, kind) {
    page.querySelectorAll('svg.sp-ink').forEach((x) => x.remove());
    page.querySelectorAll('blockquote mark').forEach((mk) => {
      const q = mk.closest('blockquote'), base = q.getBoundingClientRect(), size = parseFloat(getComputedStyle(q).fontSize), NS = 'http://www.w3.org/2000/svg', svg = document.createElementNS(NS, 'svg');
      svg.setAttribute('class', 'sp-ink'); svg.setAttribute('aria-hidden', 'true');
      for (const r of mk.getClientRects()) {
        const x = r.left - base.left, y = r.top - base.top, w = r.width, h = r.height, t = Math.max(2.5, size * .07), u = y + h - size * .08;
        const add = (d, width, op) => { const p = document.createElementNS(NS, 'path'); p.setAttribute('d', d); p.setAttribute('stroke-width', width); if (op) p.style.opacity = op; svg.append(p); };
        const line = (yy) => `M${x - 3} ${yy + t * .4}C${x + w * .3} ${yy - t * 1.1} ${x + w * .62} ${yy + t * 1.5} ${x + w + 5} ${yy - t * .2}`;
        if (kind === 'double') { add(line(u - t * .6), t * .7); add(line(u + t * 1.3), t * .7); }
        else if (kind === 'highlight') { svg.classList.add('sp-hi'); add(`M${x - 3} ${y + h * .56}C${x + w * .3} ${y + h * .52} ${x + w * .7} ${y + h * .6} ${x + w + 3} ${y + h * .55}`, h * .72, .26); }
        else if (kind === 'circle') { const X = x - size * .24, Y = y - h * .02, W = w + size * .48, H = h * 1.06, p = (a, b) => `${X + a / 100 * W} ${Y + b / 60 * H}`; add(`M${p(58, 3)}C${p(20, 0)} ${p(1, 4)} ${p(1, 31)}C${p(1, 57)} ${p(22, 60)} ${p(58, 58)}C${p(90, 57)} ${p(100, 54)} ${p(99, 28)}C${p(98, 3)} ${p(80, 0)} ${p(42, 5)}`, Math.max(2, size * .05)); }
        else add(line(u), t);
      }
      q.prepend(svg);
    });
  }
  /* p: { kind, theme: {name, color}?, from?, items: [{memo?, place?, when?, mark?}], design, pictures?: count, looks?: ['plate'|'mounted'|'whole'] }
     opts.pictures: the pictures' addresses (the published copies, or the writer's preview). */
  function render(page, p, opts) {
    const d = p.design || {}, [c, n] = COLORS[d.color] || COLORS.clay, name = p.theme && p.theme.name;
    page.className = 'sp' + (d.paper === 'night' ? ' night' : d.paper === 'paper' ? '' : ' bold');
    page.style.setProperty('--sp-theme', c); page.style.setProperty('--sp-theme-night', n);
    page.replaceChildren();
    const end = el('footer', { class: 'sp-end' }, el('b', {}, 'CentMemo'), el('span', {}, (p.from ? 'Shared by ' + p.from + '. ' : '') + 'This page isn’t listed anywhere. ', opts && opts.report ? el('a', { href: opts.report }, 'Report it') : null));
    if (p.kind === 'theme') {
      const places = [...new Set(p.items.map((m) => m.place).filter(Boolean))];
      if (d.cover) page.append(el('header', { class: 'sp-cover' }, el('div', { class: 'sp-gut' }, el('h1', {}, name || ''), places.length ? el('p', {}, places.join(', ')) : null, el('p', { class: 'sp-count' }, p.items.length === 1 ? '1 memo' : p.items.length + ' memos'))));
      const g = el('div', { class: 'sp-gut' });
      if (!d.cover && name) g.append(el('p', { class: 'sp-big', style: 'max-width:820px;margin:0 auto;padding-top:clamp(36px,8cqi,80px)' }, name));
      if (d.lines) g.append(el('ol', { class: 'sp-poem' }, p.items.map((m, i) => el('li', {}, d.mems ? el('a', { href: '#m' + i, 'data-to': i }, lineOf(m.memo, m.mark)) : lineOf(m.memo, m.mark)))));
      if (d.mems) g.append(el('div', { class: 'sp-mems' }, p.items.map((m, i) => el('article', { class: 'sp-mem', 'data-mem': i }, quote(m), where(m)))));
      g.append(end); page.append(g);
      // The address holds the link's code, so a jump scrolls instead of changing it.
      page.querySelectorAll('[data-to]').forEach((a) => a.addEventListener('click', (e) => { e.preventDefault(); page.querySelector(`[data-mem="${a.dataset.to}"]`).scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' }); }));
    } else {
      const m = p.items[0], tag = name ? el('span', { class: 'sp-tag' }, el('i'), name) : null;
      // W7: the pictures the writer chose, first, each in its own shape.
      const pics = ((opts && opts.pictures) || []).slice(0, 3);
      // W8: each keeps its look from the memo: a paper mat, a drawing whole, or a plate.
      const looks = p.looks || [];
      const band = pics.length ? el('div', { class: 'sp-pics sp-pics-' + pics.length }, pics.map((u, i) => el('figure', { class: 'sp-pic sp-' + (['mounted', 'whole'].includes(looks[i]) ? looks[i] : 'plate') }, el('img', { src: u, alt: 'A picture from this memo', loading: 'lazy' })))) : null;
      const parts = d.lead === 'setting' ? [band, where(m, true), quote(m), tag] : d.lead === 'theme' ? [name ? el('p', { class: 'sp-big' }, name) : null, band, quote(m), where(m)] : [band, quote(m), where(m), tag];
      page.append(el('div', { class: 'sp-gut' }, el('article', { class: 'sp-memo' }, parts.filter(Boolean)), end));
      page.querySelectorAll('.sp-pics img').forEach((i) => i.addEventListener('error', () => i.parentNode.remove()));
    }
    const again = () => ink(page, d.pencil);
    requestAnimationFrame(again);
    if (document.fonts) document.fonts.ready.then(again);
    if (!page._ro && root.ResizeObserver) { page._ro = new ResizeObserver(() => requestAnimationFrame(() => page._ink && page._ink())); page._ro.observe(page); }
    page._ink = again;
  }
  const api = { render, COLORS, lineOf };
  root.CentStory = api;
  if (typeof module !== 'undefined') module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
