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

Registrar: WordPress.com (nameservers ns1-3.wordpress.com before the move).
