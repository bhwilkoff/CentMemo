/**
 * API: the one client every view goes through (AGENTS.md hard rule).
 * Wraps supabase-js for CentMemo. Row-level security does the scoping;
 * this file never filters by user_id for safety, only for clarity.
 * Money stays integer minor units end to end (Decision 057).
 */
const API = (() => {
  'use strict';

  const SUPABASE_URL = 'https://qucsmmazfalbyduxlavl.supabase.co';
  // Publishable key: safe in the browser; RLS is the guard.
  const SUPABASE_KEY = 'sb_publishable_XuubuEBTUKXkzttN2MUdzw_Aq7-q6YT';
  // The connector's public address (workers/mcp-proxy on Cloudflare); the old Supabase address still works.
  const MCP_URL = 'https://mcp.centmemo.com';

  let db = null;
  function client() {
    if (!db) {
      if (!window.supabase) throw new Error('The sign-in library did not load. Check your connection and reload.');
      db = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
    }
    return db;
  }
  function must(r) {
    if (r.error) throw new Error(r.error.message);
    return r.data;
  }

  /* ---- Auth ---- */
  async function session() { return (await client().auth.getSession()).data.session; }
  function onAuthChange(fn) { client().auth.onAuthStateChange((_e, s) => fn(s)); }
  /**
   * Sign in with Apple on the web (Decision 058, amended): Apple's own script
   * opens a popup and returns a signed identity token, which Supabase checks
   * against the web identifier. No client secret, so nothing expires.
   * redirectURI must match one registered on com.learningischange.centmemo.web.
   */
  const APPLE_WEB_CLIENT_ID = 'com.learningischange.centmemo.web';
  async function sha256Hex(text) {
    const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
    return Array.from(new Uint8Array(d)).map(b => b.toString(16).padStart(2, '0')).join('');
  }
  async function signInWithApple(redirectURI) {
    if (!window.AppleID) throw new Error('Apple\u2019s sign-in script did not load. Check your connection and reload.');
    const raw = Array.from(crypto.getRandomValues(new Uint8Array(24)), b => b.toString(16).padStart(2, '0')).join('');
    window.AppleID.auth.init({
      clientId: APPLE_WEB_CLIENT_ID, scope: 'email', redirectURI,
      usePopup: true, nonce: await sha256Hex(raw), state: raw.slice(0, 12),
    });
    let res;
    try { res = await window.AppleID.auth.signIn(); }
    catch (e) {
      const code = e && (e.error || e.message);
      // In-app browsers (Claude's connector sheet among them) block the popup.
      // Fall back to a same-window round trip to Apple; it never returns here.
      if (code === 'popup_blocked_by_browser') return signInWithAppleRedirect();
      throw new Error(code === 'popup_closed_by_user' || code === 'user_cancelled_authorize'
        ? 'Sign-in was canceled. Choose Sign in with Apple to try again.'
        : 'Apple couldn\u2019t sign you in (' + (code || 'unknown error') + ').');
    }
    const token = res && res.authorization && res.authorization.id_token;
    if (!token) throw new Error('Apple didn\u2019t return a sign-in token. Try again.');
    must(await client().auth.signInWithIdToken({ provider: 'apple', token, nonce: raw }));
  }
  /**
   * The same-window fallback: Apple's authorize page, asking for the email,
   * which Apple will only POST to a server; supabase/functions/apple-return
   * receives it and sends the browser back to the starting page (named by the
   * end of state, from a fixed list) with the identity token in the fragment.
   * The page's query (the consent request's authorization_id) and the nonce
   * wait in sessionStorage, checked by state.
   */
  const APPLE_RETURN_KEY = 'cm_apple_return';
  const APPLE_RETURN_URL = SUPABASE_URL + '/functions/v1/apple-return';
  const randomHex = (n) => Array.from(crypto.getRandomValues(new Uint8Array(n)), b => b.toString(16).padStart(2, '0')).join('');
  async function signInWithAppleRedirect() {
    const page = location.pathname.startsWith('/oauth/consent') ? 'c' : 'w';
    const raw = randomHex(24), state = randomHex(16) + '.' + page;
    sessionStorage.setItem(APPLE_RETURN_KEY, JSON.stringify({ raw, state, back: location.search }));
    const u = new URL('https://appleid.apple.com/auth/authorize');
    u.search = new URLSearchParams({ client_id: APPLE_WEB_CLIENT_ID, redirect_uri: APPLE_RETURN_URL,
      response_type: 'code id_token', response_mode: 'form_post', scope: 'email', state, nonce: await sha256Hex(raw) }).toString();
    location.assign(u.href);
    return new Promise(() => {});
  }
  /** Finishes a same-window Apple sign-in. Returns the page query to restore, or null when this load is not a return from Apple. */
  async function finishAppleRedirect() {
    const h = new URLSearchParams(location.hash.slice(1));
    if (!h.get('id_token') && !h.get('error')) return null;
    let saved = null;
    try { saved = JSON.parse(sessionStorage.getItem(APPLE_RETURN_KEY) || 'null'); sessionStorage.removeItem(APPLE_RETURN_KEY); } catch (_) {}
    history.replaceState(null, '', location.pathname + location.search);
    if (h.get('error')) {
      throw new Error(h.get('error') === 'user_cancelled_authorize'
        ? 'Sign-in was canceled. Choose Sign in with Apple to try again.'
        : 'Apple couldn\u2019t sign you in (' + h.get('error') + ').');
    }
    if (!saved || saved.state !== h.get('state')) throw new Error('That sign-in didn\u2019t start on this page. Choose Sign in with Apple again.');
    must(await client().auth.signInWithIdToken({ provider: 'apple', token: h.get('id_token'), nonce: saved.raw }));
    return saved.back || '';
  }
  async function signOut() { names = null; vals = null; await client().auth.signOut(); }
  async function deleteAccount() {
    must(await client().rpc('delete_my_account'));
    await client().auth.signOut({ scope: 'local' });
  }

  /* ---- Reading ---- */
  const TXN = 'id, account_id, txn_date, posted_date, amount_minor, currency, description, merchant, category, plain_category, txn_type, status, skipped_at';

  async function unexamined(limit = 200) {
    const r = await client().from('unexamined_transactions').select(TXN, { count: 'exact' })
      .order('txn_date', { ascending: false }).limit(limit);
    return { rows: must(r), count: r.count || 0 };
  }
  async function transactionCount() {
    const r = await client().from('transactions').select('id', { count: 'exact', head: true });
    must(r);
    return r.count || 0;
  }
  async function month(ym) {
    const [y, m] = ym.split('-').map(Number);
    const from = ym + '-01';
    const to = new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10);
    return must(await client().from('transactions').select(TXN + ', memos(body, memo_values(value_id, life_values(name)))')
      .gte('txn_date', from).lte('txn_date', to).order('txn_date', { ascending: false }).limit(2000));
  }
  // D7: what to write about (the database picks, by readable rules; memo_suggestions).
  async function suggestions() {
    const rows = must(await client().rpc('memo_suggestions'));
    const seen = new Set();
    return rows.filter((r) => !seen.has(r.transaction_id) && seen.add(r.transaction_id));
  }
  // D12: how many memos each theme collects.
  async function themeCounts() {
    const rows = must(await client().from('memo_values').select('value_id').limit(10000));
    return rows.reduce((m, r) => (m[r.value_id] = (m[r.value_id] || 0) + 1, m), {});
  }
  // D8: every event at one Setting. The pattern finds each raw descriptor the name
  // came from; only rows whose cleaned name is exactly the Setting are kept.
  async function atSetting(name) {
    const p = CentMoney.settingPattern(name);
    if (!p) return [];
    const rows = must(await client().from('transactions').select(TXN + ', memos(body, memo_values(value_id, life_values(name)))')
      .or('merchant.ilike.' + p + ',description.ilike.' + p).order('txn_date', { ascending: false }).limit(1000));
    return rows.filter((t) => CentMoney.cleanMerchant(t.merchant || t.description) === name);
  }
  async function latestMonth() {
    const rows = must(await client().from('transactions').select('txn_date').order('txn_date', { ascending: false }).limit(1));
    return rows.length ? rows[0].txn_date.slice(0, 7) : null;
  }
  async function transaction(id) {
    const rows = must(await client().from('transactions')
      .select(TXN + ', accounts(display_name), memos(body, updated_at, memo_values(value_id, life_values(name))), attachments(kind)').eq('id', id).limit(1));
    return rows[0] || null;
  }
  async function stories({ ym, valueId }) {
    let q = client().from('transactions')
      .select(TXN + ', memos!inner(body, memo_values(value_id, life_values(name)))');
    if (ym) {
      const [y, m] = ym.split('-').map(Number);
      q = q.gte('txn_date', ym + '-01').lte('txn_date', new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10));
    }
    if (valueId) {
      const ids = must(await client().from('memo_values').select('transaction_id').eq('value_id', valueId)).map(x => x.transaction_id);
      if (!ids.length) return [];
      q = q.in('id', ids);
    }
    return must(await q.order('txn_date', { ascending: true }).limit(1000));
  }

  /* ---- The person's ground (Decision 059) ---- */
  const GROUNDS = [
    { id: 'aqua', name: 'Aqua', hex: '#2FD4EC' }, { id: 'sky', name: 'Sky', hex: '#9AC0F8' },
    { id: 'salmon', name: 'Salmon', hex: '#FDA19B' }, { id: 'apricot', name: 'Apricot', hex: '#FEA669' },
    { id: 'citron', name: 'Citron', hex: '#C7C43F' }, { id: 'pistachio', name: 'Pistachio', hex: '#B4C875' },
  ];
  async function ground() {
    const rows = must(await client().from('profiles').select('ground').limit(1));
    return rows.length ? rows[0].ground : 'aqua';
  }
  async function setGround(id) {
    must(await client().from('profiles').upsert({ ground: id }, { onConflict: 'user_id' }));
  }

  /* ---- Values the person names ---- */
  // D14: cached with each theme's color (CentThemes.assignColors); any change clears it.
  let vals = null;
  async function values() {
    if (!vals) vals = must(await client().from('life_values').select('id, name, color, created_at').order('name'));
    return vals;
  }
  async function addValue(name) {
    vals = null;
    return must(await client().from('life_values').insert({ name: name.trim() }).select('id, name, color, created_at').single());
  }
  // Skip (Decision 065): a detail left out of the Story; false brings it back.
  async function setSkipped(id, skipped) {
    must(await client().from('transactions').update({ skipped_at: skipped ? new Date().toISOString() : null }).eq('id', id));
  }
  async function renameValue(id, name) {
    vals = null;
    must(await client().from('life_values').update({ name: name.trim() }).eq('id', id));
  }
  async function deleteValue(id) {
    vals = null;
    must(await client().from('life_values').delete().eq('id', id));
  }
  // D8 renames: the person's name for a Setting, keyed by its cleaned name.
  let names = null;
  async function settingNames() {
    if (!names) {
      const rows = must(await client().from('setting_names').select('setting, name'));
      names = Object.fromEntries(rows.map((r) => [r.setting, r.name]));
    }
    return names;
  }
  async function renameSetting(setting, name) {
    const n = (name || '').trim();
    if (n && n !== setting) must(await client().from('setting_names').upsert({ setting, name: n, updated_at: new Date().toISOString() }));
    else must(await client().from('setting_names').delete().eq('setting', setting));
    if (names) { if (n && n !== setting) names[setting] = n; else delete names[setting]; }
  }

  /* ---- Writing the memo (only the person; agents are refused in SQL) ---- */
  async function saveMemo(transactionId, body, valueIds) {
    const text = body.trim();
    if (!text) {
      must(await client().from('memos').delete().eq('transaction_id', transactionId));
      return;
    }
    must(await client().from('memos').upsert({ transaction_id: transactionId, body: text }, { onConflict: 'transaction_id' }));
    const have = must(await client().from('memo_values').select('value_id').eq('transaction_id', transactionId)).map(x => x.value_id);
    const drop = have.filter(v => !valueIds.includes(v));
    const add = valueIds.filter(v => !have.includes(v));
    if (drop.length) must(await client().from('memo_values').delete().eq('transaction_id', transactionId).in('value_id', drop));
    if (add.length) must(await client().from('memo_values').insert(add.map(value_id => ({ transaction_id: transactionId, value_id }))));
  }

  /* ---- Import (idempotent on source_id, Decision 057) ---- */
  // One account per exported source (S1/S2).
  const EXPORT_ACCOUNTS = {
    applecard: { source_id: 'applecard', kind: 'liability', display_name: 'Apple Card', institution: 'Apple' },
    venmo: { source_id: 'venmo', kind: 'asset', display_name: 'Venmo', institution: 'Venmo' },
    paypal: { source_id: 'paypal', kind: 'asset', display_name: 'PayPal', institution: 'PayPal' },
    cashapp: { source_id: 'cashapp', kind: 'asset', display_name: 'Cash App', institution: 'Block' },
  };
  async function importAppleCard(rows, filename) { return importExport('applecard', rows, filename); }
  async function importExport(kind, rows, filename) {
    const account = must(await client().from('accounts').upsert(
      { source: 'csv', ...EXPORT_ACCOUNTS[kind] },
      { onConflict: 'user_id,source,source_id' }).select('id').single());
    const batch = must(await client().from('import_batches').insert(
      { source: 'csv', filename: String(filename || '').slice(0, 255), row_count: rows.length }).select('id').single());
    let inserted = 0;
    for (let i = 0; i < rows.length; i += 500) {
      const chunk = rows.slice(i, i + 500).map(r => ({ ...r, account_id: account.id, import_batch_id: batch.id }));
      const got = must(await client().from('transactions')
        .upsert(chunk, { onConflict: 'user_id,source,source_id', ignoreDuplicates: true }).select('id'));
      inserted += got.length;
    }
    must(await client().from('import_batches').update({ inserted_count: inserted }).eq('id', batch.id));
    return { inserted, skipped: rows.length - inserted };
  }

  return {
    MCP_URL, client, session, onAuthChange, signInWithApple, finishAppleRedirect, signOut, deleteAccount,
    unexamined, suggestions, themeCounts, transactionCount, month, latestMonth, atSetting, transaction, stories,
    values, addValue, setSkipped, renameValue, deleteValue, settingNames, renameSetting, saveMemo, importAppleCard, importExport, GROUNDS, ground, setGround,
  };
})();
