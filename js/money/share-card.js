/* The share card (DESIGN S): one memo as an image the person designs. Draws to a
 * canvas from the memo, its Setting, its date and its themes. It is never given an
 * amount, so it can never show one (Ben, 2026-11-24). The Apple twin is ShareCard.swift. */
(function (root) {
  'use strict';
  const LOOKS = ['page', 'setting', 'theme', 'words'];
  const SHAPES = { square: [1080, 1080], tall: [1080, 1920], wide: [1200, 630] };
  const PAPERS = ['paper', 'night', 'theme'];
  const PENCILS = ['underline', 'double', 'circle', 'highlight'];
  const SERIF = 'Newsreader, "New York", Georgia, serif';
  const SANS = '-apple-system, "Helvetica Neue", Arial, sans-serif';

  function inks(paper, theme) {
    if (paper === 'night') return { bg: '#171615', ink: '#F3EEE9', muted: '#B3ACA6', pencil: '#F0B9BE', mark: theme ? theme.dark : '#F0B9BE' };
    if (paper === 'theme') return { bg: theme ? theme.color : '#4A1520', ink: '#FBFAF7', muted: 'rgba(251,250,247,.82)', pencil: '#FBFAF7', mark: '#FBFAF7' };
    return { bg: '#FBFAF7', ink: '#231B1C', muted: '#5F5454', pencil: '#4A1520', mark: theme ? theme.color : '#4A1520' };
  }
  const wordsOf = (s) => String(s || '').trim().split(/\s+/).filter(Boolean);

  // Greedy lines: [{ words: [index, ...], width }]
  function lines(ctx, words, font, maxW) {
    ctx.font = font;
    const space = ctx.measureText(' ').width, out = [];
    let cur = { words: [], width: 0 };
    words.forEach((w, i) => {
      const ww = ctx.measureText(w).width;
      if (cur.words.length && cur.width + space + ww > maxW) { out.push(cur); cur = { words: [], width: 0 }; }
      cur.width += (cur.words.length ? space : 0) + ww; cur.words.push(i);
    });
    if (cur.words.length) out.push(cur);
    return out;
  }
  // The largest size whose lines fit the box.
  function fit(ctx, words, make, box, sizes) {
    for (const s of sizes) {
      const L = lines(ctx, words, make(s), box.w);
      if (L.length * s * 1.28 <= box.h && L.every((l) => l.width <= box.w)) return { size: s, lines: L };
    }
    const s = sizes[sizes.length - 1], room = Math.max(1, Math.floor(box.h / (s * 1.28)));
    return { size: s, lines: lines(ctx, words, make(s), box.w).slice(0, room), cut: true };
  }
  // One hand-drawn stroke, the same every time for the same place (no randomness).
  function stroke(ctx, x, y, w, color, thick) {
    ctx.save(); ctx.strokeStyle = color; ctx.lineWidth = thick; ctx.lineCap = 'round'; ctx.globalAlpha = .85;
    ctx.beginPath(); ctx.moveTo(x - 4, y + thick * .4);
    ctx.bezierCurveTo(x + w * .3, y - thick * 1.1, x + w * .62, y + thick * 1.5, x + w + 6, y - thick * .2);
    ctx.stroke(); ctx.restore();
  }
  function loop(ctx, x, y, w, h, color, thick) {
    ctx.save(); ctx.strokeStyle = color; ctx.lineWidth = thick; ctx.lineCap = 'round'; ctx.globalAlpha = .85;
    const p = (a, b) => [x + a / 100 * w, y + b / 60 * h];
    ctx.beginPath(); ctx.moveTo(...p(58, 4));
    ctx.bezierCurveTo(...p(26, 2), ...p(4, 14), ...p(5, 31)); ctx.bezierCurveTo(...p(6, 49), ...p(34, 57), ...p(58, 55));
    ctx.bezierCurveTo(...p(84, 53), ...p(97, 42), ...p(95, 27)); ctx.bezierCurveTo(...p(93, 12), ...p(72, 3), ...p(44, 6));
    ctx.stroke(); ctx.restore();
  }
  // The pencil the person chose, over one line's marked words. The highlighter goes
  // under the words; on a color page it darkens, so the words keep their contrast.
  function pencilUnder(ctx, x, base, w, size, m) {
    if (m.kind !== 'highlight') return;
    ctx.save(); ctx.fillStyle = m.onColor ? '#000000' : m.color; ctx.globalAlpha = m.onColor ? .24 : .28;
    ctx.beginPath(); ctx.moveTo(x - size * .06, base - size * .62); ctx.bezierCurveTo(x + w * .3, base - size * .68, x + w * .7, base - size * .58, x + w + size * .08, base - size * .66);
    ctx.lineTo(x + w + size * .04, base + size * .14); ctx.bezierCurveTo(x + w * .7, base + size * .2, x + w * .3, base + size * .1, x - size * .04, base + size * .17);
    ctx.closePath(); ctx.fill(); ctx.restore();
  }
  function pencilOver(ctx, x, base, w, size, m) {
    const t = Math.max(3, size * .07);
    if (m.kind === 'highlight') return;
    if (m.kind === 'circle') ring(ctx, x - size * .24, base - size * .92, w + size * .48, size * 1.28, m.color, Math.max(3, size * .05));
    else if (m.kind === 'double') { stroke(ctx, x, base + size * .13, w, m.color, t * .7); stroke(ctx, x, base + size * .25, w, m.color, t * .7); }
    else stroke(ctx, x, base + size * .16, w, m.color, t);
  }
  // Around words: squarer than the date's loop, so it clears the first and last letters.
  function ring(ctx, x, y, w, h, color, thick) {
    ctx.save(); ctx.strokeStyle = color; ctx.lineWidth = thick; ctx.lineCap = 'round'; ctx.globalAlpha = .85;
    const p = (a, b) => [x + a / 100 * w, y + b / 60 * h];
    ctx.beginPath(); ctx.moveTo(...p(58, 3));
    ctx.bezierCurveTo(...p(20, 0), ...p(1, 4), ...p(1, 31)); ctx.bezierCurveTo(...p(1, 57), ...p(22, 60), ...p(58, 58));
    ctx.bezierCurveTo(...p(90, 57), ...p(100, 54), ...p(99, 28)); ctx.bezierCurveTo(...p(98, 3), ...p(80, 0), ...p(42, 5));
    ctx.stroke(); ctx.restore();
  }
  function block(ctx, words, f, make, x, y, ink, mark) {
    ctx.font = make(f.size); ctx.textBaseline = 'alphabetic'; ctx.textAlign = 'left';
    const space = ctx.measureText(' ').width, lh = f.size * 1.28;
    let last = y;
    f.lines.forEach((l, n) => {
      let cx = x; const base = y + f.size + n * lh; last = base;
      let from = null, to = null;
      const at = l.words.map((i, k) => {
        let t = words[i];
        if (f.cut && n === f.lines.length - 1 && k === l.words.length - 1) t += '…';
        const w = ctx.measureText(t).width, place = [t, cx];
        if (mark && i >= mark.from && i <= mark.to) { if (from == null) from = cx; to = cx + w; }
        cx += w + space;
        return place;
      });
      if (from != null) pencilUnder(ctx, from, base, to - from, f.size, mark);
      ctx.fillStyle = ink;
      for (const [t, px] of at) ctx.fillText(t, px, base);
      if (from != null) pencilOver(ctx, from, base, to - from, f.size, mark);
    });
    return last + f.size * .3;
  }
  function footer(ctx, W, H, M, d, c, k) {
    const s = Math.round(W * .026); let x = M; const y = H - M;
    ctx.textBaseline = 'alphabetic';
    ctx.font = `600 ${Math.round(s * 1.05)}px ${SERIF}`; ctx.fillStyle = k.pencil; ctx.textAlign = 'right'; ctx.fillText('CentMemo', W - M, y);
    const room = W - M * 2 - ctx.measureText('CentMemo').width - s * 1.5;
    ctx.textAlign = 'left'; ctx.font = `400 ${s}px ${SANS}`; ctx.fillStyle = k.muted;
    const where = [c.showSetting && c.look !== 'setting' ? d.setting : null, c.showDate && c.look !== 'setting' ? d.date : null].filter(Boolean).join(' · ');
    if (where) ctx.fillText(clip(ctx, where, room), x, y);
    if (c.showThemes && d.themes.length && c.look !== 'theme') {
      const ty = y - (where ? s * 1.7 : 0); let tx = M;
      for (const t of d.themes.slice(0, 2)) {
        const w = s * 1.1 + ctx.measureText(t.name).width + s * 1.3;
        if (tx + w > W - M) break;
        ctx.fillStyle = c.paper === 'theme' ? k.ink : c.paper === 'night' ? t.dark : t.color;
        pill(ctx, tx, ty - s * .5, s * .85, s * .28);
        ctx.fillStyle = k.muted; ctx.fillText(t.name, tx + s * 1.1, ty); tx += w;
      }
    }
    return H - M - s * 3.6;
  }
  function pill(ctx, x, y, w, h) { ctx.beginPath(); ctx.moveTo(x + h / 2, y); ctx.lineTo(x + w - h / 2, y); ctx.arc(x + w - h / 2, y + h / 2, h / 2, -Math.PI / 2, Math.PI / 2); ctx.lineTo(x + h / 2, y + h); ctx.arc(x + h / 2, y + h / 2, h / 2, Math.PI / 2, -Math.PI / 2); ctx.fill(); }
  function clip(ctx, s, w) { if (ctx.measureText(s).width <= w) return s; while (s.length > 1 && ctx.measureText(s + '…').width > w) s = s.slice(0, -1); return s + '…'; }
  const range = (a, b, step) => { const o = []; for (let v = a; v >= b; v -= step) o.push(v); return o; };

  /* d: { memo, setting, initials, date, themes: [{ name, color, dark }] }
   * c: { look, shape, paper, showSetting, showDate, showThemes, pencil, mark: [from, to] | null } */
  function draw(canvas, d, c) {
    const [W, H] = SHAPES[c.shape] || SHAPES.square;
    canvas.width = W; canvas.height = H;
    const ctx = canvas.getContext('2d'), theme = d.themes[0] || null, k = inks(c.paper, theme);
    const M = Math.round(Math.min(W, H) * .09), words = wordsOf(d.memo);
    const mark = c.mark && words.length ? { from: Math.min(...c.mark), to: Math.max(...c.mark), color: c.paper === 'theme' ? k.pencil : k.mark, kind: c.pencil, onColor: c.paper === 'theme' } : null;
    ctx.fillStyle = k.bg; ctx.fillRect(0, 0, W, H);
    const memo = (s) => `400 ${s}px ${SERIF}`, strong = (s) => `600 ${s}px ${SERIF}`;
    const big = Math.round(Math.min(W, H) * (H > W * 1.5 ? .112 : .085));

    if (c.look === 'theme') {
      const spine = Math.round(Math.min(W, H) * .13);
      ctx.fillStyle = c.paper === 'theme' ? 'rgba(0,0,0,.18)' : k.mark; ctx.fillRect(0, 0, spine, H);
      const label = c.showThemes && theme ? theme.name : d.date;
      ctx.save(); ctx.translate(spine * .62, H - M); ctx.rotate(-Math.PI / 2);
      ctx.fillStyle = c.paper === 'night' ? '#171615' : '#FBFAF7'; ctx.font = strong(Math.round(spine * .36)); ctx.textAlign = 'left';
      ctx.fillText(clip(ctx, label, H - M * 2), 0, 0); ctx.restore();
      const X = spine + M * .8, bottom = footerAt(ctx, W, H, M, X, d, c, k);
      const f = fit(ctx, words, memo, { w: W - X - M, h: bottom - M }, range(big, 28, 2));
      block(ctx, words, f, memo, X, M, k.ink, mark);
      return canvas;
    }
    const bottom = footer(ctx, W, H, M, d, c, k);
    if (c.look === 'setting') {
      const name = c.showSetting ? d.setting : d.date, t = Math.round(Math.min(W, H) * .15);
      let x = M;
      if (c.showSetting) {
        ctx.strokeStyle = k.muted; ctx.lineWidth = 3; round(ctx, M, M, t, t, t * .2); ctx.stroke();
        ctx.fillStyle = k.ink; ctx.font = strong(Math.round(t * .36)); ctx.textAlign = 'center'; ctx.fillText(d.initials, M + t / 2, M + t * .56);
        ctx.fillStyle = k.mark; ctx.fillRect(M + t * .18, M + t * .76, t * .64, t * .05); ctx.textAlign = 'left';
        x = M + t + M * .45;
      }
      const nw = wordsOf(name), nf = fit(ctx, nw, strong, { w: W - x - M, h: t }, range(Math.round(t * .62), 30, 2));
      const ny = M + Math.max(0, (t - nf.lines.length * nf.size * 1.28) / 2);
      block(ctx, nw, nf, strong, x, ny, k.ink, null);
      let y = M + t + M * .5;
      if (c.showDate && c.showSetting) {
        const s = Math.round(W * .026); ctx.font = `400 ${s}px ${SANS}`; ctx.fillStyle = k.muted;
        const w = ctx.measureText(d.date).width; ctx.fillText(d.date, M + s * .9, y + s * 1.15);
        loop(ctx, M - s * .2, y - s * .15, w + s * 2.2, s * 2.1, k.pencil, 3); y += s * 3;
      }
      const f = fit(ctx, words, memo, { w: W - M * 2, h: bottom - y }, range(big, 26, 2));
      block(ctx, words, f, memo, M, y, k.ink, mark);
      return canvas;
    }
    if (c.look === 'words') {
      const first = String(d.memo).match(/^[^.!?]*[.!?]?/)[0], chosen = mark ? words.slice(mark.from, mark.to + 1) : wordsOf(first);
      const whole = chosen.length === words.length, boxH = (bottom - M) * (whole ? 1 : .62);
      const f = fit(ctx, chosen, strong, { w: W - M * 2, h: boxH }, range(Math.round(Math.min(W, H) * .16), 34, 3));
      const end = block(ctx, chosen, f, strong, M, M * .8, c.paper === 'theme' ? k.ink : k.pencil, null);
      if (!whole) {
        const rest = fit(ctx, words, memo, { w: W - M * 2, h: bottom - end - M * .4 }, range(Math.round(big * .6), 24, 2));
        block(ctx, words, rest, memo, M, end + M * .4, k.ink, null);
      }
      return canvas;
    }
    const f = fit(ctx, words, memo, { w: W - M * 2, h: bottom - M }, range(Math.round(big * 1.1), 28, 2));
    block(ctx, words, f, memo, M, M * .8, k.ink, mark);
    return canvas;
  }
  function footerAt(ctx, W, H, M, X, d, c, k) {
    const s = Math.round(W * .026);
    ctx.textAlign = 'right'; ctx.font = `600 ${Math.round(s * 1.05)}px ${SERIF}`; ctx.fillStyle = k.pencil; ctx.fillText('CentMemo', W - M, H - M);
    const room = W - M - X - ctx.measureText('CentMemo').width - s * 1.5;
    ctx.textAlign = 'left'; ctx.font = `400 ${s}px ${SANS}`; ctx.fillStyle = k.muted;
    const where = [c.showSetting ? d.setting : null, c.showDate && c.showThemes ? d.date : null].filter(Boolean).join(' · ');
    if (where) ctx.fillText(clip(ctx, where, room), X, H - M);
    return H - M - s * 2.4;
  }
  /* ---- A whole theme (DESIGN S6): the memos that share one word ---- */
  const THEME_LOOKS = ['cover', 'pages', 'lines'];
  // The person's underlined words, or the memo's first sentence.
  function linesOf(memo, mark) {
    const w = wordsOf(memo);
    if (mark && w.length) return w.slice(Math.min(...mark), Math.max(...mark) + 1);
    const end = w.findIndex((x) => /[.!?]$/.test(x));
    return end < 0 ? w : w.slice(0, end + 1);
  }
  // The largest size at which every block fits; at the smallest, as many as fit.
  function stack(ctx, items, make, w, h, sizes, gap, cap) {
    const measure = (s) => items.map((x) => lines(ctx, x, make(s), w));
    const tall = (L, s) => L.reduce((a, l) => a + l.length * s * 1.28 + (cap ? s * .95 : 0) + s * gap, items.length ? -s * gap : 0);
    for (const s of sizes) { const L = measure(s); if (tall(L, s) <= h && L.every((l) => l.every((r) => r.width <= w))) return { size: s, blocks: L }; }
    const s = sizes[sizes.length - 1], L = measure(s), out = []; let used = 0;
    for (const l of L) { const need = l.length * s * 1.28 + (cap ? s * .95 : 0) + (out.length ? s * gap : 0); if (used + need > h - s * 1.6) break; out.push(l); used += need; }
    return { size: s, blocks: out };
  }
  /* d: { theme: { name, color, dark }, span, memos: [{ memo, setting, date, mark }] }
   * c: { look, shape, paper, pencil, showSetting, showDate } */
  function drawTheme(canvas, d, c) {
    const [W, H] = SHAPES[c.shape] || SHAPES.square;
    canvas.width = W; canvas.height = H;
    const ctx = canvas.getContext('2d'), k = inks(c.paper, d.theme), short = Math.min(W, H), M = Math.round(short * .09);
    const memo = (s) => `400 ${s}px ${SERIF}`, strong = (s) => `600 ${s}px ${SERIF}`, sans = (s) => `400 ${s}px ${SANS}`;
    ctx.fillStyle = k.bg; ctx.fillRect(0, 0, W, H);
    const s = Math.round(W * .026);
    ctx.textBaseline = 'alphabetic'; ctx.textAlign = 'right'; ctx.font = `600 ${Math.round(s * 1.05)}px ${SERIF}`; ctx.fillStyle = k.pencil; ctx.fillText('CentMemo', W - M, H - M);
    const room = W - M * 2 - ctx.measureText('CentMemo').width - s * 1.5; ctx.textAlign = 'left';
    const foot = (t) => { ctx.font = sans(s); ctx.fillStyle = k.muted; ctx.fillText(clip(ctx, t, room), M, H - M); };
    const bottom = H - M - s * 2.6, many = d.memos.length === 1 ? '1 memo' : d.memos.length + ' memos';
    const mark = (y) => { ctx.fillStyle = k.mark; pill(ctx, M, y, short * .09, short * .012); };

    if (c.look === 'cover') {
      const nw = wordsOf(d.theme.name), f = fit(ctx, nw, strong, { w: W - M * 2, h: (bottom - M) * .55 }, range(Math.round(short * .2), 48, 4));
      mark(M);
      const end = block(ctx, nw, f, strong, M, M + short * .035, c.paper === 'theme' ? k.ink : k.pencil, null);
      const under = c.showSetting ? [...new Set(d.memos.map((m) => m.setting))] : [];
      if (under.length) {
        const words = under.join(' · ').split(' '), g = fit(ctx, words, memo, { w: W - M * 2, h: bottom - end - short * .03 }, range(Math.round(short * .05), 26, 2));
        block(ctx, words, g, memo, M, end + short * .03, k.ink, null);
      }
      foot([many, c.showDate ? d.span : null].filter(Boolean).join(' · '));
      return canvas;
    }
    if (c.look === 'lines') {
      const items = d.memos.map((m) => linesOf(m.memo, m.mark)), f = stack(ctx, items, strong, W - M * 2, bottom - M, range(Math.round(short * .1), 26, 2), .55, false);
      let y = M * .8;
      f.blocks.forEach((L, i) => { block(ctx, items[i], { size: f.size, lines: L }, strong, M, y, k.ink, null); y += L.length * f.size * 1.28 + f.size * .55; });
      const left = d.memos.length - f.blocks.length;
      ctx.fillStyle = k.mark; pill(ctx, M, H - M - s * .5, s * .85, s * .28);
      ctx.font = sans(s); ctx.fillStyle = k.muted; ctx.fillText(clip(ctx, [d.theme.name, left > 0 ? 'and ' + left + ' more' : null, c.showDate ? d.span : null].filter(Boolean).join(' · '), room - s * 1.2), M + s * 1.1, H - M);
      return canvas;
    }
    const head = Math.round(short * .06); ctx.font = strong(head); ctx.fillStyle = c.paper === 'theme' ? k.ink : k.pencil;
    ctx.fillText(clip(ctx, d.theme.name, W - M * 2), M, M + head); mark(M + head * 1.35);
    const top = M + head * 2, cap = c.showSetting || c.showDate, items = d.memos.map((m) => wordsOf(m.memo));
    const f = stack(ctx, items, memo, W - M * 2, bottom - top, range(Math.round(short * .055), 22, 1), .8, cap);
    let y = top;
    f.blocks.forEach((L, i) => {
      block(ctx, items[i], { size: f.size, lines: L }, memo, M, y, k.ink, d.memos[i].mark ? { from: Math.min(...d.memos[i].mark), to: Math.max(...d.memos[i].mark), color: c.paper === 'theme' ? k.pencil : k.mark, kind: c.pencil, onColor: c.paper === 'theme' } : null);
      y += L.length * f.size * 1.28;
      if (cap) { const t = Math.round(Math.max(20, f.size * .62)); ctx.font = sans(t); ctx.fillStyle = k.muted; ctx.fillText([c.showSetting ? d.memos[i].setting : null, c.showDate ? d.memos[i].date : null].filter(Boolean).join(' · '), M, y + f.size * .72); y += f.size * .95; }
      y += f.size * .8;
    });
    const left = d.memos.length - f.blocks.length;
    foot(left > 0 ? 'and ' + left + ' more' : many);
    return canvas;
  }
  function round(ctx, x, y, w, h, r) { ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r); ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath(); }

  const api = { LOOKS, THEME_LOOKS, SHAPES, PAPERS, PENCILS, draw, drawTheme, linesOf, wordsOf, inks };
  root.CentShare = api;
  if (typeof module !== 'undefined') module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
