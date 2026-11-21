# Apple Card to Claude Duet through FinanceKit and a listed connector

Research brief, November 21, 2026. This brief follows
`duet-connect-pathways.md` and replaces its Apple Card conclusion. That brief
said FinanceKit was out of reach for a personal app. The owner's account
changes that answer: Duet Connect ships under an organization account, and
FinanceKit requires one.

Tags: **[documented]** means a primary source says it. **[reported]** means a
third party or a forum says it. **[inferred]** means it is a reading of the
evidence, not something a source states. **[verified]** means checked in this
session against App Store Connect or the repos.

## Where the owner stands with Apple [verified]

- **Developer team**: Learning is Change, Inc., team `L2G756LY8N`, an
  organization account. The App Store Connect API team key in
  `~/.appstoreconnect/` belongs to this team. Duet Connect's bundle ID
  `com.learningischange.duetconnect` will live on this team.
- **Apps on the team** (App Store Connect API, read November 21, 2026):

| App | Bundle ID | Category | Live now |
|---|---|---|---|
| Archive Watch | `app.archivewatch.tvos` | Entertainment | iOS 1.47.45, tvOS 1.47.42, macOS |
| Tidbits Trivia | `com.learningischange.tidbitstrivia` | Games | iOS, tvOS, macOS |
| Bsky Dreams | `app.bskydreams.ios` | Social Networking | iOS |
| Ear Drama | `app.eardrama` | Entertainment | tvOS live; iOS and macOS waiting for review |
| BOBA Playbook | `app.bobaplaybook.ios` | Utilities | No version ready for sale; latest iOS version rejected |

  That is four apps live and one with no live version. The owner counts five,
  so either BOBA Playbook was live before or a fifth app sits on another team.
  An older Bsky Dreams project file names a second team, `P4A86LCSY7`. This
  doesn't block anything, but it is worth confirming.
- **What this settles**:
  - FinanceKit's organization-account rule is met.
  - App Review 5.1.1(ix) wants financial apps "submitted by a legal entity".
    That rule is met too.
  - The cloud build and CLI submission pipeline already works for this team
    (`cloud-appstore-submission`, `apple-app-store-cli-submission`).
- **What is still open**:
  - The **Account Holder** must file the entitlement request in person.
  - Duet Connect must be a real **Finance category** app on the US App Store.

## The short answer

Building this is possible, and it is the only way to give Duet Apple Card data
beyond Apple Pay taps. Five facts set its shape.

1. **FinanceKit sees much more than Apple Pay.** It returns Apple Card, Apple
   Cash, and Savings accounts. For each it gives balances, credit limit, next
   payment due, and every transaction type FinanceKit models: purchases,
   refunds, interest, fees, payments, adjustments, transfers, and deposits
   **[documented]**. Purchases made with the physical card or the card number
   should appear too, because FinanceKit reads the same Wallet store as the
   Apple Card screen **[inferred; only a real query will prove it]**. Other US
   cards and banks in Wallet are not included **[documented]**.
2. **The entitlement is the long pole, and nothing real can be built before
   it.** Apple reviews every request by hand and publishes no turnaround time.
   Forum reports range from weeks to longer **[reported]**. Without the
   entitlement the app crashes on its first FinanceKit call. There is no
   simulator data and no mock store **[reported]**.
3. **Sending the data to the owner's server and on to Claude has precedent.**
   - YNAB syncs FinanceKit data to its server.
   - Lunch Sync, a small indie app, pushes Apple Card data to Lunch Money's
     API.
   - Monarch sends transactions to AI providers and runs its own Claude
     connector.

   No Apple text forbids server sync **[documented by absence]**. App Review
   5.1.2(i) allows sharing with "third-party AI" only with clear disclosure and
   explicit permission **[documented]**. Any terms specific to FinanceKit
   arrive with the grant, and no one outside can read them yet.
4. **An "official" connector means a Connectors Directory listing, and that
   is reachable.**
   - Submissions go through `claude.ai/directory/manage`.
   - A connector that only reads financial data is allowed; only connectors
     that move money are refused.
   - Precedent: PocketSmith holds a **Verified** personal-finance listing, and
     YNAB and Monarch run official connectors.
   - The listing requires OAuth 2.0, read-only tool annotations, a privacy
     policy, public documentation, and a test account with sample data
     **[documented]**.
5. **The unknown that matters most for Duet**: one review reports that Duet's
   scheduled runs can't reach custom connectors **[reported]**. Anthropic says
   listed and custom connectors share "identical" runtime code paths, and no
   Duet document addresses the question **[documented]**. Test this first,
   because it decides whether the listing is worth having for Duet.

## The architecture

```
iPhone (Duet Connect, Finance category)
  FinanceKit history query + background delivery extension (iOS 26)
  -> encrypt, POST small batches with retry
Cloudflare Worker on a learningischange.com subdomain  ($0 tier)
  D1: transactions, balances, accounts per user, encrypted at rest
  workers-oauth-provider: OAuth 2.1 + PKCE, CIMD, Sign in with Apple upstream
  MCP (Streamable HTTP): read-only tools only
-> Claude connector (custom first, then Directory listing)
-> Claude, Claude Duet, Cowork, Claude Code
```

Each layer, with what the sources say:

- **iPhone app.**
  - Use `transactionHistory(forAccountID:since:isMonitoring:)` with a saved
    `HistoryToken`, so each sync sends only inserts, updates, and deletes
    **[documented]**.
  - The iOS 26 background delivery extension wakes at most hourly, daily, or
    weekly, and only when data changed **[documented]**.
  - Network calls from the extension are neither documented nor forbidden.
    Store first, then send small batches that are safe to resend, and keep a
    foreground sync as the fallback **[inferred]**.
  - The background extension's bundle ID probably needs the entitlement too
    **[documented: WWDC25 session 201 adds it to both targets]**.
  - iPhone only. The transaction APIs are not on macOS, iPad is reported buggy,
    and visionOS is absent **[documented / reported]**.
- **Server.**
  - Cloudflare Workers, D1, and KV on the free plan, matching the owner's
    other apps.
  - The directory wants the server "domain to match your service", so the
    server goes on a `learningischange.com` subdomain, not `workers.dev`
    **[documented: review criteria]**.
  - Sign in with Apple needs a custom form-POST callback. The library's
    upstream guide is shaped for GitHub **[inferred]**.
- **MCP tools**:
  - Read-only, with `readOnlyHint` and a `title` on every tool.
  - Results are structured and sized to the question.
  - No catch-all tool and no write tools **[documented: review criteria]**.
  - Candidate set: `list_accounts`, `get_balances`, `search_transactions`
    (date range, merchant, category, amount, status), and
    `spending_by_category` (period).
- **Prompt injection.** Merchant names and descriptions are untrusted text.
  - Return them as fields, not prose.
  - Cap their length and strip control characters.
  - Offer no tool an injected instruction could act on **[inferred; Anthropic
    has no guidance specific to tool-result text]**.
- **Rules that bind the whole system** **[documented]**:
  - No transaction details in any push or local notification (Apple Developer
    Program License Agreement).
  - Delete server data when the user revokes access.
  - A privacy policy that names Anthropic, Cloudflare, and Apple.
  - Explicit opt-in before the first sync to Claude (5.1.2(i)).

## Why we build: the four questions

The app must be a real financial management tool to earn the entitlement.
Apple's criteria name "spending trends, budgeting". That requirement fits the
project's values. A version that only pipes data to Claude would fail both
Apple's bar and ours.

1. **Does it deepen understanding?** Yes, if the app shows the person their
   own spending structure: categories by merchant code, month over month,
   interest and fees made visible. Claude adds to that view; it doesn't
   replace it.
2. **Does it invite participation?** Yes, if the person chooses which
   accounts, how far back, and which categories Duet may see, and names their
   own budget lines. Apple's account picker already asks for accounts and the
   earliest date.
3. **Does it support agency?** Yes, if every sync is visible: what left the
   phone, when it left, and a log of what Claude asked for. Access can be
   revoked in one place. Claude gets read tools only, so it can never act on
   the money.
4. **Clarity over cleverness.** Four read tools, one server, one table per
   entity. No AI-written categories or summaries in the app (AGENTS.md: no
   AI-written lists or copy in the product).

## Smaller steps, in order

| Step | What | Needs Apple? | Who |
|---|---|---|---|
| 0 | Test whether Duet reaches a trivial authless custom connector, live and in a scheduled task. Run the same test later with OAuth. | No | Agent builds the server; Ben runs the test in Duet |
| 1 | File the FinanceKit entitlement request for `com.learningischange.duetconnect` (and the extension ID if the form asks) | Starts the clock | **Ben, as Account Holder** |
| 2 | Build the Worker: OAuth, D1, the four read tools, seeded sample data (this is also the directory's required test account) | No | Agent |
| 3 | Fill it with real data before the entitlement: import a Wallet or card.apple.com CSV export through the Worker | No | Agent builds it, Ben exports |
| 4 | iOS app shell: spending views, consent screen, sync log, settings. Builds without FinanceKit behind `isDataAvailable` | No | Agent |
| 5 | Turn on FinanceKit sync and the background extension. TestFlight on Ben's iPhone. Record which transaction kinds actually appear | Yes, the grant | Agent, Ben tests |
| 6 | App Store submission in Finance, then the Connectors Directory submission | Yes | Agent through the CLI pipeline; Ben approves |

Steps 0, 2, 3, and 4 can run while Apple reviews step 1. Step 3 gives Duet real
Apple Card data in days, not months, and every piece it uses carries over to
the FinanceKit version.

### Draft text for the entitlement request (for Ben to edit)

> Duet Connect is a personal finance app from Learning is Change, Inc. for
> people with Apple Card, Apple Cash, and Savings. It shows spending trends by
> category and month, interest and fees, upcoming payments, and budgets the
> person defines. With the person's explicit opt-in, it also syncs their
> transactions, encrypted, to our server, so they can ask questions about
> their own finances in Claude, Anthropic's AI assistant, through a read-only
> connector they authorize and can revoke at any time. Nothing can move money.
> We never sell or share data for advertising, and we delete it when access
> is revoked. Distribution: the App Store for iPhone in the US, in the Finance
> category.

## Decisions only the owner can make

1. **Who is it for?** Is the app public in the App Store, so anyone with an
   Apple Card can connect Claude, or is it for Ben alone?
   - Public means running a service that holds other people's financial data,
     with support, a security bar, and a real privacy policy. It is also what
     a directory listing implies.
   - Apple's **unlisted app distribution** keeps an App Store app reachable
     only by link. Whether FinanceKit's "distributed through the App Store"
     rule accepts unlisted apps is unknown **[inferred; ask in the request]**.
2. **Filing the request**: will you submit it this week, as Account Holder?
3. **Data at rest**: is D1 on Cloudflare, encrypted, acceptable?
   - The alternative stores nothing in the cloud. The phone would answer live,
     but an iPhone can't stay reachable for Duet, so that design fails for
     this data.
4. **History window**: how far back Duet may see. Apple's picker sets the
   floor, and the app can set a shorter one.
5. **Server address**: a subdomain such as
   `duetconnect.learningischange.com`.

## Unknown until tested or granted

- Whether Duet's scheduled runs call custom connectors, and whether a listing
  changes that (step 0).
- Whether read-only tools run unattended without asking, and whether OAuth
  refresh works during unattended runs.
- What the request form asks, how long review takes, and whether one grant
  covers both development and distribution.
- Any FinanceKit terms on off-device storage, AI sharing, or retention.
- Which Apple Card transaction kinds appear, and how many months back.
- The background extension's time budget, and whether network calls finish.
- Whether account IDs survive the Chase issuer change (about January 2028).

## Sources

Apple
- Get started with FinanceKit: https://developer.apple.com/financekit/
- FinanceKit docs: https://developer.apple.com/documentation/financekit
- BackgroundDeliveryExtension: https://developer.apple.com/documentation/financekit/backgrounddeliveryextension
- WWDC25 session 201 (background delivery): https://developer.apple.com/videos/play/wwdc2025/201/
- Meet FinanceKit (WWDC24): https://developer.apple.com/videos/play/wwdc2024/2023/
- Managed capabilities: https://developer.apple.com/help/account/reference/provisioning-with-managed-capabilities
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Developer Program License Agreement: https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
- Chase issuer change: https://www.apple.com/newsroom/2026/01/chase-to-become-new-issuer-of-apple-card/
- Forums: threads 746770, 773595, 773474, 797799, 797800, 724649

Anthropic
- Submitting to the directory: https://claude.com/docs/connectors/building/submission.md
- Review criteria: https://claude.com/docs/connectors/building/review-criteria.md
- Verification: https://claude.com/docs/connectors/verification.md
- Testing: https://claude.com/docs/connectors/building/testing.md
- Directory vs custom: https://claude.com/docs/connectors/building/directory-vs-custom.md
- Authentication: https://claude.com/docs/connectors/building/authentication.md
- Software Directory Policy: https://support.claude.com/en/articles/13145358-anthropic-software-directory-policy
- Get started with Claude Duet: https://support.claude.com/en/articles/17631495-get-started-with-claude-duet

Cloudflare
- workers-oauth-provider: https://github.com/cloudflare/workers-oauth-provider
- MCP authorization: https://developers.cloudflare.com/agents/model-context-protocol/authorization/

Precedent (vendor or reported)
- YNAB Apple connections: https://support.ynab.com/en_us/apple-connections-rkShEfrUh.md
- YNAB MCP: https://support.ynab.com/en_us/mcp-S1wvNaXAMe.md
- Monarch MCP connector: https://help.monarch.com/hc/en-us/articles/50207234679956-Monarch-MCP-Connector
- PocketSmith listing: https://claude.com/connectors/pocketsmith-complete-access
- Copilot Apple accounts: https://help.copilot.money/en/articles/9038131-apple-card-apple-cash-and-savings
- Lunch Sync: https://lunchmoney.app/blog/2025-11-10-community-newsletter
- Every, Duet review: https://every.to/vibe-check/vibe-check-duet-anthropic-s-always-on-agent

---

## Addendum: what Apple's FinanceKit terms say (read November 21, 2026)

The request form (developer.apple.com/contact/request/financekit/, signed in
as Account Holder) carries the **FinanceKit APIs Addendum** to the Apple
Developer Program License Agreement (LYL169, dated April 15, 2024). It is
also published at developer.apple.com/contact/request/download/financekit.pdf.
Summary, not legal advice; section numbers are the addendum's:

- **2.6: Two grants.** Approval first gives a development and testing
  entitlement only. Distribution is applied for separately once Apple's
  requirements are met, and is not guaranteed. **[documented]**
- **2.1: Finance and spending trends.** Finance must be the *primary*
  category, and the app must give "financial management tools (including
  tools that help with tracking comprehensive net worth or spending trends)".
  **[documented]**
- **3.1: Minimum data.** Account Data is used only to provide the service
  through the app and its "Corresponding Product", collecting the minimum
  necessary. **[documented]**
- **3.2: No third parties.** No sharing, transfer, or disclosure of Account
  Data to *any third party*. The only exceptions are a **service provider
  acting on our behalf** (Developer Agreement 2.9: Supabase, Cloudflare), a
  **separate written permission from Apple**, or law. "Account Data"
  includes data "derived from" FinanceKit. **[documented]**
- **3.3: Consent does not override 3.2.** Before asking for access, show the
  data elements, how they are processed, and the privacy policy. Marketing
  or personalized recommendations need separate, unbundled consent. And
  "any end user consent ... shall not supersede the restrictions set forth
  in Section 3.2." **[documented]**
- **3.4: Corresponding Product.** A companion such as the web app may use
  the data with the user's explicit consent, if the use is comparable to the
  app's. **[documented]**
- **3.6: Revocation.** Destroy a user's Account Data within 30 days of
  revocation, and certify it to Apple on request. **[documented]**
- **3.7: Security.** Encryption in transit (App Transport Security) and at
  rest, access controls, and **two-factor authentication with a one-time
  password when a user signs in on a new or unrecognized device**, for both
  the app and the Corresponding Product. **[documented]**
- **3.8: Security incidents.** Notify Apple, remediate, and make no public
  announcement without Apple's written approval. **[documented]**

### What this changes [inferred]

1. **The Claude connector cannot serve FinanceKit-sourced rows by default.**
   Claude reading a user's data through our MCP server discloses Account
   Data to Anthropic. Anthropic acts for the user, not as our service
   provider, and user consent does not override 3.2. Unless Apple grants
   written permission, the connector must exclude rows with
   `source = 'financekit'` and anything derived from them. Rows the person
   imported from their own Wallet or card.apple.com export are not
   FinanceKit Account Data, so the connector may keep serving them, along
   with the person's own memos.
2. **Ask Apple in the request.** The explanation field now says plainly
   that an opt-in, read-only Claude connector is planned. Apple's answer
   (approval, conditions, or a separate written agreement) decides
   whether FinanceKit rows can ever reach Claude.
3. **Two-factor sign-in is required** before FinanceKit data syncs. An email
   magic link alone is one factor. Plan Sign in with Apple (Apple ID 2FA),
   or an email code plus a passkey or TOTP, for any new device.
4. **The website is fine** as a Corresponding Product, with explicit consent.

### The form, as Apple asks it

Fields:
- Website, distribution (US/UK), app name, App Store URL and Apple ID
  (optional), bundle ID, privacy policy link.
- iOS yes/no, interest in other platforms.
- "Does your app provide financial management tools?"
- "Explain why you need the FinanceKit APIs and how you'll use them" (free
  text).
- Whether the app offers financial products.
- "Will any data obtained from FinanceKit APIs be sold?"
- "Will any data obtained from FinanceKit be used for marketing purposes or
  app personalization?"
- Expected users in 12 months (bands).
- The addendum, with an **Agree** button.
