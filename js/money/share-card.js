/* The share card (DESIGN S): one memo as an image the person designs. Draws to a
 * canvas from the memo, its Setting, its date and its themes. It is never given an
 * amount, so it can never show one (Ben, 2026-11-24). The Apple twin is ShareCard.swift. */
(function (root) {
  'use strict';
  const LOOKS = ['page', 'setting', 'theme', 'words'];
  const SHAPES = { square: [1080, 1080], tall: [1080, 1920], wide: [1200, 630] };
  const PAPERS = ['paper', 'night', 'theme'];
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
  function block(ctx, words, f, make, x, y, ink, mark) {
    ctx.font = make(f.size); ctx.textBaseline = 'alphabetic'; ctx.textAlign = 'left';
    const space = ctx.measureText(' ').width, lh = f.size * 1.28;
    let last = y;
    f.lines.forEach((l, n) => {
      let cx = x; const base = y + f.size + n * lh; last = base;
      let from = null, to = null;
      l.words.forEach((i, k) => {
        let t = words[i];
        if (f.cut && n === f.lines.length - 1 && k === l.words.length - 1) t += '…';
        const w = ctx.measureText(t).width;
        ctx.fillStyle = ink; ctx.fillText(t, cx, base);
        if (mark && i >= mark.from && i <= mark.to) { if (from == null) from = cx; to = cx + w; }
        cx += w + space;
      });
      if (from != null) stroke(ctx, from, base + f.size * .16, to - from, mark.color, Math.max(3, f.size * .07));
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
   * c: { look, shape, paper, showSetting, showDate, showThemes, mark: [from, to] | null } */
  function draw(canvas, d, c) {
    const [W, H] = SHAPES[c.shape] || SHAPES.square;
    canvas.width = W; canvas.height = H;
    const ctx = canvas.getContext('2d'), theme = d.themes[0] || null, k = inks(c.paper, theme);
    const M = Math.round(Math.min(W, H) * .09), words = wordsOf(d.memo);
    const mark = c.mark && words.length ? { from: Math.min(...c.mark), to: Math.max(...c.mark), color: c.paper === 'theme' ? k.pencil : k.mark } : null;
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
  function round(ctx, x, y, w, h, r) { ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r); ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath(); }

  const api = { LOOKS, SHAPES, PAPERS, draw, wordsOf, inks };
  root.CentShare = api;
  if (typeof module !== 'undefined') module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
