# centmemo.com DNS

Snapshot taken 2026-11-22 before moving DNS from WordPress.com to Cloudflare
(for mcp.centmemo.com). Every record below must exist after the move.

| Name | Type | Value | Cloudflare proxy |
|---|---|---|---|
| centmemo.com | A | 185.199.108.153 | DNS only (GitHub Pages issues the certificate) |
| centmemo.com | A | 185.199.109.153 | DNS only |
| centmemo.com | A | 185.199.110.153 | DNS only |
| centmemo.com | A | 185.199.111.153 | DNS only |
| www | CNAME | bhwilkoff.github.io | DNS only |
| centmemo.com | MX (1) | smtp.google.com | n/a (Google Workspace mail: privacy@, hello@) |
| _github-pages-challenge-bhwilkoff | TXT | 2ea05411896053e40c5a13fa5fae0e | n/a (GitHub Pages domain verification) |
| centmemo.com | TXT | google-site-verification=NviqFNA8QitgoJR2qTEUL2MmPedjwud--m0IFHHdXdg | n/a |

| mcp | Worker custom domain | centmemo-mcp (Cloudflare Worker) | proxied, managed by Cloudflare |

Registrar: WordPress.com. Nameservers moved 2026-11-22 from ns1-3.wordpress.com to
heather.ns.cloudflare.com and shane.ns.cloudflare.com (Cloudflare account
benwilkoff@gmail.com, free plan). Verified after the move through 1.1.1.1 and 8.8.8.8:
the same A, MX, and TXT answers; centmemo.com 200; www 301. DNSSEC was off.
Keep the GitHub Pages records DNS only (grey cloud) or the Pages certificate breaks.
