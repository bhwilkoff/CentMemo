/**
 * CentMemo web app. Vanilla JS (Decision 001), one IIFE.
 * Views are <section> elements; the hash is the route:
 *   #/unexamined  #/ledger/2026-11  #/t/<id>  #/setting/<name>  #/story/<month|value:id>
 *   #/import  #/settings
 * All network calls go through API (js/api.js). DOM text is set with
 * textContent; nothing from the database is ever parsed as HTML.
 */
(function () {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const M = window.CentMoney;

  function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v == null || v === false) continue;
      if (k === 'class') el.className = v;
      else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
      else el.setAttribute(k, v === true ? '' : v);
    }
    for (const kid of kids.flat()) if (kid != null && kid !== false) el.append(kid.nodeType ? kid : String(kid));
    return el;
  }
  // Like replaceChildren, but with h()'s rules: lists are spread, and null or false
  // is nothing. replaceChildren itself prints "null" and turns a list into text.
  function fill(el, ...kids) {
    el.replaceChildren(...kids.flat().filter((k) => k != null && k !== false && k !== ''));
  }
  // DESIGN W: two columns when there is room, one after the other when there is not.
  // `side` stands left unless the page says otherwise (the purchase desk's is right).
  function split(side, main) {
    return h('div', { class: 'split' }, h('div', { class: 'split-side' }, side), h('div', { class: 'split-main' }, main));
  }
  // Settings: each heading and what follows it, side by side when there is room.
  function sections(kids) {
    const out = [];
    for (const k of kids.filter((x) => x != null && x !== '')) {
      if (k.tagName === 'H2') out.push(h('section', { class: 'set' }, k, h('div', { class: 'set-body' })));
      else out[out.length - 1].lastChild.append(k);
    }
    return out;
  }
  function icon(name) {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('aria-hidden', 'true');
    const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    use.setAttribute('href', '#i-' + name);
    svg.append(use);
    return svg;
  }
  const money = (minor, cur) => M.formatMinor(minor, cur || 'USD');
  // D8: Apple Card's category words for every event (plain_category, in the database).
  const catOf = (t) => t.plain_category || t.category || '';
  // A row's date: the year only when it isn't this one (DESIGN W2).
  function rowDate(iso) {
    const full = niceDate(iso);
    return iso && iso.slice(0, 4) === String(new Date().getUTCFullYear()) ? full.replace(/, \d{4}$/, '') : full;
  }
  function niceDate(iso) {
    const [y, m, d] = iso.split('-').map(Number);
    return new Date(Date.UTC(y, m - 1, d)).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' });
  }
  function monthName(ym) {
    const [y, m] = ym.split('-').map(Number);
    return new Date(Date.UTC(y, m - 1, 1)).toLocaleDateString('en-US', { month: 'long', year: 'numeric', timeZone: 'UTC' });
  }
  function stepMonth(ym, n) {
    const [y, m] = ym.split('-').map(Number);
    const d = new Date(Date.UTC(y, m - 1 + n, 1));
    return d.toISOString().slice(0, 7);
  }
  const thisMonth = () => new Date().toISOString().slice(0, 7);
  // D8: a Setting's key is its cleaned name; the person's rename, when there is one, is what shows.
  let NAMES = {};
  const placeKey = (t) => CentMoney.cleanMerchant(t.merchant || t.description) || 'Unknown';
  const merchantOf = (t) => NAMES[placeKey(t)] || placeKey(t);
  const TILE_HUES = ['clay', 'ochre', 'sage', 'slate', 'rose', 'stone'];
  // D8: the store tile, the same initials and hue as the iPhone (Money.merchantHue).
  function tile(t, big) {
    const name = merchantOf(t);
    return h('span', { class: 'tile' + (big ? ' tile-big' : ''), 'aria-hidden': 'true', style: '--tile-hue: var(--color-store-' + TILE_HUES[CentMoney.merchantHue(name, 6)] + ')' }, CentMoney.merchantInitials(name));
  }

  /* ---- Four states (universal-feature-states) ---- */
  function loading(body) { fill(body, h('p', { class: 'state state-loading', role: 'status' }, 'Loading…')); }
  function empty(body, text, action) { fill(body, h('div', { class: 'state state-empty' }, h('p', {}, text), action || null)); }
  function failed(body, err, retry) {
    fill(body, h('div', { class: 'banner banner-error', role: 'alert' },
      h('span', {}, !navigator.onLine ? 'You\'re offline.'
        : /Failed to fetch|NetworkError|Load failed/i.test((err && err.message) || '') ? 'CentMemo couldn\'t reach its server.'
        : (err && err.message) || 'Something went wrong.'),
      retry ? h('button', { class: 'btn btn-small', onclick: retry }, 'Try again') : null));
  }
  function updateOnline() { $('offline-banner').hidden = navigator.onLine; }
  window.addEventListener('online', updateOnline);
  window.addEventListener('offline', updateOnline);

  /* ---- Navigation ---- */
  const TABS = [
    { id: 'unexamined', label: 'Unexamined', icon: 'inbox', href: '#/unexamined' },
    { id: 'ledger', label: 'Narrative', icon: 'list', href: '#/ledger' },
    { id: 'story', label: 'Story', icon: 'book', href: '#/story' },
    { id: 'import', label: 'Import', icon: 'import', href: '#/import' },
    { id: 'settings', label: 'Settings', icon: 'gear', href: '#/settings' },
  ];
  function buildTabs() {
    document.querySelectorAll('.tabs').forEach((nav) => {
      fill(nav, ...TABS.map((t) => h('a', { class: 'tab', href: t.href, 'data-tab': t.id }, icon(t.icon), h('span', {}, t.label))));
    });
  }
  function showView(id, tab) {
    document.querySelectorAll('.view').forEach((v) => { v.hidden = v.id !== 'view-' + id; });
    document.querySelectorAll('.tab').forEach((a) => {
      if (a.dataset.tab === tab) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
    });
    $('main-content').scrollTop = 0;
    return $('view-' + id).querySelector('[data-body]');
  }

  let lastList = '#/unexamined';
  let depth = 0;
  async function route() {
    if (history.state && history.state.depth) depth = history.state.depth;
    else history.replaceState({ depth: ++depth }, '');
    const parts = (location.hash.replace(/^#\/?/, '') || 'unexamined').split('/');
    const [name, arg] = parts;
    try {
      try { NAMES = await API.settingNames(); } catch (_) { NAMES = {}; }
      try { THEME_COLORS = CentThemes.assignColors(await API.values()); } catch (_) { THEME_COLORS = {}; }
      if (name === 'ledger') { lastList = location.hash; return await ledgerView(arg); }
      if (name === 't' && arg) return await txnView(arg);
      if (name === 'setting' && arg) return await settingView(decodeURIComponent(arg));
      if (name === 'story') { lastList = location.hash; return await storyView(arg ? decodeURIComponent(arg) : null); }
      if (name === 'import') return importView();
      if (name === 'settings') return await settingsView();
      lastList = '#/unexamined';
      return await unexaminedView();
    } catch (err) {
      console.error(err);
    }
  }

  /* ---- Rows ---- */
  function txnRow(t, opts) {
    const memo = t.memos && (Array.isArray(t.memos) ? t.memos[0] : t.memos);
    // DESIGN C3.1: in the Ledger, a purchase still waiting for a memo is highlighted.
    const waiting = opts && opts.memo && !memo && t.amount_minor < 0 && t.status !== 'rejected';
    return h('a', { class: 'row' + (waiting ? ' is-unexamined' : ''), href: '#/t/' + t.id },
      tile(t),
      h('span', { class: 'row-main' },
        h('span', { class: 'row-title' }, merchantOf(t)),
        h('span', { class: 'row-sub' }, [rowDate(t.txn_date), catOf(t), t.status === 'pending' ? 'Pending' : null].filter(Boolean).join(' · ')),
        opts && opts.memo && memo ? h('span', { class: 'row-memo' }, memo.body) : null),
      h('span', { class: 'row-amount' + (t.amount_minor > 0 ? ' is-credit' : '') }, money(t.amount_minor, t.currency)));
  }

  /* ---- Unexamined (home) ---- */
  // The words for each rule; human-written, Ben approves them (as SuggestionWords).
  // The question fits the purchase's moment first (Ben, 2026-11-23: State Farm
  // Insurance asked "What was the day about?"), then the rule's own question.
  const REASONS = { first_visit: 'First time here', biggest_month: 'Biggest this month', busy_day: 'Your busiest day this month', year_ago: 'A year ago you wrote' };
  const PROMPTS = { first_visit: 'What brought you here?', biggest_month: 'What was it for?', busy_day: 'What was the day about?' };
  const MOMENTS = { meal: 'What was the occasion?', groceries: 'What were you making?', trip: 'Where were you headed?',
    ride: 'Where were you going?', fuel: 'Where was the drive taking you?', car: 'What did the car need?', outing: 'What did you see?',
    find: 'What did you find?', care: 'Who was it for?', gift: 'Who was it for?', giving: 'What moved you to give?', shop: 'What did you bring home?' };
  const promptFor = (s) => MOMENTS[s.moment] || PROMPTS[s.kind] || null;
  // One invitation at a time (as the iPhone's SuggestionCard): the question leads
  // over a pencil line, the place is the small print, and it ends on the act.
  function suggestionCard(s, t) {
    const prompt = s.memo_body ? null : promptFor(s);
    return h('a', { class: 'suggestion', href: '#/t/' + t.id, 'data-kind': s.kind },
      h('span', { class: 'suggestion-reason' }, REASONS[s.kind] || ''),
      s.memo_body ? h('span', { class: 'suggestion-quote' }, '\u201C' + s.memo_body + '\u201D')
        : prompt ? h('span', { class: 'suggestion-prompt' }, prompt) : null,
      h('span', { class: 'suggestion-place' }, tile(t), h('span', { class: 'caption' }, merchantOf(t) + ' · ' + rowDate(t.txn_date)),
        h('span', { class: 'caption suggestion-amount' }, money(t.amount_minor, t.currency))),
      h('span', { class: 'suggestion-act' }, s.memo_body ? 'Read it again' : 'Write a memo'));
  }
  async function suggestionCards(rows) {
    const out = [];
    for (const s of (await API.suggestions()).slice(0, 3)) {
      const t = rows.find((r) => r.id === s.transaction_id) || await API.transaction(s.transaction_id).catch(() => null);
      if (t) out.push(suggestionCard(s, t));
    }
    if (out.length < 2) return out;
    let shown = 0;
    // In the card's corner (Ben, 2026-11-23): a sibling laid over the card, since a
    // button inside the card's link would open the event.
    const box = h('div', { class: 'suggestions has-another' }, out[0]);
    // The icon alone (Ben, 2026-11-23), named for screen readers.
    const another = h('button', { class: 'suggestion-another', type: 'button', 'data-another': '', 'aria-label': 'Another suggestion', title: 'Another suggestion' });
    another.innerHTML = '<svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12a8 8 0 1 1-2.34-5.66"/><path d="M20 4v4h-4"/></svg>';
    another.addEventListener('click', () => { shown = (shown + 1) % out.length; fill(box, out[shown], another); });
    box.append(another);
    return [box];
  }

  /* ---- D14: starter themes (Ben's approved list), in Settings only (Ben, 2026-11-24) ---- */
  function starterRows(held, onAdd) {
    const have = new Set(held.map((v) => v.name.trim().toLowerCase()));
    return CentThemes.STARTERS.filter((t) => !have.has(t.name.toLowerCase())).map((t) => {
      // The color it would take if added now, by the same rule.
      const color = CentThemes.nextColor(held, t.name);
      const add = h('button', { type: 'button', class: 'btn btn-small' }, 'Add');
      add.addEventListener('click', () => onAdd(t, add));
      return h('li', { class: 'row row-static starter', 'data-starter': t.name },
        h('i', { class: 'theme-mark', style: 'background: var(--color-theme-' + color + ')' }),
        h('span', { class: 'starter-text' }, h('strong', {}, t.name), h('span', { class: 'caption' }, t.meaning)), add);
    });
  }
  async function unexaminedView() {
    const body = showView('unexamined', 'unexamined');
    const heading = $('h-unexamined');
    heading.textContent = 'Unexamined';
    loading(body);
    try {
      const { rows, count } = await API.unexamined();
      if (!rows.length) {
        const any = await API.transactionCount();
        return any
          ? empty(body, 'Every purchase has a memo.')
          : empty(body, 'Nothing in your Narrative yet.', h('a', { class: 'btn btn-primary', href: '#/import' }, 'Import a CSV'));
      }
      // D7: one invitation at a time, "Another" for the next of up to three; no
      // count of what is left (as the iPhone's SuggestionCard).
      const picks = await suggestionCards(rows).catch(() => []);
      const invite = picks.length === 1 ? h('div', { class: 'suggestions' }, picks) : picks.length ? picks[0] : null;
      const list = [h('div', { class: 'list' }, rows.map((t) => txnRow(t))),
        count > rows.length ? h('p', { class: 'caption' }, 'Showing the newest ' + rows.length + '.') : null];
      fill(body, invite ? split([invite], list) : list);
    } catch (err) { failed(body, err, unexaminedView); }
  }

  // Cash back and interest into Apple Cash or Savings: details, hidden from the
  // Narrative by default (Ben, 2026-11-22), as LedgerEntry.isQuietDetail on the iPhone.
  const isQuietDetail = (t) => t.txn_type === 'deposit' || t.txn_type === 'interest';
  function quietToggle(list) {
    if (!list.length) return '';
    const box = h('details', { class: 'skipped quiet-details' }, h('summary', {}, list.length + ' deposits and interest hidden · Show'),
      h('div', { class: 'thread' }, list.map(threadRow)));
    return box;
  }

  // D9: show only some kinds of events; the same rule as the iPhone's NarrativeFilter.
  const filter = { show: 'all', theme: '', details: false };
  const memoOf = (t) => t.memos && (Array.isArray(t.memos) ? t.memos[0] : t.memos);
  const themesOf = (t) => ((memoOf(t) || {}).memo_values || []).map((v) => v.life_values && v.life_values.name).filter(Boolean);
  function narrativeFilter(rows) {
    return rows.filter((t) => {
      if (t.skipped_at) return false;
      if (!filter.details && isQuietDetail(t)) return false;
      const written = !!(memoOf(t) && memoOf(t).body);
      if (filter.show === 'written' && !written) return false;
      if (filter.show === 'unwritten' && written) return false;
      return !filter.theme || themesOf(t).includes(filter.theme);
    });
  }
  // D11: the month by theme (as the iPhone's ThemeStrip / MonthStrip): money spent
  // under each written memo's first theme; a legend names every part.
  // D14: each theme's own color, by the shared rule (js/money/themes.js).
  let THEME_COLORS = {};
  const themeKey = (name) => {
    const k = String(name || '').trim().toLowerCase();
    return THEME_COLORS[k] || (CentThemes.STARTERS.find((s) => s.name.toLowerCase() === k) || {}).color
      || CentThemes.PALETTE[CentMoney.merchantHue(k, CentThemes.PALETTE.length)];
  };
  const themeHue = (name) => 'var(--color-theme-' + themeKey(name) + ')';
  function themeStrip(rows) {
    const sums = new Map();
    for (const t of rows) {
      if (t.skipped_at || t.amount_minor >= 0) continue;
      const first = themesOf(t)[0];
      if (first) sums.set(first, (sums.get(first) || 0) - t.amount_minor);
    }
    return [...sums].map(([theme, spent]) => ({ theme, spent }))
      .sort((a, b) => b.spent - a.spent || a.theme.localeCompare(b.theme));
  }
  function monthStrip(rows) {
    const parts = themeStrip(rows);
    if (!parts.length) return '';
    const total = parts.reduce((a, p) => a + p.spent, 0);
    return h('div', { class: 'month-strip' },
      h('div', { class: 'strip-bar', 'aria-hidden': 'true' },
        parts.map((p) => h('span', { style: 'flex: ' + (p.spent / total) + '; background: ' + themeHue(p.theme) }))),
      h('ul', { class: 'strip-legend' }, parts.map((p) =>
        h('li', {}, h('i', { style: 'background: ' + themeHue(p.theme) }), p.theme, ' ', h('span', { class: 'caption' }, money(p.spent))))));
  }

  function narrativeFilters(rows) {
    const thread = h('div', { class: 'thread' });
    const draw = () => fill(thread, ...narrativeFilter(rows).map(threadRow));
    const show = h('select', { id: 'filter-show', 'aria-label': 'Show' },
      ['all', 'written', 'unwritten'].map((v) => h('option', { value: v, selected: filter.show === v }, v[0].toUpperCase() + v.slice(1))));
    const names = [...new Set(rows.flatMap(themesOf))].sort();
    const theme = h('select', { id: 'filter-theme', 'aria-label': 'Theme' },
      h('option', { value: '' }, 'Every theme'), names.map((n) => h('option', { value: n, selected: filter.theme === n }, n)));
    const quiet = rows.filter((t) => !t.skipped_at && isQuietDetail(t)).length;
    const details = h('input', { type: 'checkbox', id: 'filter-details', checked: filter.details });
    show.addEventListener('change', () => { filter.show = show.value; draw(); });
    theme.addEventListener('change', () => { filter.theme = theme.value; draw(); });
    details.addEventListener('change', () => { filter.details = details.checked; draw(); });
    draw();
    return { thread, controls:
      h('div', { class: 'filters', role: 'group', 'aria-label': 'Filter the Narrative' }, show, names.length ? theme : null,
        quiet ? h('label', { class: 'filter-check' }, details, ' ' + quiet + ' deposits and interest') : null) };
  }

  /* ---- The Narrative as a thread (D10), as on the iPhone's ThreadRow ---- */
  // On a Setting's own page (place: false) the rows leave out the place.
  function threadRow(t, opts) {
    const place = !(opts && opts.place === false);
    const memo = t.memos && (Array.isArray(t.memos) ? t.memos[0] : t.memos);
    const meta = rowDate(t.txn_date) + (place ? ' · ' + merchantOf(t) : '');
    if (!memo || !memo.body) {
      return h('a', { class: 'trow is-waiting', href: '#/t/' + t.id },
        h('span', { class: 'trow-mark', 'aria-hidden': 'true' }),
        h('span', { class: 'trow-meta' }, meta),
        h('span', { class: 'row-amount' + (t.amount_minor > 0 ? ' is-credit' : '') }, money(t.amount_minor, t.currency)));
    }
    const theme = ((memo.memo_values || [])[0] || {}).life_values;
    const hue = theme ? themeHue(theme.name) : 'var(--color-primary)';
    return h('a', { class: 'trow is-written', href: '#/t/' + t.id, style: '--mark: ' + hue },
      h('span', { class: 'trow-mark', 'aria-hidden': 'true' }),
      h('span', { class: 'trow-body' },
        h('span', { class: 'trow-memo' }, memo.body),
        h('span', { class: 'trow-meta' }, place ? tile(t) : null, meta, theme ? h('span', { class: 'trow-theme' }, theme.name) : null)));
  }

  /* ---- Ledger ---- */
  async function ledgerView(ym) {
    const body = showView('ledger', 'ledger');
    if (!ym || !/^\d{4}-\d{2}$/.test(ym)) {
      ym = (await API.latestMonth().catch(() => null)) || thisMonth();
      history.replaceState(history.state, '', '#/ledger/' + ym);
    }
    $('h-ledger').textContent = monthName(ym);
    $('view-ledger').dataset.month = ym;
    loading(body);
    try {
      const rows = await API.month(ym);
      if (!rows.length) return empty(body, 'Nothing recorded in ' + monthName(ym) + '.');
      const live = rows.filter((t) => t.status !== 'rejected');
      const spent = live.filter((t) => t.amount_minor < 0).reduce((a, t) => a - t.amount_minor, 0);
      const received = live.filter((t) => t.amount_minor > 0).reduce((a, t) => a + t.amount_minor, 0);
      const written = rows.filter((t) => t.memos && (Array.isArray(t.memos) ? t.memos.length : t.memos)).length;
      const story = narrativeFilters(rows);
      fill(body, split([
        h('dl', { class: 'totals' },
          h('div', {}, h('dt', {}, 'Spent'), h('dd', {}, money(spent))),
          h('div', {}, h('dt', {}, 'Paid or credited'), h('dd', {}, money(received))),
          h('div', {}, h('dt', {}, 'Memos'), h('dd', {}, written + ' of ' + rows.length))),
        monthStrip(rows),
        story.controls], [
        story.thread,
        rows.some((t) => t.skipped_at)
          ? h('details', { class: 'skipped' }, h('summary', {}, rows.filter((t) => t.skipped_at).length + ' skipped'),
              h('div', { class: 'list' }, rows.filter((t) => t.skipped_at).map((t) => txnRow(t))))
          : null]));
    } catch (err) { failed(body, err, () => ledgerView(ym)); }
  }
  document.querySelectorAll('[data-month-step]').forEach((b) => b.addEventListener('click', () => {
    const ym = $('view-ledger').dataset.month || thisMonth();
    location.hash = '#/ledger/' + stepMonth(ym, Number(b.dataset.monthStep));
  }));

  /* ---- One transaction: the memo is written here ---- */
  async function txnView(id) {
    const body = showView('txn', null);
    loading(body);
    try {
      const [t, vals] = await Promise.all([API.transaction(id), API.values()]);
      if (!t) return empty(body, 'This event isn\'t in your CentMemo.');
      const memo = t.memos && (Array.isArray(t.memos) ? t.memos[0] : t.memos);
      const chosen = new Set(memo ? (memo.memo_values || []).map((v) => v.value_id) : []);
      const area = h('textarea', { id: 'memo-body', class: 'field-input memo-input', rows: '6', maxlength: '10000' });
      area.value = memo ? memo.body : '';
      area.placeholder = 'What do you want to remember?';
      const status = h('p', { class: 'caption', role: 'status' });
      const error = h('div', { class: 'banner banner-error', role: 'alert', hidden: true });

      // Skip (Decision 065): the web's version of the iPhone's swipe.
      const skipBtn = h('button', { type: 'button', class: 'btn btn-quiet', 'data-skip': '' }, t.skipped_at ? 'Bring back' : 'Skip');
      skipBtn.addEventListener('click', async () => {
        try { await API.setSkipped(t.id, !t.skipped_at); txnView(id); } catch (err) { failed(body, err, () => txnView(id)); }
      });
      const chips = h('div', { class: 'chips', role: 'group', 'aria-label': 'Themes' });
      function drawChips(list) {
        fill(chips, ...list.map((v) => {
          const b = h('button', { type: 'button', class: 'chip', 'aria-pressed': chosen.has(v.id) ? 'true' : 'false' }, v.name);
          b.addEventListener('click', () => {
            if (chosen.has(v.id)) chosen.delete(v.id); else chosen.add(v.id);
            b.setAttribute('aria-pressed', chosen.has(v.id) ? 'true' : 'false');
          });
          return b;
        }));
      }
      drawChips(vals);
      const newValue = h('input', { type: 'text', class: 'field-input field-inline', maxlength: '60', 'aria-label': 'New theme', placeholder: 'Add a theme' });
      const addBtn = h('button', { type: 'button', class: 'btn btn-small' }, 'Add theme');
      addBtn.addEventListener('click', async () => {
        const name = newValue.value.trim();
        if (!name) return newValue.focus();
        try {
          const v = await API.addValue(name);
          vals.push(v); vals.sort((a, b) => a.name.localeCompare(b.name));
          THEME_COLORS = CentThemes.assignColors(await API.values());
          chosen.add(v.id); newValue.value = ''; drawChips(vals);
        } catch (err) { error.textContent = /duplicate|unique/i.test(err.message) ? 'You already have that theme.' : err.message; error.hidden = false; }
      });

      const save = h('button', { type: 'button', class: 'btn btn-primary' }, 'Save');
      save.addEventListener('click', async () => {
        error.hidden = true;
        if (!area.value.trim() && chosen.size) { error.textContent = 'Write the memo first; themes belong to a memo.'; error.hidden = false; return; }
        save.disabled = true; status.textContent = 'Saving…';
        try {
          await API.saveMemo(t.id, area.value, [...chosen]);
          status.textContent = area.value.trim() ? 'Saved.' : 'Memo removed.';
        } catch (err) { status.textContent = ''; error.textContent = err.message; error.hidden = false; }
        save.disabled = false;
      });

      // D6 (Decision 065): the Setting and the memo lead; the money and the
      // bank's facts are a footnote, as on the iPhone.
      const head = h('div', { class: 'txn-head' },
          tile(t, true),
          h('div', { class: 'txn-title' },
            h('h1', { id: 'h-txn', class: 'view-heading' }, merchantOf(t)),
            h('p', { class: 'caption' }, niceDate(t.txn_date) + ' · ',
              h('a', { href: '#/setting/' + encodeURIComponent(placeKey(t)), 'data-setting': '' }, 'Every visit')),
            placeLine(await API.settingPlaces().then((p) => p[placeKey(t)]).catch(() => null))));
      // W3: the memo is the page; what belongs to it stands beside it when there is room.
      fill(body, h('div', { class: 'split split-desk' }, h('div', { class: 'split-main' }, [
        head,
        h('label', { class: 'field-label', for: 'memo-body' }, 'Memo'),
        area]), h('div', { class: 'split-side' }, [
        h('p', { class: 'field-label' }, 'Themes'),
        chips,
        h('div', { class: 'inline-form' }, newValue, addBtn),
        error,
        h('div', { class: 'actions' }, save, status, skipBtn),
        photosNote(t.attachments) || '',
        filesList(t.attachments) || '',
        h('details', { class: 'txn-details' },
          h('summary', {},
            h('span', { class: 'txn-amount' + (t.amount_minor > 0 ? ' is-credit' : '') }, money(t.amount_minor, t.currency)),
            ' ', h('span', { class: 'caption' }, [t.accounts && t.accounts.display_name, catOf(t)].filter(Boolean).join(' · '))),
          h('dl', { class: 'facts' },
            fact('Date', niceDate(t.txn_date)),
            t.posted_date && t.posted_date !== t.txn_date ? fact('Posted', niceDate(t.posted_date)) : null,
            catOf(t) ? fact('Category', catOf(t)) : null,
            t.txn_type ? fact('Type', t.txn_type) : null,
            t.status !== 'booked' ? fact('Status', t.status) : null,
            t.accounts ? fact('Account', t.accounts.display_name) : null,
            t.description && t.description !== t.merchant ? fact('Statement', t.description) : null))])),
        memo && memo.body ? sharePanel(t, memo) : '',
        memo && memo.body ? linkPanel('memo', [t], ((memo.memo_values || [])[0] || {}).life_values ? { name: memo.memo_values[0].life_values.name, id: memo.memo_values[0].value_id || memo.memo_values[0].life_values.id } : null) : '');
    } catch (err) { failed(body, err, () => txnView(id)); }
  }
  // D8: a Setting's page, every visit there as a thread (as the iPhone's SettingView).
  async function settingView(name) {
    const body = showView('setting', null);
    loading(body);
    try {
      const rows = (await API.atSetting(name)).filter((t) => !t.skipped_at);
      if (!rows.length) return empty(body, 'Nothing at ' + name + ' in your CentMemo.');
      const written = rows.filter((t) => { const m = t.memos && (Array.isArray(t.memos) ? t.memos[0] : t.memos); return m && m.body; }).length;
      const first = rows[rows.length - 1].txn_date;
      const shown = NAMES[name] || name;
      const heading = h('h1', { id: 'h-setting', class: 'view-heading' }, shown);
      // D8 renames: the person's name for this place; cleared, the bank's name returns.
      const rename = h('button', { class: 'btn btn-small', type: 'button', 'data-rename': '' }, 'Rename');
      rename.addEventListener('click', () => {
        const input = h('input', { type: 'text', value: shown, maxlength: '80', 'aria-label': 'Name for ' + name, 'data-rename-input': '' });
        const form = h('form', { class: 'rename-form' }, input, h('button', { class: 'btn btn-small', type: 'submit' }, 'Save'));
        form.addEventListener('submit', async (e) => {
          e.preventDefault();
          try { await API.renameSetting(name, input.value); NAMES = await API.settingNames(); settingView(name); } catch (err) { failed(body, err, () => settingView(name)); }
        });
        heading.replaceWith(form); rename.remove(); input.focus(); input.select();
      });
      fill(body, split([h('div', { class: 'txn-head' }, tile(rows[0], true),
          h('div', { class: 'txn-title' },
            heading,
            h('p', { class: 'caption', 'data-setting-summary': '' },
              [rows.length === 1 ? '1 visit' : rows.length + ' visits', rows.length > 1 ? 'since ' + niceDate(first) : null,
                written ? (written === 1 ? '1 memo' : written + ' memos') : null].filter(Boolean).join(' · ')),
            shown !== name ? h('p', { class: 'caption' }, 'On the statement: ' + name) : null,
            placeLine(await API.settingPlaces().then((p) => p[name]).catch(() => null)),
            rename))],
        [h('div', { class: 'thread' }, rows.map((t) => threadRow(t, { place: false })))]));
    } catch (err) { failed(body, err, () => settingView(name)); }
  }
  // D15: a confirmed place, as words and a link that opens Apple Maps there.
  function placeLine(p) {
    if (!p) return null;
    const href = 'https://maps.apple.com/?ll=' + p.lat.toFixed(6) + ',' + p.lon.toFixed(6) + '&q=' + encodeURIComponent(p.name);
    return h('p', { class: 'place-line', 'data-place': '' },
      h('a', { href, target: '_blank', rel: 'noopener' }, p.name), p.address ? h('span', { class: 'caption' }, ' · ' + p.address) : null);
  }
  // N4 (DESIGN S): the person designs their share. The card is drawn from the memo,
  // the Setting, the date and the themes; it is never given an amount.
  const SHARE_NAMES = { page: 'Page', setting: 'Setting', theme: 'Theme', words: 'Words', paper: 'Paper', night: 'Night', themeColor: 'Theme color', square: 'Square', tall: 'Tall', wide: 'Wide', cover: 'Cover', pages: 'Pages', lines: 'Lines', underline: 'Underline', double: 'Two lines', circle: 'Circle', highlight: 'Highlight' };
  const THEME_HEX = { clay: ['#A33E25', '#FCA48D'], persimmon: ['#964D09', '#FEA668'], ochre: ['#815C0A', '#E9B452'], olive: ['#686800', '#C3C55A'], moss: ['#2F751D', '#90D281'], sage: ['#1B735B', '#54D8B1'], teal: ['#157171', '#2AD7D7'], sky: ['#006D91', '#60CCFC'], slate: ['#2F60B2', '#98BFFE'], iris: ['#6451AC', '#BCB3FA'], plum: ['#8A428E', '#E8A0EC'], rose: ['#9D3A67', '#FF99C2'], stone: ['#6F6964', '#B3ACA6'] };
  const themeOf = (n) => { const [color, dark] = THEME_HEX[themeKey(n)] || THEME_HEX.stone; return { name: n, color, dark }; };
  // The pieces both studios share: a choice, a switch, the words, and sending.
  function sharePick(c, prefix, legend, key, values, draw) {
    return h('fieldset', { class: 'share-set' }, h('legend', {}, legend),
      h('div', { class: 'share-opts' }, values.map((v) => {
        const box = h('input', { type: 'radio', name: prefix + key, id: prefix + key + '-' + v, checked: c[key] === v });
        box.addEventListener('change', () => { c[key] = v; draw(); });
        return h('label', {}, box, key === 'paper' && v === 'theme' ? SHARE_NAMES.themeColor : SHARE_NAMES[v]);
      })));
  }
  function shareShow(c, prefix, key, label, draw) {
    const box = h('input', { type: 'checkbox', id: prefix + key, checked: c[key] });
    box.addEventListener('change', () => { c[key] = box.checked; draw(); });
    return h('label', {}, box, label);
  }
  // The words that matter are the person's choice: first word, then last.
  function shareWords(text, get, set, draw) {
    const box = h('div', { class: 'share-words' });
    function paint(focus) {
      fill(box, CentShare.wordsOf(text).flatMap((w, i) => {
        const m = get(), on = m && i >= Math.min(...m) && i <= Math.max(...m);
        const b = h('button', { type: 'button', 'aria-pressed': on ? 'true' : 'false' }, w);
        b.addEventListener('click', () => { const n = get(); set(!n || n[0] !== n[1] ? [i, i] : [n[0], i]); paint(i); draw(); });
        return [b, document.createTextNode(' ')];
      }));
      if (focus != null) box.querySelectorAll('button')[focus].focus();
    }
    const clear = h('button', { type: 'button', class: 'btn btn-small btn-quiet' }, 'No mark');
    clear.addEventListener('click', () => { set(null); paint(); draw(); });
    paint();
    return [box, clear];
  }
  function shareSend(card, status) {
    const send = h('button', { type: 'button', class: 'btn btn-primary' }, 'Share');
    send.addEventListener('click', async () => {
      const blob = await new Promise((r) => card.toBlob(r, 'image/png'));
      const file = new File([blob], 'centmemo.png', { type: 'image/png' });
      try {
        if (navigator.canShare && navigator.canShare({ files: [file] })) { await navigator.share({ files: [file] }); status.textContent = ''; }
        else {
          const a = h('a', { href: URL.createObjectURL(blob), download: 'centmemo.png' }); a.click();
          setTimeout(() => URL.revokeObjectURL(a.href), 1000); status.textContent = 'Saved to your downloads.';
        }
      } catch (_) { /* the person closed the share sheet */ }
    });
    return send;
  }
  const shareFonts = () => (document.fonts ? Promise.all([document.fonts.load('400 40px Newsreader'), document.fonts.load('600 40px Newsreader')]) : Promise.resolve()).catch(() => {});
  function sharePanel(t, memo) {
    const names = (memo.memo_values || []).map((v) => v.life_values && v.life_values.name).filter(Boolean);
    const data = { memo: memo.body, setting: merchantOf(t), initials: CentMoney.merchantInitials(merchantOf(t)), date: niceDate(t.txn_date),
      themes: names.map(themeOf) };
    const c = { look: 'page', shape: 'square', paper: 'paper', showSetting: true, showDate: true, showThemes: true, pencil: 'underline', mark: null };
    const card = h('canvas', { class: 'share-canvas', role: 'img' }), status = h('span', { class: 'caption', role: 'status' });
    const draw = () => { CentShare.draw(card, data, c); card.setAttribute('aria-label', SHARE_NAMES[c.look] + ' card: ' + data.memo); pencil.hidden = c.look === 'words'; };
    const pick = (legend, key, values) => sharePick(c, 'share-', legend, key, values, draw), show = (key, label) => shareShow(c, 'share-', key, label, draw);
    const pencil = pick('Pencil', 'pencil', CentShare.PENCILS);
    shareFonts().then(draw);
    return h('details', { class: 'share-panel' }, h('summary', {}, 'Share this memo'),
      h('div', { class: 'share-studio' }, h('div', { class: 'share-stage' }, card),
        h('div', { class: 'share-choices' },
          h('fieldset', { class: 'share-set' }, h('legend', {}, 'Mark the words that matter'), shareWords(data.memo, () => c.mark, (m) => { c.mark = m; }, draw)),
          pencil, pick('Look', 'look', CentShare.LOOKS), pick('Paper', 'paper', CentShare.PAPERS.filter((p) => p !== 'theme' || data.themes.length)), pick('Shape', 'shape', Object.keys(CentShare.SHAPES)),
          h('fieldset', { class: 'share-set' }, h('legend', {}, 'Show'), h('div', { class: 'share-opts' }, show('showSetting', 'Where'), show('showDate', 'When'), data.themes.length ? show('showThemes', 'Themes') : null)),
          h('div', { class: 'actions' }, shareSend(card, status), status))));
  }
  // N4 (DESIGN S6): a whole theme. Any memo can be left out; Lines is made of the
  // words the person underlines in each. Never an amount.
  function shareThemePanel(themeName, rows) {
    const memoOf = (t) => (Array.isArray(t.memos) ? t.memos[0] : t.memos) || {};
    const all = rows.map((t) => ({ memo: memoOf(t).body, setting: merchantOf(t), day: t.txn_date, date: niceDate(t.txn_date), mark: null, on: true }));
    const c = { look: 'cover', shape: 'square', paper: 'paper', showSetting: true, showDate: true, pencil: 'underline' };
    const card = h('canvas', { class: 'share-canvas', role: 'img' }), status = h('span', { class: 'caption', role: 'status' });
    const draw = () => {
      const memos = all.filter((m) => m.on), days = memos.map((m) => m.day).sort();
      const span = !days.length ? '' : days[0] === days[days.length - 1] ? niceDate(days[0]) : niceDate(days[0]) + ' to ' + niceDate(days[days.length - 1]);
      CentShare.drawTheme(card, { theme: themeOf(themeName), span, memos }, c);
      card.setAttribute('aria-label', themeName + ': ' + memos.map((m) => m.memo).join(' '));
      pencil.hidden = c.look !== 'pages';
    };
    const pick = (legend, key, values) => sharePick(c, 'share-theme-', legend, key, values, draw), show = (key, label) => shareShow(c, 'share-theme-', key, label, draw);
    const pencil = pick('Pencil', 'pencil', CentShare.PENCILS);
    const picks = all.map((m, i) => {
      const box = h('input', { type: 'checkbox', id: 'share-theme-' + i, checked: true });
      const words = h('div', { class: 'share-memo-words' }, shareWords(m.memo, () => m.mark, (v) => { m.mark = v; }, draw));
      box.addEventListener('change', () => { m.on = box.checked; words.hidden = !m.on; draw(); });
      return h('div', { class: 'share-memo' }, h('label', { class: 'filter-check' }, box, ' ' + m.setting + ', ' + m.date), words);
    });
    shareFonts().then(draw);
    return h('details', { class: 'share-panel', 'data-share-theme': '' }, h('summary', {}, 'Share this theme'),
      h('div', { class: 'share-studio' }, h('div', { class: 'share-stage' }, card),
        h('div', { class: 'share-choices' },
          pick('Look', 'look', CentShare.THEME_LOOKS), pencil, pick('Paper', 'paper', CentShare.PAPERS), pick('Shape', 'shape', Object.keys(CentShare.SHAPES)),
          h('fieldset', { class: 'share-set' }, h('legend', {}, 'Show'), h('div', { class: 'share-opts' }, show('showSetting', 'Where'), show('showDate', 'When'))),
          h('fieldset', { class: 'share-set' }, h('legend', {}, 'Mark the words that matter'), picks),
          h('div', { class: 'actions' }, shareSend(card, status), status))));
  }
  /* ---- Make a link (DESIGN S7): every choice is the writer's, beside the reader's page ---- */
  function linkPanel(kind, rows, theme) {
    const memoOf = (t) => (Array.isArray(t.memos) ? t.memos[0] : t.memos) || {};
    const all = rows.slice(0, 100).map((t) => ({ txn: t.id, memo: memoOf(t).body, shown: merchantOf(t), shownWhen: niceDate(t.txn_date), place: '', when: '', mark: null, on: true, wallet: true }));
    const d = { paper: 'bold', pencil: 'underline', lead: 'memory', place: true, when: true, theme: true, cover: true, lines: true, mems: true };
    const page = h('div', { class: 'sp' }), status = h('p', { class: 'caption', role: 'status' }), made = h('div', { class: 'link-made' });
    const say = { from: '' };
    const on = () => all.filter((m) => m.on);
    function draw() {
      go.disabled = false;
      const items = on().map((m) => ({ memo: m.memo, place: d.place && m.place.trim() || null, when: d.when && m.when.trim() || null, mark: m.mark && [Math.min(...m.mark), Math.max(...m.mark)] }));
      CentStory.render(page, { kind, theme: theme && (kind === 'theme' || d.theme) ? { name: theme.name } : null, from: say.from.trim() || null, items, design: { ...d, color: theme ? themeKey(theme.name) : 'clay' } });
    }
    const pick = (legend, key, values) => h('fieldset', { class: 'share-set' }, h('legend', {}, legend), h('div', { class: 'share-opts' }, values.map(([v, label]) => {
      const box = h('input', { type: 'radio', name: 'link-' + key, id: 'link-' + key + '-' + v, checked: d[key] === v });
      box.addEventListener('change', () => { d[key] = v; draw(); });
      return h('label', {}, box, label);
    })));
    const check = (key, label) => { const box = h('input', { type: 'checkbox', id: 'link-' + key, checked: d[key] }); box.addEventListener('change', () => { d[key] = box.checked; draw(); }); return h('label', {}, box, label); };
    const field = (id, label, value, set, hint, max) => { const i = h('input', { type: 'text', id, class: 'field-input', value, maxlength: max, placeholder: hint, autocomplete: 'off' }); i.addEventListener('input', () => { set(i.value); draw(); }); return h('div', { class: 'link-field' }, h('label', { class: 'field-label', for: id }, label), i); };
    const choices = h('div', { class: 'share-choices' });
    function build() {
      const anyWallet = all.some((m) => m.wallet);
      fill(choices,
        h('fieldset', { class: 'share-set' }, h('legend', {}, 'Mark the words that matter'), all.map((m, i) => {
          const body = h('div', {}, shareWords(m.memo, () => m.mark, (v) => { m.mark = v; }, draw),
            field('link-place-' + i, 'Where', m.place, (v) => { m.place = v; }, 'The place, in your words', 80),
            field('link-when-' + i, 'When', m.when, (v) => { m.when = v; }, 'A date, a season, or nothing', 60));
          if (kind === 'memo') return body;
          const box = h('input', { type: 'checkbox', id: 'link-on-' + i, checked: true });
          box.addEventListener('change', () => { m.on = box.checked; body.hidden = !m.on; draw(); });
          return h('div', { class: 'share-memo' }, h('label', { class: 'filter-check' }, box, ' ' + m.shown + ', ' + m.shownWhen), body);
        })),
        anyWallet ? h('p', { class: 'caption' }, 'For Apple Card purchases, Where and When start empty. Apple’s rules don’t let CentMemo publish the store or the date, so you write them.') : null,
        pick('Pencil', 'pencil', [['underline', 'Underline'], ['double', 'Two lines'], ['circle', 'Circle'], ['highlight', 'Highlight']]),
        pick('Color', 'paper', [['bold', 'Bold'], ['paper', 'Paper'], ['night', 'Night']]),
        kind === 'memo' ? pick('What leads', 'lead', [['memory', 'The memory'], ['setting', 'The place']].concat(theme ? [['theme', 'The theme']] : []))
          : h('fieldset', { class: 'share-set' }, h('legend', {}, 'Parts of the page'), h('div', { class: 'share-opts' }, check('cover', 'Cover'), check('lines', 'Lines'), check('mems', 'Each memory'))),
        h('fieldset', { class: 'share-set' }, h('legend', {}, 'Show'), h('div', { class: 'share-opts' }, check('place', 'Where'), check('when', 'When'), kind === 'memo' && theme ? check('theme', 'Theme') : null)),
        field('link-from', 'Shared by', say.from, (v) => { say.from = v; }, 'Your name, or nothing', 60),
        h('p', { class: 'caption' }, 'Anyone with the link can read this page. It isn’t listed anywhere, and you can turn it off in Settings.'),
        h('div', { class: 'actions' }, go), status, made);
    }
    const go = h('button', { type: 'button', class: 'btn btn-primary' }, 'Make the link');
    go.addEventListener('click', async () => {
      const items = on();
      if (!items.length) { status.textContent = 'Choose at least one memo.'; return; }
      if (kind === 'theme' && !d.cover && !d.lines && !d.mems) { status.textContent = 'Choose at least one part of the page.'; return; }
      go.disabled = true; status.textContent = 'Making the link…';
      try {
        const code = await API.makeShare(kind, items.map((m) => ({ txn: m.txn, place: m.place, when: m.when, mark: m.mark })), { ...d, color: theme ? themeKey(theme.name) : 'clay' }, theme && theme.id, say.from);
        const url = location.origin + '/s/#' + code, copy = h('button', { type: 'button', class: 'btn btn-small' }, 'Copy');
        copy.addEventListener('click', async () => { try { await navigator.clipboard.writeText(url); copy.textContent = 'Copied'; } catch (_) { copy.textContent = 'Select and copy'; } });
        status.textContent = 'Your link is ready.';
        fill(made, h('div', { class: 'inline-form' }, h('a', { class: 'link-url', href: url, target: '_blank', rel: 'noopener' }, url), copy));
      } catch (err) { status.textContent = err.message; go.disabled = false; }
    });
    const panel = h('details', { class: 'share-panel link-panel' }, h('summary', {}, kind === 'theme' ? 'Make a link to this theme' : 'Make a link to this memo'),
      h('div', { class: 'share-studio' }, h('div', { class: 'link-stage' }, page), choices));
    let opened = false;
    panel.addEventListener('toggle', async () => {
      if (!panel.open || opened) return;
      opened = true; build(); draw();
      try {
        // Only what is not Apple's to publish may be filled in for the writer.
        const wallet = await API.walletIds(all.map((m) => m.txn));
        for (const m of all) { m.wallet = wallet.has(m.txn); if (!m.wallet) { m.place = m.shown; m.when = m.shownWhen; } }
        build(); draw();
      } catch (_) { /* they stay empty, the safe way round */ }
    });
    return panel;
  }
  function fact(k, v) { return h('div', {}, h('dt', {}, k), h('dd', {}, v)); }
  // Back walks the app's own history (a Setting opened from an event returns to
  // it); a page reached directly goes to the last list instead.
  document.querySelectorAll('[data-back]').forEach((b) => b.addEventListener('click', () => {
    if ((history.state && history.state.depth) > 1) history.back(); else location.hash = lastList;
  }));

  // Photos are attached on the iPhone by PhotoKit reference (money-story-design);
  // the web cannot draw them, so it says they exist and where they live.
  // Item 10: files the person added on the iPhone, kept privately; each opens
  // through a link that lasts an hour.
  function filesList(list) {
    const files = (list || []).filter((a) => a.kind === 'file' && a.storage_path);
    if (!files.length) return null;
    const ul = h('ul', { class: 'files-list', 'data-files': '' }, files.map((a) => h('li', { 'data-file': a.storage_path }, a.caption || 'File')));
    API.copyUrls(files.map((a) => a.storage_path)).then((urls) => {
      ul.querySelectorAll('[data-file]').forEach((li) => {
        const url = urls[li.dataset.file];
        if (url) fill(li, h('a', { href: url, target: '_blank', rel: 'noopener' }, li.textContent));
      });
    }).catch(() => {});
    return h('div', {}, h('p', { class: 'field-label' }, 'Files'), ul);
  }
  function photosNote(list) {
    const photos = (list || []).filter((a) => a.kind === 'photo');
    if (!photos.length) return null;
    // Item 10: copies the person chose to keep show here; the rest live on the iPhone.
    const kept = photos.filter((a) => a.storage_path);
    const onPhone = photos.length - kept.length;
    const grid = h('div', { class: 'photo-copies', 'data-photo-copies': '' });
    if (kept.length) {
      API.copyUrls(kept.map((a) => a.storage_path)).then((urls) => fill(grid, ...kept.filter((a) => urls[a.storage_path])
        .map((a) => h('img', { src: urls[a.storage_path], alt: 'A photo attached to this memo', loading: 'lazy' })))).catch(() => {});
    }
    return h('div', {}, kept.length ? grid : null,
      onPhone ? h('p', { class: 'caption photos-note' }, onPhone === 1 ? '1 photo attached in the CentMemo iPhone app.' : onPhone + ' photos attached in the CentMemo iPhone app.') : null);
  }


  /* ---- Story: the memos, read in order ---- */
  // Kept by reference: it is drawn inside the Story's shelf each time.
  const STORY_CONTROLS = document.querySelector('.story-controls');
  async function storyView(scope) {
    const body = showView('story', 'story');
    const controls = STORY_CONTROLS, select = controls.querySelector('select');
    loading(body);
    try {
      const vals = await API.values();
      const counts = await API.themeCounts().catch(() => ({}));
      const latest = (await API.latestMonth()) || thisMonth();
      if (!scope) scope = latest;
      const months = [];
      for (let ym = latest, i = 0; i < 24; i++, ym = stepMonth(ym, -1)) months.push(ym);
      if (/^\d{4}-\d{2}$/.test(scope) && !months.includes(scope)) months.unshift(scope);
      fill(select, 
        months.map((ym) => h('option', { value: ym, selected: scope === ym }, monthName(ym))));
      select.onchange = () => { location.hash = '#/story/' + encodeURIComponent(select.value); };

      const valueId = scope.startsWith('value:') ? scope.slice(6) : null;
      // Themes have their own shelf below; the picker is for months (as on the iPhone).
      controls.hidden = !!valueId;
      const rows = await API.stories(valueId ? { valueId } : { ym: scope });
      const title = valueId ? (vals.find((v) => v.id === valueId) || {}).name || 'Theme' : monthName(scope);
      $('h-story').textContent = 'Story';
      // D12 (Decision 065): Themes are the Story's collections, as on the iPhone.
      const shelfVals = vals.filter((v) => counts[v.id]);
      const shelf = shelfVals.length ? h('nav', { class: 'theme-shelf', 'aria-label': 'Themes' },
        h('p', { class: 'field-label' }, 'Themes'),
        shelfVals.map((v) => h('a', { class: 'theme-row', href: valueId === v.id ? '#/story/' + latest : '#/story/value:' + v.id,
          'aria-current': valueId === v.id ? 'true' : null, 'data-theme': v.name },
          h('i', { style: 'background: ' + themeHue(v.name) }), h('span', {}, v.name), h('span', { class: 'caption' }, String(counts[v.id])))),
        valueId ? h('a', { class: 'theme-row every', href: '#/story/' + latest }, 'Every memo') : null) : '';
      const none = rows.length ? null : h('div', { class: 'state state-empty' },
        h('p', {}, valueId ? 'No memos carry this theme yet.' : 'No memos written for ' + title + '.'),
        h('a', { class: 'btn', href: '#/unexamined' }, 'Write a memo'));
      // W4: the shelf on the left, the memos as one column to read.
      fill(body, split([controls, shelf], none || [
        h('header', { class: 'story-head' },
          h('h2', { class: 'section-heading' }, title),
          h('p', { class: 'caption' }, rows.length + (rows.length === 1 ? ' memo' : ' memos'))),
        valueId ? shareThemePanel(title, rows) : '',
        valueId ? linkPanel('theme', rows, { name: title, id: valueId }) : '',
        h('ol', { class: 'story' }, rows.map((t) => {
          const memo = Array.isArray(t.memos) ? t.memos[0] : t.memos;
          const names = (memo.memo_values || []).map((mv) => mv.life_values && mv.life_values.name).filter(Boolean);
          // D6: the memo is the headline; when, where and how much are its footnote.
          return h('li', { class: 'story-entry' },
            h('p', { class: 'story-text' }, memo.body),
            names.length ? h('p', { class: 'chips chips-static' }, names.map((n) => h('span', { class: 'chip' }, n))) : null,
            h('a', { class: 'story-meta', href: '#/t/' + t.id },
              h('span', {}, niceDate(t.txn_date) + ' · ' + merchantOf(t)),
              h('span', { class: 'row-amount' }, money(t.amount_minor, t.currency))));
        }))]));
    } catch (err) { failed(body, err, () => storyView(scope)); }
  }

  /* ---- Import ---- */
  function importView() {
    const body = showView('import', 'import');
    if (!body.childElementCount) fill(body);
  }
  $('import-file').addEventListener('change', async (e) => {
    const file = e.target.files && e.target.files[0];
    const body = $('view-import').querySelector('[data-body]');
    if (!file) return;
    loading(body);
    let rows, kind;
    try {
      ({ kind, rows } = await M.parseAnyExport(await file.text()));
    } catch (err) { e.target.value = ''; return failed(body, err); }
    if (!rows.length) { e.target.value = ''; return empty(body, 'That export has no purchases in it.'); }
    const dates = rows.map((r) => r.txn_date).sort();
    const spent = rows.filter((r) => r.amount_minor < 0).reduce((a, r) => a - r.amount_minor, 0);
    const NAMES = { applecard: 'Apple Card', venmo: 'Venmo', paypal: 'PayPal', cashapp: 'Cash App' };
    const go = h('button', { class: 'btn btn-primary' }, 'Import ' + rows.length + ' ' + NAMES[kind] + ' events');
    const status = h('p', { class: 'caption', role: 'status' });
    go.addEventListener('click', async () => {
      go.disabled = true; status.textContent = 'Importing…';
      try {
        const r = await API.importExport(kind, rows, file.name);
        e.target.value = '';
        fill(body, h('div', { class: 'state' },
          h('p', {}, r.inserted + ' new' + (r.skipped ? ', ' + r.skipped + ' already in CentMemo.' : '.')),
          h('a', { class: 'btn btn-primary', href: '#/unexamined' }, 'Start writing')));
      } catch (err) { go.disabled = false; status.textContent = ''; failed(body, err); }
    });
    fill(body, 
      h('dl', { class: 'totals' },
        h('div', {}, h('dt', {}, 'Events'), h('dd', {}, String(rows.length))),
        h('div', {}, h('dt', {}, 'From'), h('dd', {}, niceDate(dates[0]))),
        h('div', {}, h('dt', {}, 'To'), h('dd', {}, niceDate(dates[dates.length - 1]))),
        h('div', {}, h('dt', {}, 'Spent'), h('dd', {}, money(spent)))),
      h('div', { class: 'actions' }, go, status));
  });

  /* ---- Ground ---- */
  function applyGround(id) {
    if (id && id !== 'aqua') document.documentElement.setAttribute('data-ground', id);
    else document.documentElement.removeAttribute('data-ground');
    try { localStorage.setItem('cm_ground', id || 'aqua'); } catch (_) {}
  }

  /* ---- Settings ---- */
  async function settingsView() {
    const body = showView('settings', 'settings');
    loading(body);
    try {
      const [vals, session, current] = await Promise.all([API.values(), API.session(), API.ground()]);
      const picker = h('div', { class: 'grounds', role: 'group', 'aria-label': 'Color' }, API.GROUNDS.map((g) => {
        const b = h('button', { type: 'button', class: 'ground-swatch', 'aria-pressed': g.id === current ? 'true' : 'false' },
          h('i', { style: 'background:' + g.hex }), h('span', {}, g.name));
        b.addEventListener('click', async () => {
          picker.querySelectorAll('.ground-swatch').forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
          applyGround(g.id);
          try { await API.setGround(g.id); } catch (err) { failed(body, err, settingsView); }
        });
        return b;
      }));
      const valueList = h('ul', { class: 'list' }, vals.map((v) => {
        const input = h('input', { type: 'text', class: 'field-input field-inline', value: v.name, maxlength: '60', 'aria-label': 'Theme name' });
        const rename = h('button', { class: 'btn btn-small' }, 'Rename');
        const del = h('button', { class: 'btn btn-small btn-quiet' }, 'Remove');
        rename.addEventListener('click', async () => { try { await API.renameValue(v.id, input.value); rename.textContent = 'Renamed'; } catch (err) { failed(body, err, settingsView); } });
        del.addEventListener('click', async () => {
          if (del.dataset.confirm !== '1') { del.dataset.confirm = '1'; del.textContent = 'Remove from all memos'; return; }
          try { await API.deleteValue(v.id); settingsView(); } catch (err) { failed(body, err, settingsView); }
        });
        return h('li', { class: 'row row-static' }, h('i', { class: 'theme-mark', style: 'background: ' + themeHue(v.name) }), input, rename, del);
      }));

      const copy = h('button', { class: 'btn btn-small' }, 'Copy');
      copy.addEventListener('click', async () => { try { await navigator.clipboard.writeText(API.MCP_URL); copy.textContent = 'Copied'; } catch (_) { copy.textContent = 'Select and copy'; } });

      const del = h('button', { class: 'btn btn-danger' }, 'Delete account');
      const delNote = h('p', { class: 'caption', role: 'status' });
      del.addEventListener('click', async () => {
        if (del.dataset.confirm !== '1') {
          del.dataset.confirm = '1'; del.textContent = 'Delete everything, permanently';
          delNote.textContent = 'This removes every event, memo, and theme, and cannot be undone.';
          return;
        }
        del.disabled = true; delNote.textContent = 'Deleting…';
        try { await API.deleteAccount(); location.hash = ''; showAuth('Your account and everything in it is deleted.'); }
        catch (err) { del.disabled = false; delNote.textContent = err.message; }
      });

      fill(body, sections([
        h('h2', { class: 'section-heading' }, 'Color'),
        picker,
        h('h2', { class: 'section-heading' }, 'Themes'),
        vals.length ? valueList : h('p', { class: 'caption' }, 'Add a theme from any memo.'),
        (() => {
          const rows = starterRows(vals, async (t, btn) => {
            btn.disabled = true;
            try { await API.addValue(t.name); settingsView(); } catch (err) { btn.disabled = false; failed(body, err, settingsView); }
          });
          return rows.length ? h('div', {}, h('p', { class: 'field-label' }, 'Starter themes'), h('ul', { class: 'list starters' }, rows)) : '';
        })(),
        h('h2', { class: 'section-heading' }, 'Your links'),
        linksBox(),
        h('h2', { class: 'section-heading' }, 'Connect Claude'),
        h('p', {}, 'Claude can read your Narrative and memos, but can never change them. In Claude, open Settings, then Connectors, then Add custom connector, and paste:'),
        h('div', { class: 'inline-form' }, h('code', { class: 'code-line' }, API.MCP_URL), copy),
        h('h2', { class: 'section-heading' }, 'Account'),
        h('p', {}, session && session.user ? session.user.email : ''),
        h('div', { class: 'actions' }, h('button', { class: 'btn', onclick: async () => { await API.signOut(); showAuth(); } }, 'Sign out'), del),
        delNote,
        h('p', { class: 'caption' }, h('a', { href: 'privacy/' }, 'Privacy'), ' · ', h('a', { href: 'terms/' }, 'Terms'))]));
    } catch (err) { failed(body, err, settingsView); }
  }

  // Loads by itself, so a slow answer never holds up the rest of Settings.
  function linksBox() {
    const box = h('div', { id: 'your-links' });
    const load = async () => {
      fill(box, h('p', { class: 'caption', role: 'status' }, 'Loading…'));
      try { fill(box, linksList(await API.shares())); }
      catch (_) {
        const again = h('button', { type: 'button', class: 'btn btn-small' }, 'Try again');
        again.addEventListener('click', load);
        fill(box, h('p', { class: 'caption', role: 'alert' }, navigator.onLine ? 'CentMemo couldn’t load your links.' : 'You’re offline.'), again);
      }
    };
    load();
    return box;
  }
  // Every link the person made, each turned off at once.
  function linksList(list) {
    if (!list.length) return h('p', { class: 'caption' }, 'None. Make one from a memo or a theme.');
    return h('ul', { class: 'list' }, list.map((l) => {
      const off = h('button', { type: 'button', class: 'btn btn-small' }, 'Turn off');
      const li = h('li', { class: 'row row-static link-row' }, h('span', { class: 'row-main' }, h('a', { class: 'row-title', href: '/s/#' + l.code, target: '_blank', rel: 'noopener' }, l.title),
        h('span', { class: 'row-sub' }, 'Made ' + niceDate(l.created_at.slice(0, 10)))), off);
      off.addEventListener('click', async () => { off.disabled = true; try { await API.turnOffShare(l.code); li.querySelector('.row-sub').textContent = 'Off'; off.remove(); } catch (err) { off.disabled = false; off.textContent = 'Try again'; } });
      return li;
    }));
  }

  /* ---- Auth ---- */
  function showAuth(message) {
    $('app-screen').hidden = true;
    $('auth-screen').hidden = false;
    const sent = $('auth-sent');
    sent.hidden = !message; sent.textContent = message || '';
  }
  function showApp() {
    API.ground().then(applyGround).catch(() => {});
    $('auth-screen').hidden = true;
    $('app-screen').hidden = false;
    updateOnline();
    route();
  }
  $('auth-apple').addEventListener('click', async () => {
    const err = $('auth-error'), btn = $('auth-apple');
    err.hidden = true; $('auth-sent').hidden = true;
    btn.disabled = true;
    try { await API.signInWithApple('https://centmemo.com/'); }
    catch (ex) { err.textContent = ex.message; err.hidden = false; }
    btn.disabled = false;
  });

  window.addEventListener('hashchange', () => { if (!$('app-screen').hidden) route(); });

  async function start() {
    buildTabs();
    try {
      // A return from Apple's same-window sign-in carries a token in the hash,
      // which the router would read as a route: finish it first.
      await API.finishAppleRedirect();
    } catch (err) {
      const e = $('auth-error'); e.textContent = err.message; e.hidden = false;
    }
    try {
      const s = await API.session();
      if (s) showApp(); else showAuth();
      API.onAuthChange((session) => {
        if (session && $('app-screen').hidden) showApp();
        if (!session && !$('app-screen').hidden) showAuth();
      });
    } catch (err) {
      showAuth();
      const e = $('auth-error'); e.textContent = err.message; e.hidden = false;
    }
  }
  start();
})();
