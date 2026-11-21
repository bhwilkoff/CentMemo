/**
 * CentMemo web app. Vanilla JS (Decision 001), one IIFE.
 * Views are <section> elements; the hash is the route:
 *   #/unexamined  #/ledger/2026-11  #/t/<id>  #/story/<month|value:id>
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
  const merchantOf = (t) => t.merchant || t.description || 'Unknown';

  /* ---- Four states (universal-feature-states) ---- */
  function loading(body) { body.replaceChildren(h('p', { class: 'state state-loading', role: 'status' }, 'Loading…')); }
  function empty(body, text, action) { body.replaceChildren(h('div', { class: 'state state-empty' }, h('p', {}, text), action || null)); }
  function failed(body, err, retry) {
    body.replaceChildren(h('div', { class: 'banner banner-error', role: 'alert' },
      h('span', {}, navigator.onLine ? (err && err.message) || 'Something went wrong.' : 'You\'re offline.'),
      retry ? h('button', { class: 'btn btn-small', onclick: retry }, 'Try again') : null));
  }
  function updateOnline() { $('offline-banner').hidden = navigator.onLine; }
  window.addEventListener('online', updateOnline);
  window.addEventListener('offline', updateOnline);

  /* ---- Navigation ---- */
  const TABS = [
    { id: 'unexamined', label: 'Unexamined', icon: 'inbox', href: '#/unexamined' },
    { id: 'ledger', label: 'Ledger', icon: 'list', href: '#/ledger' },
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
  async function route() {
    const parts = (location.hash.replace(/^#\/?/, '') || 'unexamined').split('/');
    const [name, arg] = parts;
    try {
      if (name === 'ledger') { lastList = location.hash; return await ledgerView(arg); }
      if (name === 't' && arg) return await txnView(arg);
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
      h('span', { class: 'row-main' },
        h('span', { class: 'row-title' }, merchantOf(t)),
        h('span', { class: 'row-sub' }, [niceDate(t.txn_date), t.category, t.status === 'pending' ? 'Pending' : null].filter(Boolean).join(' · ')),
        opts && opts.memo && memo ? h('span', { class: 'row-memo' }, memo.body) : null),
      h('span', { class: 'row-amount' + (t.amount_minor > 0 ? ' is-credit' : '') }, money(t.amount_minor, t.currency)));
  }

  /* ---- Unexamined (home) ---- */
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
          : empty(body, 'No transactions yet.', h('a', { class: 'btn btn-primary', href: '#/import' }, 'Import from Apple Card'));
      }
      heading.replaceChildren('Unexamined ', h('span', { class: 'pencil-circle', 'aria-label': count + ' unexamined' },
        h('span', { class: 'yours-count' }, count.toLocaleString('en-US'))));
      body.replaceChildren(h('div', { class: 'list' }, rows.map((t) => txnRow(t))),
        count > rows.length ? h('p', { class: 'caption' }, 'Showing the newest ' + rows.length + '.') : null);
    } catch (err) { failed(body, err, unexaminedView); }
  }

  /* ---- Ledger ---- */
  async function ledgerView(ym) {
    const body = showView('ledger', 'ledger');
    if (!ym || !/^\d{4}-\d{2}$/.test(ym)) {
      ym = (await API.latestMonth().catch(() => null)) || thisMonth();
      history.replaceState(null, '', '#/ledger/' + ym);
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
        h('div', { class: 'list' }, rows.map((t) => txnRow(t, { memo: true }))));
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
      if (!t) return empty(body, 'This transaction is not in your CentMemo.');
      const memo = t.memos && (Array.isArray(t.memos) ? t.memos[0] : t.memos);
      const chosen = new Set(memo ? (memo.memo_values || []).map((v) => v.value_id) : []);
      const area = h('textarea', { id: 'memo-body', class: 'field-input memo-input', rows: '6', maxlength: '10000' });
      area.value = memo ? memo.body : '';
      const status = h('p', { class: 'caption', role: 'status' });
      const error = h('div', { class: 'banner banner-error', role: 'alert', hidden: true });

      const chips = h('div', { class: 'chips', role: 'group', 'aria-label': 'Values' });
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
      const newValue = h('input', { type: 'text', class: 'field-input field-inline', maxlength: '60', 'aria-label': 'New value' });
      const addBtn = h('button', { type: 'button', class: 'btn btn-small' }, 'Add value');
      addBtn.addEventListener('click', async () => {
        const name = newValue.value.trim();
        if (!name) return newValue.focus();
        try {
          const v = await API.addValue(name);
          vals.push(v); vals.sort((a, b) => a.name.localeCompare(b.name));
          chosen.add(v.id); newValue.value = ''; drawChips(vals);
        } catch (err) { error.textContent = /duplicate|unique/i.test(err.message) ? 'You already have that value.' : err.message; error.hidden = false; }
      });

      const save = h('button', { type: 'button', class: 'btn btn-primary' }, 'Save');
      save.addEventListener('click', async () => {
        error.hidden = true;
        if (!area.value.trim() && chosen.size) { error.textContent = 'Write the memo first; values belong to a memo.'; error.hidden = false; return; }
        save.disabled = true; status.textContent = 'Saving…';
        try {
          await API.saveMemo(t.id, area.value, [...chosen]);
          status.textContent = area.value.trim() ? 'Saved.' : 'Memo removed.';
        } catch (err) { status.textContent = ''; error.textContent = err.message; error.hidden = false; }
        save.disabled = false;
      });

      body.replaceChildren(
        h('div', { class: 'txn-head' },
          h('h1', { id: 'h-txn', class: 'view-heading' }, merchantOf(t)),
          h('p', { class: 'txn-amount' + (t.amount_minor > 0 ? ' is-credit' : '') }, money(t.amount_minor, t.currency))),
        h('dl', { class: 'facts' },
          fact('Date', niceDate(t.txn_date)),
          t.posted_date && t.posted_date !== t.txn_date ? fact('Posted', niceDate(t.posted_date)) : null,
          t.category ? fact('Category', t.category) : null,
          t.txn_type ? fact('Type', t.txn_type) : null,
          t.status !== 'booked' ? fact('Status', t.status) : null,
          t.accounts ? fact('Account', t.accounts.display_name) : null,
          t.description && t.description !== t.merchant ? fact('Statement', t.description) : null),
        h('label', { class: 'field-label', for: 'memo-body' }, 'Memo'),
        area,
        h('p', { class: 'field-label' }, 'Values'),
        chips,
        h('div', { class: 'inline-form' }, newValue, addBtn),
        error,
        h('div', { class: 'actions' }, save, status));
    } catch (err) { failed(body, err, () => txnView(id)); }
  }
  function fact(k, v) { return h('div', {}, h('dt', {}, k), h('dd', {}, v)); }
  document.querySelector('[data-back]').addEventListener('click', () => { location.hash = lastList; });

  /* ---- Story: the memos, read in order ---- */
  async function storyView(scope) {
    const body = showView('story', 'story');
    const select = $('story-scope');
    loading(body);
    try {
      const vals = await API.values();
      const latest = (await API.latestMonth()) || thisMonth();
      if (!scope) scope = latest;
      const months = [];
      for (let ym = latest, i = 0; i < 24; i++, ym = stepMonth(ym, -1)) months.push(ym);
      if (/^\d{4}-\d{2}$/.test(scope) && !months.includes(scope)) months.unshift(scope);
      select.replaceChildren(
        h('optgroup', { label: 'Month' }, months.map((ym) => h('option', { value: ym, selected: scope === ym }, monthName(ym)))),
        vals.length ? h('optgroup', { label: 'Value' }, vals.map((v) => h('option', { value: 'value:' + v.id, selected: scope === 'value:' + v.id }, v.name))) : null);
      select.onchange = () => { location.hash = '#/story/' + encodeURIComponent(select.value); };

      const valueId = scope.startsWith('value:') ? scope.slice(6) : null;
      const rows = await API.stories(valueId ? { valueId } : { ym: scope });
      const title = valueId ? (vals.find((v) => v.id === valueId) || {}).name || 'Value' : monthName(scope);
      $('h-story').textContent = 'Story';
      if (!rows.length) {
        return empty(body, valueId ? 'No memos carry this value yet.' : 'No memos written for ' + title + '.',
          h('a', { class: 'btn', href: '#/unexamined' }, 'Write one'));
      }
      const spent = rows.filter((t) => t.amount_minor < 0).reduce((a, t) => a - t.amount_minor, 0);
      body.replaceChildren(
        h('header', { class: 'story-head' },
          h('h2', { class: 'section-heading' }, title),
          h('p', { class: 'caption' }, rows.length + (rows.length === 1 ? ' memo · ' : ' memos · ') + money(spent) + ' spent')),
        h('ol', { class: 'story' }, rows.map((t) => {
          const memo = Array.isArray(t.memos) ? t.memos[0] : t.memos;
          const names = (memo.memo_values || []).map((mv) => mv.life_values && mv.life_values.name).filter(Boolean);
          return h('li', { class: 'story-entry' },
            h('a', { class: 'story-meta', href: '#/t/' + t.id },
              h('span', {}, niceDate(t.txn_date) + ' · ' + merchantOf(t)),
              h('span', { class: 'row-amount' }, money(t.amount_minor, t.currency))),
            h('p', { class: 'story-text' }, memo.body),
            names.length ? h('p', { class: 'chips chips-static' }, names.map((n) => h('span', { class: 'chip' }, n))) : null);
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
    let rows;
    try {
      rows = await M.parseAppleCardCsv(await file.text());
    } catch (err) { e.target.value = ''; return failed(body, err); }
    if (!rows.length) { e.target.value = ''; return empty(body, 'That export has no transactions.'); }
    const dates = rows.map((r) => r.txn_date).sort();
    const spent = rows.filter((r) => r.amount_minor < 0).reduce((a, r) => a - r.amount_minor, 0);
    const go = h('button', { class: 'btn btn-primary' }, 'Import ' + rows.length + ' transactions');
    const status = h('p', { class: 'caption', role: 'status' });
    go.addEventListener('click', async () => {
      go.disabled = true; status.textContent = 'Importing…';
      try {
        const r = await API.importAppleCard(rows, file.name);
        e.target.value = '';
        body.replaceChildren(h('div', { class: 'state' },
          h('p', {}, r.inserted + ' new' + (r.skipped ? ', ' + r.skipped + ' already in CentMemo.' : '.')),
          h('a', { class: 'btn btn-primary', href: '#/unexamined' }, 'Start writing')));
      } catch (err) { go.disabled = false; status.textContent = ''; failed(body, err); }
    });
    body.replaceChildren(
      h('dl', { class: 'totals' },
        h('div', {}, h('dt', {}, 'Transactions'), h('dd', {}, String(rows.length))),
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
      const picker = h('div', { class: 'grounds', role: 'group', 'aria-label': 'Ground color' }, API.GROUNDS.map((g) => {
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
        const input = h('input', { type: 'text', class: 'field-input field-inline', value: v.name, maxlength: '60', 'aria-label': 'Value name' });
        const rename = h('button', { class: 'btn btn-small' }, 'Rename');
        const del = h('button', { class: 'btn btn-small btn-quiet' }, 'Remove');
        rename.addEventListener('click', async () => { try { await API.renameValue(v.id, input.value); rename.textContent = 'Renamed'; } catch (err) { failed(body, err, settingsView); } });
        del.addEventListener('click', async () => {
          if (del.dataset.confirm !== '1') { del.dataset.confirm = '1'; del.textContent = 'Remove from all memos'; return; }
          try { await API.deleteValue(v.id); settingsView(); } catch (err) { failed(body, err, settingsView); }
        });
        return h('li', { class: 'row row-static' }, input, rename, del);
      }));

      const copy = h('button', { class: 'btn btn-small' }, 'Copy');
      copy.addEventListener('click', async () => { try { await navigator.clipboard.writeText(API.MCP_URL); copy.textContent = 'Copied'; } catch (_) { copy.textContent = 'Select and copy'; } });

      const del = h('button', { class: 'btn btn-danger' }, 'Delete account');
      const delNote = h('p', { class: 'caption', role: 'status' });
      del.addEventListener('click', async () => {
        if (del.dataset.confirm !== '1') {
          del.dataset.confirm = '1'; del.textContent = 'Delete everything, permanently';
          delNote.textContent = 'This removes every transaction, memo, and value, and cannot be undone.';
          return;
        }
        del.disabled = true; delNote.textContent = 'Deleting…';
        try { await API.deleteAccount(); location.hash = ''; showAuth('Your account and everything in it is deleted.'); }
        catch (err) { del.disabled = false; delNote.textContent = err.message; }
      });

      body.replaceChildren(
        h('h2', { class: 'section-heading' }, 'Ground'),
        picker,
        h('h2', { class: 'section-heading' }, 'Values'),
        vals.length ? valueList : h('p', { class: 'caption' }, 'Add a value from any memo.'),
        h('h2', { class: 'section-heading' }, 'Connect Claude'),
        h('p', {}, 'Claude can read your transactions and memos, but can never change them. In Claude, open Settings, then Connectors, then Add custom connector, and paste:'),
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
