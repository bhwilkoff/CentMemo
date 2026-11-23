/**
 * CentMoney: the one money core (Decision 057). Plain script that works in
 * the browser (window.CentMoney), Deno (globalThis.CentMoney), and Node
 * (require). Amounts are signed integer minor units: negative left the
 * account. Never floats.
 */
(function (root) {
  'use strict';

  // "12.34", "-1,234.5", "$7" -> integer cents. Throws on anything else.
  function toMinor(text) {
    const s = String(text).trim().replace(/[$,\s]/g, '');
    const m = /^(-|\+)?(\d+)(?:\.(\d{0,2}))?$/.exec(s);
    if (!m) throw new Error('Not an amount: ' + text);
    const minor = Number(m[2]) * 100 + Number((m[3] || '').padEnd(2, '0'));
    if (!Number.isSafeInteger(minor)) throw new Error('Amount too large: ' + text);
    return m[1] === '-' ? -minor : minor;
  }

  function formatMinor(minor, currency) {
    const sign = minor < 0 ? '-' : '';
    const abs = Math.abs(minor);
    const whole = Math.floor(abs / 100).toLocaleString('en-US');
    const cents = String(abs % 100).padStart(2, '0');
    const symbol = (currency || 'USD') === 'USD' ? '$' : (currency + ' ');
    return sign + symbol + whole + '.' + cents;
  }

  // RFC 4180 CSV: quoted fields, doubled quotes, CRLF or LF.
  function parseCsv(text) {
    const rows = [];
    let row = [], field = '', i = 0, quoted = false;
    const s = String(text).replace(/^\ufeff/, '');
    while (i < s.length) {
      const c = s[i];
      if (quoted) {
        if (c === '"' && s[i + 1] === '"') { field += '"'; i += 2; continue; }
        if (c === '"') { quoted = false; i++; continue; }
        field += c; i++; continue;
      }
      if (c === '"') { quoted = true; i++; continue; }
      if (c === ',') { row.push(field); field = ''; i++; continue; }
      if (c === '\r') { i++; continue; }
      if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; i++; continue; }
      field += c; i++;
    }
    if (field !== '' || row.length) { row.push(field); rows.push(row); }
    return rows.filter(r => r.some(f => f.trim() !== ''));
  }

  // MM/DD/YYYY -> YYYY-MM-DD
  function isoDate(text) {
    const m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(String(text).trim());
    if (!m) throw new Error('Not a date: ' + text);
    return m[3] + '-' + m[1].padStart(2, '0') + '-' + m[2].padStart(2, '0');
  }

  async function sha256Hex(text) {
    const bytes = new TextEncoder().encode(text);
    const digest = await crypto.subtle.digest('SHA-256', bytes);
    return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, '0')).join('');
  }

  const APPLE_CARD_COLUMNS = ['Transaction Date', 'Clearing Date', 'Description', 'Merchant',
    'Category', 'Type', 'Amount (USD)'];

  /**
   * Apple Card CSV export (Wallet or card.apple.com) -> normalized rows.
   * In the export, purchases are positive and payments/credits negative;
   * CentMemo flips that so spending is negative. The export has no
   * transaction IDs, so source_id is a hash of the row's facts plus its
   * occurrence among identical rows in the same file (Decision 057).
   */
  async function parseAppleCardCsv(text) {
    const rows = parseCsv(text);
    if (!rows.length) throw new Error('The file is empty.');
    const header = rows[0].map(h => h.trim());
    const col = {};
    for (const name of APPLE_CARD_COLUMNS) {
      const idx = header.indexOf(name);
      if (idx < 0) throw new Error('This is not an Apple Card export: no "' + name + '" column.');
      col[name] = idx;
    }
    const seen = new Map();
    const out = [];
    for (let r = 1; r < rows.length; r++) {
      const f = rows[r];
      const get = (name) => (f[col[name]] || '').trim();
      const txn_date = isoDate(get('Transaction Date'));
      const clearing = get('Clearing Date');
      const exportAmount = toMinor(get('Amount (USD)'));
      const row = {
        source: 'csv',
        txn_date,
        posted_date: clearing ? isoDate(clearing) : null,
        amount_minor: -exportAmount,
        currency: 'USD',
        description: get('Description').slice(0, 500),
        merchant: get('Merchant').slice(0, 200),
        category: get('Category').slice(0, 80),
        txn_type: get('Type').slice(0, 40),
        status: clearing ? 'booked' : 'pending',
      };
      const key = [row.txn_date, exportAmount, row.description, row.merchant, row.txn_type].join('|');
      const n = seen.get(key) || 0;
      seen.set(key, n + 1);
      row.source_id = 'applecard:' + (await sha256Hex(key)).slice(0, 32) + ':' + n;
      out.push(row);
    }
    return out;
  }

  // ---- Other sources (S1/S2): Venmo, PayPal, Cash App statement CSVs. Formats and
  // traps: docs/research/p2p-csv-export-paths.md. Each row keeps the person's note
  // in `description`, and the other party (or the store) as `merchant`.

  // "- $65.00", "+ $10.00", "-$2.90", "($2.90)", "-6.99", "1,234.50" -> cents.
  function looseMinor(text) {
    let s = String(text || '').trim();
    if (!s) throw new Error('Not an amount: (empty)');
    const paren = /^\(.*\)$/.test(s);
    s = s.replace(/[()\s$,]/g, '');
    const neg = paren || s.startsWith('-');
    const n = toMinor(s.replace(/^[+-]/, ''));
    return neg ? -n : n;
  }
  function headerIndex(rows, must) {
    const i = rows.findIndex((r) => must.every((m) => r.some((c) => c.trim() === m)));
    if (i < 0) throw new Error('Not a recognized export: no "' + must.join('", "') + '" columns.');
    const col = {};
    rows[i].forEach((c, k) => { const t = c.trim(); if (t && !(t in col)) col[t] = k; });
    return { i, col };
  }
  const cell = (r, col, name) => (col[name] == null ? '' : String(r[col[name]] || '').trim());

  function parseVenmoCsv(text) {
    const rows = parseCsv(text);
    const { i, col } = headerIndex(rows, ['ID', 'Datetime', 'Amount (total)']);
    const out = [];
    for (const r of rows.slice(i + 1)) {
      const id = cell(r, col, 'ID');
      if (!/^\d{6,}$/.test(id)) continue;  // title, balance, and disclaimer rows have no ID
      const amount = looseMinor(cell(r, col, 'Amount (total)'));
      const status = cell(r, col, 'Status');
      out.push({
        source: 'csv', source_id: 'venmo:' + id,
        txn_date: cell(r, col, 'Datetime').slice(0, 10), posted_date: null,
        amount_minor: amount, currency: 'USD',
        description: cell(r, col, 'Note').slice(0, 500),
        merchant: (amount < 0 ? cell(r, col, 'To') : cell(r, col, 'From')).slice(0, 200),
        category: '', txn_type: cell(r, col, 'Type').slice(0, 40),
        status: /^(complete|completed)$/i.test(status) ? 'booked' : 'pending',
      });
    }
    return out;
  }

  function parsePayPalCsv(text) {
    const rows = parseCsv(text);
    const { i, col } = headerIndex(rows, ['Date', 'Gross', 'Transaction ID']);
    const out = [];
    for (const r of rows.slice(i + 1)) {
      const id = cell(r, col, 'Transaction ID');
      if (!id || /^memo$/i.test(cell(r, col, 'Balance Impact'))) continue;  // holds move no money
      const status = cell(r, col, 'Status');
      out.push({
        source: 'csv', source_id: 'paypal:' + id,
        txn_date: isoDate(cell(r, col, 'Date')), posted_date: null,
        amount_minor: looseMinor(cell(r, col, 'Gross')), currency: cell(r, col, 'Currency') || 'USD',
        description: (cell(r, col, 'Note') || cell(r, col, 'Subject') || cell(r, col, 'Item Title')).slice(0, 500),
        merchant: cell(r, col, 'Name').slice(0, 200),
        category: '', txn_type: cell(r, col, 'Type').slice(0, 40),
        status: /^completed$/i.test(status) ? 'booked' : 'pending',
      });
    }
    return out;
  }

  function parseCashAppCsv(text) {
    const rows = parseCsv(text);
    const { i, col } = headerIndex(rows, ['Transaction ID', 'Date', 'Amount']);
    const out = [];
    for (const r of rows.slice(i + 1)) {
      const id = cell(r, col, 'Transaction ID');
      const status = cell(r, col, 'Status');
      const type = cell(r, col, 'Transaction Type');
      if (!id || /^failed$/i.test(status) || /notification/i.test(type)) continue;
      const name = cell(r, col, 'Name of sender/receiver');
      const notes = cell(r, col, 'Notes');
      out.push({
        source: 'csv', source_id: 'cashapp:' + id,
        txn_date: cell(r, col, 'Date').slice(0, 10), posted_date: null,
        amount_minor: looseMinor(cell(r, col, 'Amount')), currency: cell(r, col, 'Currency') || 'USD',
        // On Cash Card purchases Notes holds the store, not a note.
        description: (name ? notes : '').slice(0, 500),
        merchant: (name || notes).slice(0, 200),
        category: '', txn_type: type.slice(0, 40),
        status: /refund|fail/i.test(status) ? 'pending' : 'booked',
      });
    }
    return out;
  }

  // Which export a file is, by its header: 'applecard', 'venmo', 'paypal', 'cashapp', or null.
  function detectExport(text) {
    const head = parseCsv(String(text).slice(0, 20000)).slice(0, 12).map((r) => r.map((c) => c.trim()));
    const has = (...names) => head.some((r) => names.every((n) => r.includes(n)));
    if (has('Transaction Date', 'Clearing Date', 'Amount (USD)')) return 'applecard';
    if (has('ID', 'Datetime', 'Amount (total)')) return 'venmo';
    if (has('Gross', 'Balance Impact')) return 'paypal';
    if (has('Transaction ID', 'Name of sender/receiver')) return 'cashapp';
    return null;
  }
  async function parseAnyExport(text) {
    const kind = detectExport(text);
    if (kind === 'applecard') return { kind, rows: await parseAppleCardCsv(text) };
    if (kind === 'venmo') return { kind, rows: parseVenmoCsv(text) };
    if (kind === 'paypal') return { kind, rows: parsePayPalCsv(text) };
    if (kind === 'cashapp') return { kind, rows: parseCashAppCsv(text) };
    throw new Error('This file is not an Apple Card, Venmo, PayPal, or Cash App export.');
  }

  // Store names (D8): the bank's descriptor cleaned for people, conservatively.
  // The raw string is always kept beside it; a rename the person makes wins.
  const PROCESSOR = /^(?:SQ|TST|SP|PP|PAYPAL|DD|GOOGLE|IC|POS|PY|BT)\s*\*\s*/i;
  function cleanMerchant(raw) {
    let s = String(raw || '').replace(/\s+/g, ' ').trim().replace(PROCESSOR, '').replace(/\s*\*.*$/, '');
    s = s.replace(/\s+(?:#\s*)?\d{3,}$/, '').replace(/\s+#\d+$/, '').trim();
    if (s && !/[a-z]/.test(s)) {
      s = s.toLowerCase().replace(/(^|[\s\-\/&('])([a-z])/g, (m, p1, c) => p1 + c.toUpperCase())
        .replace(/'([A-Z])(?=\s|$)/g, (m, c) => "'" + c.toLowerCase());
    }
    return s;
  }
  // One or two letters for the tile: first letters of the first two words
  // ("King Soopers" -> "KS"), skipping a leading "The".
  function merchantInitials(name) {
    const words = String(name || '').replace(/\.(?:com|net|org)$/i, '').split(/[^A-Za-z0-9]+/).filter(Boolean);
    if (words.length > 1 && /^the$/i.test(words[0])) words.shift();
    return words.slice(0, 2).map((w) => w[0].toUpperCase()).join('') || '?';
  }
  // Which of the tile hues a store wears: FNV-1a (32-bit) of its lowercased
  // name, mod `count`. Same on every platform (golden: tests/fixtures/merchant-names.json).
  function merchantHue(name, count) {
    let h = 0x811c9dc5;
    for (const b of new TextEncoder().encode(String(name || '').toLowerCase())) {
      h ^= b; h = Math.imul(h, 0x01000193) >>> 0;
    }
    return h % (count || 6);
  }

  // D8: a PostgREST ilike pattern that finds every raw descriptor a Setting's
  // name came from ("Blue Bottle Coffee" -> "*Blue*Bottle*Coffee*"); callers keep
  // only the rows whose cleaned name is exactly the Setting.
  function settingPattern(name) {
    const words = String(name || '').split(/[^A-Za-z0-9]+/).filter(Boolean);
    return words.length ? '*' + words.join('*') + '*' : '';
  }

  const api = { toMinor, formatMinor, parseCsv, isoDate, parseAppleCardCsv, sha256Hex, cleanMerchant, merchantInitials, merchantHue, settingPattern,
    looseMinor, parseVenmoCsv, parsePayPalCsv, parseCashAppCsv, detectExport, parseAnyExport };
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.CentMoney = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
