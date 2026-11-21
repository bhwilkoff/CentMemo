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
  const MCP_URL = SUPABASE_URL + '/functions/v1/mcp';

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
      throw new Error(code === 'popup_closed_by_user' || code === 'user_cancelled_authorize'
        ? 'Sign-in was canceled. Choose Sign in with Apple to try again.'
        : 'Apple couldn\u2019t sign you in (' + (code || 'unknown error') + ').');
    }
    const token = res && res.authorization && res.authorization.id_token;
    if (!token) throw new Error('Apple didn\u2019t return a sign-in token. Try again.');
    must(await client().auth.signInWithIdToken({ provider: 'apple', token, nonce: raw }));
  }
  async function signOut() { await client().auth.signOut(); }
  async function deleteAccount() {
    must(await client().rpc('delete_my_account'));
    await client().auth.signOut({ scope: 'local' });
  }

  /* ---- Reading ---- */
  const TXN = 'id, account_id, txn_date, posted_date, amount_minor, currency, description, merchant, category, txn_type, status';

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
    return must(await client().from('transactions').select(TXN + ', memos(body)')
      .gte('txn_date', from).lte('txn_date', to).order('txn_date', { ascending: false }).limit(2000));
  }
  async function latestMonth() {
    const rows = must(await client().from('transactions').select('txn_date').order('txn_date', { ascending: false }).limit(1));
    return rows.length ? rows[0].txn_date.slice(0, 7) : null;
  }
  async function transaction(id) {
    const rows = must(await client().from('transactions')
      .select(TXN + ', accounts(display_name), memos(body, updated_at, memo_values(value_id))').eq('id', id).limit(1));
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

  /* ---- Values the person names ---- */
  async function values() {
    return must(await client().from('life_values').select('id, name').order('name'));
  }
  async function addValue(name) {
    return must(await client().from('life_values').insert({ name: name.trim() }).select('id, name').single());
  }
  async function renameValue(id, name) {
    must(await client().from('life_values').update({ name: name.trim() }).eq('id', id));
  }
  async function deleteValue(id) {
    must(await client().from('life_values').delete().eq('id', id));
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
  async function importAppleCard(rows, filename) {
    const account = must(await client().from('accounts').upsert(
      { source: 'csv', source_id: 'applecard', kind: 'liability', display_name: 'Apple Card', institution: 'Apple' },
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
    MCP_URL, client, session, onAuthChange, signInWithApple, signOut, deleteAccount,
    unexamined, transactionCount, month, latestMonth, transaction, stories,
    values, addValue, renameValue, deleteValue, saveMemo, importAppleCard,
  };
})();
