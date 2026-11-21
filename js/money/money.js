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
    const s = String(text).replace(/^﻿/, '');
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

  const api = { toMinor, formatMinor, parseCsv, isoDate, parseAppleCardCsv, sha256Hex };
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.CentMoney = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
