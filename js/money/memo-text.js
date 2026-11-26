/**
 * CentMemoText (W4, Decision 069): a memo's styled text, kept as a small Markdown
 * subset: **bold**, *italic*, ~~strike~~, "# " heading, "- " list item, "> " quote.
 * The Swift twin is apple/Core/Models/MemoText.swift; tests/fixtures/memo-text.json
 * holds both to the same answers. Never HTML in, always escaped HTML out.
 */
(function (root) {
  'use strict';

  const BLOCKS = [['## ', 'heading'], ['# ', 'heading'], ['- ', 'bullet'], ['* ', 'bullet'], ['> ', 'quote']];

  function lineOf(raw) {
    for (const [prefix, block] of BLOCKS) if (raw.startsWith(prefix)) return { block, runs: inline(raw.slice(prefix.length)) };
    return { block: 'paragraph', runs: inline(raw) };
  }

  // Tokens: escaped characters are literal; a marker counts only when the same marker
  // closes it later on the line (CommonMark leaves a lone one as text).
  function inline(s) {
    const toks = [];
    for (let i = 0; i < s.length;) {
      if (s[i] === '\\' && i + 1 < s.length && '\\*_~`[]<#->!'.includes(s[i + 1])) { toks.push({ t: s[i + 1] }); i += 2; continue; }
      if (s.startsWith('~~', i)) { toks.push({ m: '~~' }); i += 2; continue; }
      if (s.startsWith('**', i)) { toks.push({ m: '**' }); i += 2; continue; }
      if (s[i] === '*') { toks.push({ m: '*' }); i += 1; continue; }
      toks.push({ t: s[i] }); i += 1;
    }
    const open = { '**': false, '*': false, '~~': false };
    const runs = [];
    const push = (text) => {
      const r = { text, bold: open['**'], italic: open['*'], strike: open['~~'] };
      const last = runs[runs.length - 1];
      if (last && last.bold === r.bold && last.italic === r.italic && last.strike === r.strike) last.text += text;
      else runs.push(r);
    };
    toks.forEach((k, i) => {
      if (k.t !== undefined) return push(k.t);
      if (open[k.m]) { open[k.m] = false; return; }
      if (toks.slice(i + 1).some((n) => n.m === k.m)) { open[k.m] = true; return; }
      push(k.m);
    });
    return runs;
  }

  function parse(md) {
    return String(md || '').replace(/\r\n/g, '\n').split('\n').map(lineOf);
  }

  const textOf = (l) => l.runs.map((r) => r.text).join('');

  function plain(md) {
    return parse(md).map((l) => (l.block === 'bullet' ? '• ' : '') + textOf(l)).join('\n');
  }

  const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  function runHTML(r) {
    let h = esc(r.text);
    if (r.italic) h = '<em>' + h + '</em>';
    if (r.bold) h = '<strong>' + h + '</strong>';
    if (r.strike) h = '<s>' + h + '</s>';
    return h;
  }

  /** The memo as escaped HTML blocks, for pages that show it whole (the Story). */
  function html(md) {
    const out = [];
    let list = null;
    for (const l of parse(md)) {
      const body = l.runs.map(runHTML).join('');
      if (l.block === 'bullet') { (list = list || []).push('<li>' + body + '</li>'); continue; }
      if (list) { out.push('<ul class="memo-list">' + list.join('') + '</ul>'); list = null; }
      if (l.block === 'heading') out.push('<p class="memo-heading"><strong>' + body + '</strong></p>');
      else if (l.block === 'quote') out.push('<blockquote class="memo-quote">' + body + '</blockquote>');
      else out.push('<p>' + (body || '<br>') + '</p>');
    }
    if (list) out.push('<ul class="memo-list">' + list.join('') + '</ul>');
    return out.join('');
  }

  const api = { parse, plain, html };
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.CentMemoText = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
