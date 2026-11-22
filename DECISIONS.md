# CentMemo — Architecture & Technology Decisions

Entries capture the *why* behind choices — not the *what* (the code
already shows that). Each entry should answer: **"what would the next
developer get wrong if they didn't know this?"** Lead with the rule,
follow with `**Why:**` and `**How to apply:**`. Append-only.

When a decision affects people and not just code, add one line:
**Who was in the room, who gains, who pays:** (who took part in the
decision, who benefits, and who bears the cost, in money, effort, or
something lost).

Invoke the `architectural-decision-log` skill when adding a new entry.

---

## Where entries live

This file is loaded into every session's context, so it holds the format
rules, a one-line index of every decision, and the recent entries in full.
Older entries are archived verbatim: moved whole, never edited (Decision 033).

- 001–053 (inherited from UniversalAppTemplate) → `docs/decisions/DECISIONS-001-053.md`
- 054+ (CentMemo) → below, in full

Roll again past ~50 KB. Never trim, edit, or summarize an entry in place.

## Index

- 001 — Vanilla HTML/CSS/JS for Web
- 002 — Xcode Project at Repository Root
- 003 — Shared Apple Version Config via xcconfig
- 004 — SwiftUI + @Observable + SwiftData (Apple) — iOS 26 / tvOS 26 baseline
- 005 — Cross-Platform Feature Parity
- 006 — Kotlin + Jetpack Compose for Android (NOT KMP / CMP / Flutter / RN)
- 007 — Material 3 + M3 Expressive; brand theme default, dynamic color opt-in
- 008 — Android: Compose-only, no XML / AppCompat / ActionBar
- 009 — Android: edge-to-edge + predictive back are non-negotiable
- 010 — Universal Links / App Links: `/.well-known/` is the contract
- 011 — Refresh JWT before every Worker / Storage / Edge Function call
- 012 — Brand vs Semantic color split is binding on all platforms
- 013 — One universal Apple target serves iPhone, iPad, and Apple TV
- 014 — The platform set is a decision, not a default
- 015 — Per-ecosystem sync on the user's OWN cloud; no backend to run
- 016 — Shared data plane: published once, every client a consumer
- 017 — tvOS persistence: Caches + App Group only
- 018 — Debug/state env hooks ship in the app, as production no-ops
- 019 — macOS joins the universal Apple target (amends 013)
- 020 — Default Apple submission is a cloud build on a GitHub runner
- 021 — Android publishes to Play via the Developer API from the CLI
- 022 — Player title/metadata uses each platform's native chrome hook
- 023 — Cross-platform multiplayer rides a transport seam; the protocol + arbiter live in Core
- 024 — Online play is per-ecosystem native + a neutral backend; bot-first with honest labels
- 025 — Cross-platform-identical values use order-independent hash-rank + golden-parity tests
- 026 — Persist per-event detail, not just aggregates
- 027 — Cloud Apple builds self-revoke stale auto-created Development certs
- 028 — Smart TVs are two builds plus two zero-app routes, never six apps
- 029 — Windows is an optional first-class platform, and CI is the Windows machine
- 030 — The CI fleet runs on the split-lock / budget / guard / sweeper / auditor doctrine
- 031 — A red X is reserved for broken
- 032 — The agent is never the tester: changes ship on external observation
- 033 — DECISIONS.md stays context-sized: index + recent entries; archives are verbatim
- 034 — Markers carry their source, their timestamp, and their evidence
- 035 — Account deletion is a launch requirement, and the anonymous account is an account
- 036 — Bundled content is queried, never loaded: RAM is a shipping constraint
- 037 — A generator's output is not the shipped artifact; re-running one must be additive
- 038 — Randomness lives outside the selection pipeline
- 039 — Store billing APIs disagree in shape; port the intent, never the code
- 040 — Local persistence must never block launch: open in do/catch, fall back to in-memory
- 041 — When the native project can't live at the repo root, a root workspace shim satisfies the CI host
- 042 — Platform-free logic gets a sidecar SPM package so `swift test` runs without a simulator
- 043 — Algorithmic surfaces honor the user's own moderation and explain every ranked item
- 044 — Every user-visible affordance must control something real
- 045 — Feature gating: keep the code, gate the single UI entry point
- 046 — One canonical ID and one canonical asset per entity
- 047 — Two backend postures: sync islands OR the hosted split — choose in M0
- 048 — Next-OS APIs are adopted additively behind BOTH a runtime and a compile-time gate
- 049 — Marketplace-adjacent features never touch money
- 050 — Market data is provenance-honest, and the sold history is generated, not bought
- 051 — Every third-party data dependency is presumed revocable
- 052 — User-facing vocabulary is a render-layer contract over frozen schema names
- 053: The look has one source, and every platform's tokens are generated from it
- 054: CentMemo is a public Finance-category app, and the story is the product
- 055: Hosted split on Supabase; iOS is the only FinanceKit source; web writes and imports
- 056: Claude reads; only the person writes the story
- 057: Money is signed integer minor units, and ingestion is idempotent on the source ID
- 058: CentMemo signs in with Apple only, on iPhone and on the web
- 059: A sanguine pencil on a ground the person chooses; aqua by default
- 060: The person's color is a mark, never a background (replaces 059's full-screen ground)
- 061: The mark is a sanguine cent sign circled once in pencil, in the person's color
- 062: The connector's public address is mcp.centmemo.com, a Cloudflare Worker in front of the Edge Function
- 063: Connectors Directory reviewers sign in with one reviewer account; everyone else uses Apple (amends 058)
- 064: Reviewer credentials go in the official submission form (amends 063)
- 065: The story vocabulary: Narrative, memo, Story, plot point, Skip, Theme, Setting

---

## 054: CentMemo is a public Finance-category app, and the story is the product
*Date: 2026-11-21*

CentMemo ships on the US App Store for iPhone in the Finance category, under
Learning is Change, Inc., for anyone with Apple Card, Apple Cash, or Savings.
Its core is the person's own memo for each purchase. The Claude connector is
one feature, not the reason the app exists.

**Why**: FinanceKit is the only documented path to full Apple Card history.
Apple grants it only to organization accounts for App Store Finance apps that
"provide financial management tools". A pipe to Claude alone would fail that
test. It would also fail ours: it makes people more passive about their
money. Ben: "There are far too many charges on my card that go unexamined."

**How to apply**: every feature must be something a person uses to
understand their money without Claude. The connector exposes what the app
already holds. Ben's words: `docs/WHAT-CENTMEMO-IS.md`.

**Who was in the room, who gains, who pays:** Ben decided, with research
from this session. People with Apple Card gain a place to tell their money's
story. Learning is Change, Inc. takes on holding other people's financial
data, with its support duty and security bar.

---

## 055: Hosted split on Supabase; iOS is the only FinanceKit source; web writes and imports
*Date: 2026-11-21 (applies 047)*

One Supabase project (`centmemo`) holds Auth (email, Sign in with Apple, and
the OAuth 2.1 server Claude signs in through), plus Postgres with owner-only
RLS on every table. A single Edge Function `mcp` serves the connector. The
platforms:
- **iOS** syncs FinanceKit.
- **Web** (centmemo.com, GitHub Pages) imports Apple Card CSV exports and
  writes memos.
- **macOS** waits: it could be added later through the universal target,
  without FinanceKit.
- **tvOS** is excluded.
- **Android** is excluded for FinanceKit.

**Why**: Claude can only read data from a server it can reach. Shared
stories will be read by other people, which is the 047 fork. Human Shaped
already runs this exact shape (a Supabase OAuth server, a static consent
page, and read-only MCP under RLS) as a working Claude connector. FinanceKit
has no Mac or web API.

**How to apply**: no client calls the network except through its one API
client. Refresh the JWT before Edge Function calls (011). Test every RLS
policy against the deployed project as a stranger and as the owner. Account
deletion ships with sign-in (035).

---

## 056: Claude reads; only the person writes the story
*Date: 2026-11-21*

The connector's tools are all read-only (`readOnlyHint`). The database
refuses writes from any token that carries an OAuth `client_id` claim. No
memo, value, or summary in CentMemo is written by a model.

**Why**: Ben chose read-only. The memo is the person's act of examining a
purchase. If Claude wrote it, the examining would be gone. A read-only
connector also leaves an injected instruction in a merchant name with
nothing to act on.

**How to apply**: no `create_memo` tool, ever, without a new decision.
Claude may point to unexamined purchases (`unexamined_transactions`) and
help the person think. Writing stays in the app.

---

## 057: Money is signed integer minor units, and ingestion is idempotent on the source ID
*Date: 2026-11-21*

Store every amount as `amount_minor bigint` with an ISO currency code.
Negative means money left the account. Never store floats. Every
transaction row is unique on `(user_id, source, source_id)`. For FinanceKit
the source ID is the transaction's UUID. For CSV imports, which have no
IDs, it is a hash of date, amount, and description, plus an index for
identical rows on the same day.

**Why**: FinanceKit amounts are always positive, and the direction lives in
`creditDebitIndicator`. Floats round cents wrong in sums. Re-importing the
same export, or syncing again after a crash, must never duplicate a
purchase, or memos split across copies.

**How to apply**: parse with `js/money/` (golden-tested). When FinanceKit
replaces CSV data, reconcile on date, amount, and merchant so memos carry
over. Never delete and reinsert.

---

## 058: CentMemo signs in with Apple only, on iPhone and on the web
*Date: 2026-11-21*

On iPhone, CentMemo signs in only with Sign in with Apple. The app sends
Apple's identity token to Supabase (`grant_type=id_token`, provider `apple`,
with a nonce). There is no email code and no password. The website keeps its
email sign-in link, which works with Supabase's default sender.

**Why**: Ben: "Why do we need this? Neither Archive Watch nor tidbits trivia
requires this for sign in." An email code needs a custom mail sender (SMTP)
just to edit Supabase's template, and the default sender allows only a few
emails an hour. Sign in with Apple needs neither. It also brings Apple ID's
two-factor sign-in, which the FinanceKit Addendum (3.7) requires on new
devices.

**Amended the same day:**
- **The web signs in with Apple too.** The email link is removed. Ben: "Why
  aren't we using apple sign in on the web?"
- The website uses Apple's own script in popup mode, which returns a signed
  identity token. The page hands it to Supabase (`signInWithIdToken`). That
  is the same token-only shape as Tidbits on Windows and Human Shaped with
  Google.
- **There is no client secret, so nothing expires.** I had wrongly said a
  six-month secret was needed. That applies only to the server-side code
  exchange, which CentMemo doesn't use.
- The web identifier `com.learningischange.centmemo.web` is grouped under
  the CentMemo App ID. Its return URLs are `https://centmemo.com/` and
  `/oauth/consent/`.
- Because the identifier is grouped, a person gets the same Apple user ID
  on the web and on iPhone: one account.

**How to apply**:
- Keep the Apple button out of any `Form`, and show every failure on screen,
  including a cancel (Tidbits' 2.1(a) rejection).
- Bundle ID capability: `APPLE_ID_AUTH`. Supabase Apple provider client ID:
  `com.learningischange.centmemo`.
- Apple sign-in on the web works only on centmemo.com (the registered
  domain), not on localhost. Local testing signs the synthetic accounts in
  from the console.
- The full round trip is verified only on a team-signed device build.

---

## 059: A sanguine pencil on a ground the person chooses; aqua by default
*Date: 2026-11-21*

The pencil, meaning text, marks, and actions, is sanguine `#4A1520`. The
page is a bold ground the person picks in Settings: Aqua (the default), Sky,
Salmon, Apricot, Citron, or Pistachio. The choice is stored in `profiles`,
so it follows them across web and iPhone. Type is editorial: Newsreader on
the web and New York (the system serif) on Apple, for headings and memos.
The pencil appears as drawn marks (a circled count, wavy rules), never as a
handwriting font.

**Why**: Ben: "I like the sanguine color a lot and the background color(s)
should be able to be chosen by the user, but I like the aqua as a default as
long as it isn't too close to the old Twitter bird color."
- Aqua is 16 to 21 CIEDE2000 from Twitter's blues, so it is clearly distinct.
- Every ground pairs with sanguine in a way no brand uses
  (docs/research/color-search.md). Lavender was left out because it reads as
  Human Shaped's sibling.
- The usual green, red, and amber fail on bold grounds, so the semantic
  colors are deeper in light mode.
- Dark grounds stay near neutral, so the pale sanguine never sits on its
  near-opposite hue (Human Shaped's October 9 lesson).

**How to apply**:
- A new ground needs four things: a `grounds` entry in design-tokens.json, a
  CSS rule in all three blocks, a case in `apple/Core/Ground.swift`, and the
  `profiles` check constraint.
- `node tools/test_grounds.mjs` fails on any contrast or parity miss.
- Long reading and writing (memos, the story) sit on paper (surface), not
  directly on the ground.

---

## 060: The person's color is a mark, never a background (replaces 059's full-screen ground)
*Date: 2026-11-21*

Pages are paper, and text is ink. Sanguine is the pencil: titles, actions,
selection, and drawn marks. The person's chosen color (aqua by default) has
exactly two jobs: what still needs a memo, and the values they name. The
binding rules are in `docs/DESIGN.md`, sections C1 to C6.

**Why**: Ben: "I like the colors as strong color pops, but having an entire
background of an app be aqua (or any of the other colors) reads as too much
color. It also makes the text harder to read. You need to use an actual
design skill to determine where to use the good colors in the app." Human
Shaped had learned the same thing on October 6: pages stay near-white, and
color appears in highlights and buttons. `mobile-first-density-design` gives
the rule: color carries meaning or an action, never chrome, and each screen
gets one focal point.

**How to apply**:
- Quote `docs/DESIGN.md` before placing color.
- `tools/test_grounds.mjs` fails if a chosen color becomes a page background,
  if ink can't be read on it, or if web and Apple drift apart.
- When everything has a memo, a screen has no bold color. That is the reward.

---

## 061: The mark is a sanguine cent sign circled once in pencil, in the person's color
*Date: 2026-11-21*

CentMemo's mark is a serif cent sign (Newsreader) in sanguine. Around it is
one drawn pencil circle in the person's color (aqua by default) that runs a
little past its start. It sits on paper, and in dark mode on near-black with
a pale sanguine cent sign. The wordmark is the mark plus "CentMemo" in
Newsreader 700. Every asset renders from `branding/brand.html` through
`tools/render_brand.sh`, and none is hand-exported. The brand page is at
`/brand/`.

**Why**: Ben asked for "branding/logos, etc. for us to work from." The mark
uses the app's own gesture: the circle around what still needs you
(DESIGN C3.1, M1). Three concepts were drawn at real home-screen sizes:
- A, the circled cent, was the only one legible at 29 px.
- B, a highlighter band, turned muddy below 60 px.
- C, a memo slip, read as a generic notes app.

A's loop is not Duet's: Duet draws a squiggle on a terracotta disc, and
CentMemo draws a circle around a glyph in its own colors.

**How to apply**:
- Change the mark in `branding/brand.html`, re-run the render script, and
  look at every size, light and dark.
- The icon stays paper with one aqua circle. Color stays a mark, even on the
  icon.
- No handwriting fonts anywhere (memory `no-handwriting-fonts`).

---

## 062: The connector's public address is mcp.centmemo.com, a Cloudflare Worker in front of the Edge Function
*Date: 2026-11-22*

People add `https://mcp.centmemo.com`. A Cloudflare Worker (`workers/mcp-proxy`)
forwards every request, streamed, to the Supabase Edge Function. It sends
`x-centmemo-public-host`, which makes the function name the public address in its
OAuth metadata, and it rewrites the 401 challenge, so a client that comes in
through mcp.centmemo.com only ever sees that address. The old Supabase address
keeps working, and keeps advertising itself, for connections already made.
centmemo.com's DNS moved from WordPress.com to Cloudflare for this
(docs/DNS.md); WordPress.com is still the registrar.

**Why**: Ben, after the first real Duet connection: "I do think that the link
needs to get cleaned up for other people to want to use it." He chose
Cloudflare over a Vercel proxy and over Supabase's custom domain (about $35 a
month). Supabase's gateway overwrites `x-forwarded-host`, hence the
CentMemo-only header; the challenge is written by a later layer than the
metadata option reaches, hence the rewrite in the Worker.

**How to apply**:
- A change to the Worker is made in `workers/mcp-proxy/index.js` and then
  deployed (the dashboard editor, or `wrangler deploy` once signed in).
- `node tools/test_connector.mjs` tests the public address by default;
  `CONNECTOR_MCP_URL=<Supabase URL>` tests the old one. Both must pass.
- The function honors only `mcp.centmemo.com`; never widen that to whatever
  host a request names.
- GitHub Pages records stay DNS only in Cloudflare.

---

## 063: Connectors Directory reviewers sign in with one reviewer account; everyone else uses Apple (amends 058)
*Date: 2026-11-22*

The consent page has a collapsed "Reviewer sign-in" (email and password) that
accepts only `review@centmemo.com`, a dedicated account seeded with the
synthetic sample data (`node tools/seed_demo.mjs reviewer`). Its credentials
live in `~/.centmemo/test-users.json` (never in git) and go to Anthropic by
email, never in the portal. Every other person still signs in with Apple
(Decision 058).

**Why**: Ben chose "Reviewer-only sign-in" when the directory's requirement
(a reviewer test account with sample data) met Apple-only sign-in. The
reviewer account is separate from the test owner, so reviewers holding its
password cannot disturb the RLS and device-test fixture.

**How to apply**:
- The allowlist is in `js/consent.js` (REVIEWER). The page refuses other
  emails and points to Apple; the server would accept any password account,
  and the only password accounts are the synthetic ones.
- `tools/test_web_states.mjs` drives the reviewer path end to end (a real
  authorization, sign-in, approval, the code back) with a refusal control.
- Rotate the reviewer password after a review if it was shared widely:
  change it in Supabase, update test-users.json, and re-send it.

## 064: Reviewer credentials go in the official submission form (amends 063)

*Date: 2026-11-22*

The reviewer account's email and password go in the Connectors Directory
form's Additional notes, as test credentials go into every App Store
submission. Not by a separate email.

**Why**: Ben: "Test credentials that cannot do anything within the app mean
that they are harmless to have in a chat transcript, to be sent via this
form... This is not sensitive materials." The account holds only synthetic
data, and the database refuses writes from agent tokens. 063's "by email,
never in the portal" was a precaution from the connector skill, not a rule
Anthropic states.

**How to apply**:
- The agent fills the form and leaves the cursor after "Reviewer password: ",
  with the password on the clipboard. The agent does not type passwords into
  third-party fields itself; the owner's part is one paste.
- Real secrets (API keys, live tokens) still never leave the Keychain.

## 065: The story vocabulary: Narrative, memo, Story, plot point, Skip, Theme, Setting (Ben, 2026-11-22)

*Date: 2026-11-22*

On screen, every charge is an event in the **Narrative**. A person writes a
**memo** on an event. All memos put together are the **Story**. Events worth a
memo are **plot points**. **Skip** swipes an event away as a detail that stays
out of the Story. **Themes** are the collections. Where an event happened is
its **Setting**. "Unexamined" stays. The design base is the Chronicle mockup
(direction C), with parts of A and B.

**Why**: Ben: "The word Memo is literally in our app name ... the sum of all
of the memos is the story of your life, not that you are turning a single
memo into a story." "'Narrative' is probably the best word to describe all
of the events as they come in from your Apple Card." "The 'places' that a
story happens is generally known as the Setting." His full words are in
docs/design/STORY-DESIGN-BRIEF.md.

**How to apply**:
- New screen words come from the brief's vocabulary table. "Ledger",
  "Chronicle", "merchant", "vendor" and "transaction" never reach a screen;
  code identifiers may keep their old names.
- A skipped event is never deleted, and Skip is undoable.
- The connector's tool names stay as they are (an external contract), but
  their descriptions use the vocabulary where it helps the reader.
