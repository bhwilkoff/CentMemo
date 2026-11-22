// The consent page for connecting Claude (or another agent) to CentMemo
// (/oauth/consent/), adapted from Human Shaped. Supabase's OAuth server
// sends people here with an authorization_id; this page signs them in if
// needed, says what the agent may do, and sends their answer back. What
// an agent can and cannot do is enforced by the database (Decision 056),
// not by this page.
(function () {
  'use strict';
  var root = document.querySelector('[data-consent]');
  if (!root) return;
  var db;
  try { db = API.client(); } catch (e) { return fail(e.message); }
  var id = new URLSearchParams(location.search).get('authorization_id');

  function $(sel) { return root.querySelector(sel); }
  function show(state) {
    root.querySelectorAll('[data-state]').forEach(function (s) { s.hidden = s.getAttribute('data-state') !== state; });
  }
  function fail(message) { $('[data-error-text]').textContent = message; show('error'); }
  function host(url) { try { return new URL(url).host || url; } catch (e) { return url; } }

  $('[data-sign-in]').addEventListener('click', function () {
    $('[data-sent]').textContent = '';
    API.signInWithApple('https://centmemo.com/oauth/consent/').then(function () { location.reload(); })
      .catch(function (e) { $('[data-sent]').textContent = e.message; });
  });

  function answer(approve) {
    root.querySelectorAll('[data-approve], [data-deny]').forEach(function (b) { b.disabled = true; });
    var call = approve ? db.auth.oauth.approveAuthorization(id) : db.auth.oauth.denyAuthorization(id);
    call.then(function (r) {
      if (r.error) return fail('Your answer could not be sent: ' + r.error.message);
      $('[data-done-text]').textContent = approve
        ? 'Connected. You can close this page.'
        : 'Not connected. Nothing was shared, and you can close this page.';
      show('done');
      if (r.data && r.data.redirect_url) location.href = r.data.redirect_url;
    });
  }
  $('[data-approve]').addEventListener('click', function () { answer(true); });
  $('[data-deny]').addEventListener('click', function () { answer(false); });

  // A return from Apple's same-window sign-in (used when the popup is blocked,
  // as in Claude's connector sheet): finish it, then put the request back.
  API.finishAppleRedirect().then(function (back) {
    if (back !== null) { location.replace(location.pathname + back); return; }
    begin();
  }).catch(function (e) { show('signed-out'); $('[data-sent]').textContent = e.message; });

  function begin() {
  if (!id) return fail('This page opens from Claude when you connect it to CentMemo, so there is nothing to answer here yet.');

  db.auth.getSession().then(function (s) {
    var session = s.data && s.data.session;
    if (!session) return show('signed-out');
    return db.auth.oauth.getAuthorizationDetails(id).then(function (r) {
      if (r.error) return fail('This request could not be read: ' + r.error.message + '. It may have expired, so start again from Claude.');
      var d = r.data;
      if (!('authorization_id' in d)) { location.href = d.redirect_url; return; }
      $('[data-client-name]').textContent = d.client && d.client.name ? d.client.name : 'An AI agent';
      $('[data-who]').textContent = (d.user && d.user.email) || session.user.email || 'you';
      $('[data-redirect]').textContent = host(d.redirect_uri);
      show('ask');
    });
  }).catch(function (err) { fail('Something went wrong: ' + (err && err.message ? err.message : 'no details') + '.'); });
  }
})();
