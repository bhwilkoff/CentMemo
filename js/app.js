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
  function loading(body) { body.replaceChildren(h('p', { class: 'state state-loading', role: 'status' }, 'Loading…')); }
  function empty(body, text, action) { body.replaceChildren(h('div', { class: 'state state-empty' }, h('p', {}, text), action || null)); }
  function failed(body, err, retry) {
    body.replaceChildren(h('div', { class: 'banner banner-error', role: 'alert' },
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
      nav.replaceChildren(...TABS.map((t) => h('a', { class: 'tab', href: t.href, 'data-tab': t.id }, icon(t.icon), h('span', {}, t.label))));
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
        h('span', { class: 'row-sub' }, [niceDate(t.txn_date), catOf(t), t.status === 'pending' ? 'Pending' : null].filter(Boolean).join(' · ')),
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
      h('span', { class: 'suggestion-place' }, tile(t), h('span', { class: 'caption' }, merchantOf(t) + ' · ' + niceDate(t.txn_date)),
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
    another.addEventListener('click', () => { shown = (shown + 1) % out.length; box.replaceChildren(out[shown], another); });
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
          : empty(body, 'Nothing in your Narrative yet.', h('a', { class: 'btn btn-primary', href: '#/import' }, 'Import from Apple Card'));
      }
      // D7: one invitation at a time, "Another" for the next of up to three; no
      // count of what is left (as the iPhone's SuggestionCard).
      const picks = await suggestionCards(rows).catch(() => []);
      body.replaceChildren(picks.length === 1 ? h('div', { class: 'suggestions' }, picks) : picks.length ? picks[0] : '',
        h('div', { class: 'list' }, rows.map((t) => txnRow(t))),
        count > rows.length ? h('p', { class: 'caption' }, 'Showing the newest ' + rows.length + '.') : null);
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
  const themeHue = (name) => {
    const k = String(name || '').trim().toLowerCase();
    const c = THEME_COLORS[k] || (CentThemes.STARTERS.find((s) => s.name.toLowerCase() === k) || {}).color
      || CentThemes.PALETTE[CentMoney.merchantHue(k, CentThemes.PALETTE.length)];
    return 'var(--color-theme-' + c + ')';
  };
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
    const draw = () => thread.replaceChildren(...narrativeFilter(rows).map(threadRow));
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
    return h('div', {},
      h('div', { class: 'filters', role: 'group', 'aria-label': 'Filter the Narrative' }, show, names.length ? theme : null,
        quiet ? h('label', { class: 'filter-check' }, details, ' ' + quiet + ' deposits and interest') : null),
      thread);
  }

  /* ---- The Narrative as a thread (D10), as on the iPhone's ThreadRow ---- */
  // On a Setting's own page (place: false) the rows leave out the place.
  function threadRow(t, opts) {
    const place = !(opts && opts.place === false);
    const memo = t.memos && (Array.isArray(t.memos) ? t.memos[0] : t.memos);
    const meta = niceDate(t.txn_date) + (place ? ' · ' + merchantOf(t) : '');
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
      body.replaceChildren(
        h('dl', { class: 'totals' },
          h('div', {}, h('dt', {}, 'Spent'), h('dd', {}, money(spent))),
          h('div', {}, h('dt', {}, 'Paid or credited'), h('dd', {}, money(received))),
          h('div', {}, h('dt', {}, 'Memos'), h('dd', {}, written + ' of ' + rows.length))),
        monthStrip(rows),
        narrativeFilters(rows),
        rows.some((t) => t.skipped_at)
          ? h('details', { class: 'skipped' }, h('summary', {}, rows.filter((t) => t.skipped_at).length + ' skipped'),
              h('div', { class: 'list' }, rows.filter((t) => t.skipped_at).map((t) => txnRow(t))))
          : null);
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
      if (!t) return empty(body, 'This event is not in your CentMemo.');
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
        chips.replaceChildren(...list.map((v) => {
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
      body.replaceChildren(
        h('div', { class: 'txn-head' },
          tile(t, true),
          h('div', { class: 'txn-title' },
            h('h1', { id: 'h-txn', class: 'view-heading' }, merchantOf(t)),
            h('p', { class: 'caption' }, niceDate(t.txn_date) + ' · ',
              h('a', { href: '#/setting/' + encodeURIComponent(placeKey(t)), 'data-setting': '' }, 'Every visit')),
            placeLine(await API.settingPlaces().then((p) => p[placeKey(t)]).catch(() => null)))),
        h('label', { class: 'field-label', for: 'memo-body' }, 'Memo'),
        area,
        h('p', { class: 'field-label' }, 'Themes'),
        chips,
        h('div', { class: 'inline-form' }, newValue, addBtn),
        error,
        h('div', { class: 'actions' }, save, status, skipBtn),
        photosNote(t.attachments) || '',
        filesList(t.attachments) || '',
        memo && memo.body ? sharePanel(t, memo) : '',
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
            t.description && t.description !== t.merchant ? fact('Statement', t.description) : null)));
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
      body.replaceChildren(
        h('div', { class: 'txn-head' }, tile(rows[0], true),
          h('div', { class: 'txn-title' },
            heading,
            h('p', { class: 'caption', 'data-setting-summary': '' },
              [rows.length === 1 ? '1 visit' : rows.length + ' visits', rows.length > 1 ? 'since ' + niceDate(first) : null,
                written ? (written === 1 ? '1 memo' : written + ' memos') : null].filter(Boolean).join(' · ')),
            shown !== name ? h('p', { class: 'caption' }, 'On the statement: ' + name) : null,
            placeLine(await API.settingPlaces().then((p) => p[name]).catch(() => null)),
            rename)),
        h('div', { class: 'thread' }, rows.map((t) => threadRow(t, { place: false }))));
    } catch (err) { failed(body, err, () => settingView(name)); }
  }
  // D15: a confirmed place, as words and a link that opens Apple Maps there.
  function placeLine(p) {
    if (!p) return null;
    const href = 'https://maps.apple.com/?ll=' + p.lat.toFixed(6) + ',' + p.lon.toFixed(6) + '&q=' + encodeURIComponent(p.name);
    return h('p', { class: 'place-line', 'data-place': '' },
      h('a', { href, target: '_blank', rel: 'noopener' }, p.name), p.address ? h('span', { class: 'caption' }, ' · ' + p.address) : null);
  }
  // D12: share a memo as a card; private by default (as the iPhone's ShareMemoSheet).
  function sharePanel(t, memo) {
    const theme = ((memo.memo_values || [])[0] || {}).life_values;
    const where = h('input', { type: 'checkbox', id: 'share-where' });
    const line = h('span', { class: 'share-line' });
    const status = h('span', { class: 'caption', role: 'status' });
    const text = () => [niceDate(t.txn_date), where.checked ? merchantOf(t) : null].filter(Boolean).join(' · ');
    const draw = () => { line.textContent = text(); };
    where.addEventListener('change', draw); draw();
    const send = h('button', { type: 'button', class: 'btn' }, 'Share');
    send.addEventListener('click', async () => {
      const body = memo.body + '\n' + (theme ? theme.name + ' · ' : '') + text() + '\nCentMemo';
      try {
        if (navigator.share) { await navigator.share({ text: body }); status.textContent = ''; }
        else { await navigator.clipboard.writeText(body); status.textContent = 'Copied.'; }
      } catch (_) { /* the person closed the share sheet */ }
    });
    return h('details', { class: 'share-panel' }, h('summary', {}, 'Share this memo'),
      h('figure', { class: 'share-card' }, h('blockquote', {}, memo.body),
        theme ? h('span', { class: 'share-theme' }, h('i', { style: 'background: ' + themeHue(theme.name) }), theme.name) : null,
        line, h('span', { class: 'share-brand' }, 'CentMemo')),
      h('label', { class: 'filter-check' }, where, ' Show where'),
      h('p', { class: 'caption' }, 'Only the memo, its date, and its theme are shared unless you turn this on. Never the amount.'),
      h('div', { class: 'actions' }, send, status));
  }
  // D12: a whole theme as one card (as the iPhone's ShareThemeSheet): its memos,
  // any left out by the person; places off unless turned on, never an amount.
  function shareThemePanel(themeName, rows) {
    const where = h('input', { type: 'checkbox', id: 'share-theme-where' });
    const status = h('span', { class: 'caption', role: 'status' });
    const memoOf = (t) => (Array.isArray(t.memos) ? t.memos[0] : t.memos) || {};
    const picks = rows.map((t, i) => h('input', { type: 'checkbox', id: 'share-theme-' + i, checked: true }));
    const list = h('ol', { class: 'share-theme-list' });
    const lineOf = (t) => [niceDate(t.txn_date), where.checked ? merchantOf(t) : null].filter(Boolean).join(' · ');
    const chosen = () => rows.filter((_, i) => picks[i].checked);
    const draw = () => list.replaceChildren(...chosen().map((t) => h('li', {}, h('blockquote', {}, memoOf(t).body), h('span', { class: 'share-line' }, lineOf(t)))));
    [where, ...picks].forEach((b) => b.addEventListener('change', draw)); draw();
    const send = h('button', { type: 'button', class: 'btn' }, 'Share');
    send.addEventListener('click', async () => {
      const items = chosen();
      if (!items.length) { status.textContent = 'Choose at least one memo.'; return; }
      const body = themeName + '\n\n' + items.map((t) => memoOf(t).body + '\n' + lineOf(t)).join('\n\n') + '\n\nCentMemo';
      try {
        if (navigator.share) { await navigator.share({ text: body }); status.textContent = ''; }
        else { await navigator.clipboard.writeText(body); status.textContent = 'Copied.'; }
      } catch (_) { /* the person closed the share sheet */ }
    });
    return h('details', { class: 'share-panel', 'data-share-theme': '' }, h('summary', {}, 'Share this theme'),
      h('figure', { class: 'share-card' },
        h('span', { class: 'share-theme' }, h('i', { style: 'background: ' + themeHue(themeName) }), themeName),
        list, h('span', { class: 'share-brand' }, 'CentMemo')),
      h('p', { class: 'field-label' }, 'Memos on the card'),
      h('div', { class: 'share-picks' }, rows.map((t, i) => h('label', { class: 'filter-check' }, picks[i], ' ' + memoOf(t).body.slice(0, 60)))),
      h('label', { class: 'filter-check' }, where, ' Show where'),
      h('p', { class: 'caption' }, 'Only the theme, its memos, and their dates are shared unless you turn this on. Never the amounts.'),
      h('div', { class: 'actions' }, send, status));
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
        if (url) li.replaceChildren(h('a', { href: url, target: '_blank', rel: 'noopener' }, li.textContent));
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
      API.copyUrls(kept.map((a) => a.storage_path)).then((urls) => grid.replaceChildren(...kept.filter((a) => urls[a.storage_path])
        .map((a) => h('img', { src: urls[a.storage_path], alt: 'A photo attached to this memo', loading: 'lazy' })))).catch(() => {});
    }
    return h('div', {}, kept.length ? grid : null,
      onPhone ? h('p', { class: 'caption photos-note' }, onPhone === 1 ? '1 photo attached in the CentMemo iPhone app.' : onPhone + ' photos attached in the CentMemo iPhone app.') : null);
  }


  /* ---- Story: the memos, read in order ---- */
  async function storyView(scope) {
    const body = showView('story', 'story');
    const select = $('story-scope');
    loading(body);
    try {
      const vals = await API.values();
      const counts = await API.themeCounts().catch(() => ({}));
      const latest = (await API.latestMonth()) || thisMonth();
      if (!scope) scope = latest;
      const months = [];
      for (let ym = latest, i = 0; i < 24; i++, ym = stepMonth(ym, -1)) months.push(ym);
      if (/^\d{4}-\d{2}$/.test(scope) && !months.includes(scope)) months.unshift(scope);
      select.replaceChildren(
        months.map((ym) => h('option', { value: ym, selected: scope === ym }, monthName(ym))));
      select.onchange = () => { location.hash = '#/story/' + encodeURIComponent(select.value); };

      const valueId = scope.startsWith('value:') ? scope.slice(6) : null;
      // Themes have their own shelf below; the picker is for months (as on the iPhone).
      select.closest('.story-controls').hidden = !!valueId;
      const rows = await API.stories(valueId ? { valueId } : { ym: scope });
      const title = valueId ? (vals.find((v) => v.id === valueId) || {}).name || 'Theme' : monthName(scope);
      $('h-story').textContent = 'Story';
      if (!rows.length) {
        return empty(body, valueId ? 'No memos carry this theme yet.' : 'No memos written for ' + title + '.',
          h('a', { class: 'btn', href: '#/unexamined' }, 'Write one'));
      }
      // D12 (Decision 065): Themes are the Story's collections, as on the iPhone.
      const shelfVals = vals.filter((v) => counts[v.id]);
      const shelf = shelfVals.length ? h('nav', { class: 'theme-shelf', 'aria-label': 'Themes' },
        h('p', { class: 'field-label' }, 'Themes'),
        shelfVals.map((v) => h('a', { class: 'theme-row', href: valueId === v.id ? '#/story/' + latest : '#/story/value:' + v.id,
          'aria-current': valueId === v.id ? 'true' : null, 'data-theme': v.name },
          h('i', { style: 'background: ' + themeHue(v.name) }), h('span', {}, v.name), h('span', { class: 'caption' }, String(counts[v.id])))),
        valueId ? h('a', { class: 'theme-row every', href: '#/story/' + latest }, 'Every memo') : null) : '';
      body.replaceChildren(
        shelf,
        h('header', { class: 'story-head' },
          h('h2', { class: 'section-heading' }, title),
          h('p', { class: 'caption' }, rows.length + (rows.length === 1 ? ' memo' : ' memos'))),
        valueId ? shareThemePanel(title, rows) : '',
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
        })));
    } catch (err) { failed(body, err, () => storyView(scope)); }
  }

  /* ---- Import ---- */
  function importView() {
    const body = showView('import', 'import');
    if (!body.childElementCount) body.replaceChildren();
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
        body.replaceChildren(h('div', { class: 'state' },
          h('p', {}, r.inserted + ' new' + (r.skipped ? ', ' + r.skipped + ' already in CentMemo.' : '.')),
          h('a', { class: 'btn btn-primary', href: '#/unexamined' }, 'Start writing')));
      } catch (err) { go.disabled = false; status.textContent = ''; failed(body, err); }
    });
    body.replaceChildren(
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

      body.replaceChildren(
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
        h('h2', { class: 'section-heading' }, 'Connect Claude'),
        h('p', {}, 'Claude can read your Narrative and memos, but can never change them. In Claude, open Settings, then Connectors, then Add custom connector, and paste:'),
        h('div', { class: 'inline-form' }, h('code', { class: 'code-line' }, API.MCP_URL), copy),
        h('h2', { class: 'section-heading' }, 'Account'),
        h('p', {}, session && session.user ? session.user.email : ''),
        h('div', { class: 'actions' }, h('button', { class: 'btn', onclick: async () => { await API.signOut(); showAuth(); } }, 'Sign out'), del),
        delNote,
        h('p', { class: 'caption' }, h('a', { href: 'privacy/' }, 'Privacy'), ' · ', h('a', { href: 'terms/' }, 'Terms')));
    } catch (err) { failed(body, err, settingsView); }
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
