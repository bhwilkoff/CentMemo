// apple-return: where Apple's same-window Sign in with Apple answers (the
// fallback when a browser blocks the popup, as Claude's connector sheet does).
// Apple only returns the email to a server (response_mode=form_post), so this
// receives that POST and sends the browser straight back to the page that
// started, with the identity token in the URL fragment, where js/api.js
// finishes sign-in and checks state and nonce. It stores nothing.
//
// The page to return to comes from the end of `state` (".c" consent, ".w" the
// web app) and is chosen from this fixed list only, never from the request,
// so this can't be used to send anyone elsewhere. Deploy with verify_jwt off.
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

const RETURN_TO: Record<string, string> = {
  c: 'https://centmemo.com/oauth/consent/',
  w: 'https://centmemo.com/',
};

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return new Response('Sign in with Apple returns here.', { status: 405 });
  let form: FormData;
  try { form = await req.formData(); } catch { return new Response('Bad request', { status: 400 }); }
  const state = String(form.get('state') ?? '');
  const target = RETURN_TO[state.split('.').pop() ?? ''];
  if (!target || !/^[0-9a-f]{32}\.[cw]$/.test(state)) return new Response('Unknown sign-in', { status: 400 });
  const out = new URLSearchParams({ state });
  const token = form.get('id_token'), error = form.get('error');
  if (token) out.set('id_token', String(token));
  else out.set('error', String(error || 'no_token'));
  return new Response(null, { status: 303, headers: { location: target + '#' + out.toString(), 'cache-control': 'no-store', 'referrer-policy': 'no-referrer' } });
});
