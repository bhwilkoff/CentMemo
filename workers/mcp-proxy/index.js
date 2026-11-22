// mcp.centmemo.com: the Claude connector's public address. Forwards every
// request, unchanged and streamed, to the Supabase Edge Function, and names
// the public host so the function advertises https://mcp.centmemo.com in its
// OAuth metadata (supabase/functions/mcp/index.ts, resourceServer).
const ORIGIN = 'https://qucsmmazfalbyduxlavl.supabase.co/functions/v1/mcp';

export default {
  async fetch(request) {
    const url = new URL(request.url);
    // Claude and the Connectors Directory show the favicon of the server's address;
    // this address serves only the connector, so point to CentMemo's icon.
    if (url.pathname === '/favicon.ico' || url.pathname === '/apple-touch-icon.png') {
      return Response.redirect('https://centmemo.com/assets/apple-touch-icon.png', 301);
    }
    let path = url.pathname === '/' ? '' : url.pathname;
    // RFC 9728 well-known location, for clients that look there first.
    if (path.startsWith('/.well-known/oauth-protected-resource')) path = '/oauth-protected-resource';
    const headers = new Headers(request.headers);
    headers.set('x-centmemo-public-host', url.host);
    const upstream = await fetch(ORIGIN + path + url.search, {
      method: request.method,
      headers,
      body: request.method === 'GET' || request.method === 'HEAD' ? undefined : request.body,
      redirect: 'manual',
      duplex: 'half',
    });
    const out = new Headers(upstream.headers);
    // The 401 challenge is written by a later layer with the Supabase address;
    // point it at the public one, so clients only ever see mcp.centmemo.com.
    const challenge = out.get('www-authenticate');
    if (challenge) out.set('www-authenticate', challenge.split(ORIGIN).join('https://' + url.host));
    return new Response(upstream.body, { status: upstream.status, headers: out });
  },
};
