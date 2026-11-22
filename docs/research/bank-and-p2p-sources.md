# Other banks, cards, Venmo, PayPal, and Cash App

Research for CentMemo, November 22, 2026. The question: how easily could
we add other banks and cards (through Plaid or another aggregator) and
Venmo, PayPal, and Cash App, with all of it readable through our Claude
connector? Only worth doing if it "would work easily."

Marks: **[documented]** means an official page says it. **[reported]**
means a third party says it. **[unconfirmed]** means we could not check
it. Not legal advice.

## The fact that changes the question

On November 5, 2026, Anthropic launched **Personal Finance in Claude**
(US beta, Pro, Max, and Ultra plans). People connect bank and card
accounts inside Claude through Plaid. Claude sees balances, credit
limits, and up to two years of transactions, read only.
**[documented]**
([Anthropic](https://claude.com/blog/introducing-personal-finance-in-claude),
[Plaid](https://plaid.com/blog/plaid-anthropic-financial-insights-in-claude/))

So a person's own Claude can already read their bank transactions
without CentMemo. What Claude cannot see is **the memo**: what the
purchase meant to the person. That is CentMemo's part. It argues
against paying an aggregator just to hand bank data to Claude, and for
making our connector return memos in a shape Claude can line up with
the transactions it already sees (date, amount, merchant).

Aggregator data still matters for the **app**: people need their
purchases in CentMemo to write a memo against them.

## 1. Aggregators

### Plaid

- **What it gives:** Transactions product, up to 24 months of history,
  refreshed one to four times a day, with merchant name, category,
  and a `counterparties` array. **[documented]**
  ([docs](https://plaid.com/docs/api/products/transactions/))
- **Billing:** Transactions is a monthly subscription per Item (one
  login at one bank) for as long as the access token exists. Removing
  the Item ends it. Months are not prorated. **[documented]**
  ([billing](https://plaid.com/docs/account/billing/))
- **Price:** Not published. Pay-as-you-go and Growth prices appear only
  inside the Production access request. Pay-as-you-go has no minimum
  and is "intended for individuals and solo developers."
  **[documented]** Third-party sites put Transactions near $0.25 to
  $0.30 per Item per month. **[unconfirmed]**
- **Free start:** Trial plans give free Production access for up to 10
  Items with a lighter questionnaire. **[documented]**
  ([changelog](https://plaid.com/docs/changelog/))
- **Approval:** Plaid's Risk team reviews the use case and a security
  questionnaire (US/Canada) before Production. The questions are only
  visible in the Dashboard. A third party says approval takes several
  business days. **[documented / reported]**
  ([help](https://support.plaid.com/hc/en-us/articles/16186552926743-How-do-I-add-new-Plaid-products))
  Big banks (Chase, others) also need OAuth registration, which adds
  steps. **[reported]**
- **Effort:** Link on web (JavaScript) and iOS (LinkKit). Server side:
  token exchange, `/transactions/sync`, a webhook for new data, and
  storing access tokens encrypted. That fits Supabase Edge Functions.
  **Catch:** LinkKit is a third-party Swift package, which our hard
  rules forbid. The iOS app would open web Link (Plaid's Hosted Link)
  in an `ASWebAuthenticationSession` instead. **[documented rule;
  Hosted Link fit unconfirmed]**
- **AI and disclosure terms:** Plaid's Developer Policy (effective
  April 19, 2026) and Developer Terms do not mention AI or models.
  **[documented]** They forbid selling or renting End User Data, and
  forbid making Output available "for the benefit of anyone other than
  Client." Use is limited to the approved Client Application.
  ([policy](https://plaid.com/developer-policy/),
  [terms](https://plaid.com/legal/terms-of-use)) Plaid's own AI page
  says an app's use of data "including by AI, is determined by the app
  or developer and is subject to their terms of use."
  ([Plaid for AI](https://plaid.com/industries/ai/)) Plaid powers
  ChatGPT and Claude themselves. So there is **no Apple-style ban**,
  but whether passing Plaid data to the person's own Claude counts as
  part of our Client Application is **[unconfirmed]**. Name it in the
  use case and ask Plaid in writing.
- **Plaid's MCP:** Plaid's official MCP server (May 2025) is a
  developer tool for the Plaid Dashboard (usage, Link issues), not
  consumer data. **[documented]**
  ([blog](https://plaid.com/blog/plaid-mcp-ai-assistant-claude/))
  Community servers that wire personal Plaid data to Claude exist; the
  user is the Plaid customer in those. **[reported]**

### Teller

- Published prices: free developer tier with 100 live connections;
  Transactions $0.30 per enrollment per month; Balance $0.10 per call.
  **[documented]** ([teller.io](https://teller.io/))
- Coverage: "7,000+" US institutions. **[documented]** Venmo, PayPal,
  Cash App: not listed. **[unconfirmed]**
- Effort: Teller Connect (JavaScript widget), REST API with mTLS client
  certificates, webhooks. An official iOS SDK is **[unconfirmed]**; web
  Connect in a web view would work. Production approval process is not
  described publicly. **[unconfirmed]**
- AI terms: not found. **[unconfirmed]**

### Stripe Financial Connections

- Transactions 30 cents per institution, per account holder, per month;
  Balances 10 cents per call; ownership $1.50. **[documented]**
  ([Stripe](https://stripe.com/financial-connections))
- Coverage: 12,000 institutions, "97% of US bank accounts."
  **[documented]**
- Effort: needs a Stripe account; Stripe's iOS SDK (third-party package,
  same catch as Plaid) or Stripe.js on web; webhooks. Built around
  payments, so the review fits a payments business better than a
  journal. Standalone use without Stripe payments is **[unconfirmed]**.

### SimpleFIN Bridge (user pays)

- The person pays SimpleFIN $1.50 a month or $15 a year (up to 25
  institutions and 25 apps). CentMemo pays nothing. **[documented]**
  ([Bridge](https://beta-bridge.simplefin.org/))
- Flow: the person makes a setup token on SimpleFIN's site and pastes
  it into CentMemo. Our server claims it once for an access URL, then
  calls `GET /accounts`. No developer approval. About 24 requests a
  day, 90 days per request, history varies by bank. **[documented]**
  ([developer guide](https://beta-bridge.simplefin.org/info/developers))
- Data: account name and balance; transaction `posted`, `amount`,
  `description`. Payee and memo fields not confirmed.
- Coverage: which aggregator runs underneath, and whether Venmo or
  PayPal work, is **[unconfirmed]**; check its institution search.
- Fit: very simple, no business review, but asks people to sign up
  with a second service. Good for early adopters, not for everyone.

### Sales-led, not for us now

- **MX:** quote only, no public small tier. **[reported]**
- **Mastercard Open Finance (Finicity):** pricing through sales; a test
  drive exists. **[reported]**
- **Akoya:** "Standard" tier under 10,000 connections, custom price,
  free sandbox with a mock bank only. Network of participating banks
  via FDX APIs, so no Venmo, PayPal, or Cash App. **[documented]**
  ([pricing](https://akoya.com/pricing))
- **Yodlee (Envestnet):** enterprise sales; screen-scrapes Venmo and
  is reported unreliable there. **[reported]**
  ([Tiller](https://community.tiller.com/t/what-can-we-do-to-get-venmo-to-include-more-details-in-transaction-descriptions/24342))
- **GoCardless Bank Account Data (Nordigen):** Europe/UK only, and new
  signups are reported closed. Not relevant. **[reported]**
  ([dev.to](https://dev.to/johnfrandsen/gocardless-bank-account-data-alternatives-what-to-use-when-signups-are-disabled-326d))

### Cost at a glance

Assume two connections per person (say, a bank and a card). Prices for
Plaid are estimates.

| | 10 users | 100 users | 1,000 users |
|---|---|---|---|
| Plaid (est. $0.30/Item) | $0 on Trial (10 Items) or about $6 | about $60/mo | about $600/mo |
| Teller ($0.30) | $0 (dev tier) | $0 to $60/mo | about $600/mo |
| Stripe FC ($0.30) | about $6 | about $60/mo | about $600/mo |
| SimpleFIN | $0 to us; $15/yr each to users | same | same |
| CSV import | $0 | $0 | $0 |

At 1,000 users, $600 a month is real money for a free app. Bank fees
may push it up (next section).

## 2. US open banking (Section 1033) in late 2026

- The CFPB finalized the 1033 rule in October 2024. It banned fees for
  required data access. Banks sued, and the CFPB moved to reconsider:
  an advance notice in August 2025, then a new proposal ("Personal
  Financial Data Rights Reconsideration") sent to White House review
  in August 2026. **[documented]**
  ([Consumer Finance Monitor](https://www.consumerfinancemonitor.com/2026/08/06/cfpb-sends-new-section-1033-open-banking-proposal-to-oira-for-review/))
- We found no published proposal as of November 2026. **[unconfirmed]**
  The open question is whether banks may charge "reasonable fees."
- Meanwhile JPMorgan Chase signed paid data-access deals with Plaid
  (September 2025) and then Yodlee, Morningstar, and Akoya (November
  2025). Amounts undisclosed. **[reported]**
  ([American Banker](https://www.americanbanker.com/news/jpmorganchase-reaches-deal-to-charge-plaid-for-customer-data),
  [The Paypers](https://thepaypers.com/fintech/news/jpmorgan-chase-reaches-paid-data-access-agreements-with-aggregators))
- **What it means for us:** nothing free or cheaper is coming soon. A
  small app still reaches banks only through an aggregator. FDX APIs
  are what aggregators use behind the scenes. If anything, costs may
  rise. 1033 never covered Venmo-style balances in a way that gives a
  small app direct access.

## 3. Venmo, PayPal, and Cash App

### Official APIs for a person's own account

- **Venmo:** no public API for personal transaction history. Venmo
  closed its old public API years ago. **[unconfirmed history; no
  current API found]** Developer offerings are checkout (Braintree),
  not history.
- **PayPal:** The Transaction Search API returns the history of the
  account that owns the REST credentials. Setup docs say to sign in
  "with your business account." Whether it works for a personal
  account is **[unconfirmed]**. Either way, it would mean each user
  creating their own developer app. Reading other people's accounts
  needs PayPal partner status. **[documented / reported]**
  ([docs](https://developer.paypal.com/docs/transaction-search))
  Not a consumer path.
- **Cash App:** no public API for personal history found.
  **[unconfirmed]**

### Through aggregators

- Plaid is reported as usually the only aggregator with
  production-grade coverage of PayPal, Venmo, and Cash App.
  **[reported]** ([FintechSpecs](https://fintechspecs.com/blog/plaid-vs-mx-vs-finicity/))
- A Tiller user reports Plaid's Venmo feed includes the counterparty
  (the person paid). Whether **the payment note** comes through is
  **[unconfirmed]**. Yodlee's Venmo feed has the note but not the
  person. **[reported]**
  ([Tiller](https://community.tiller.com/t/what-can-we-do-to-get-venmo-to-include-more-details-in-transaction-descriptions/24342))
- Teller, MX, SimpleFIN coverage of these three: **[unconfirmed]**.
- Plan to test this in Plaid Sandbox and then one real Venmo login on
  the Trial plan before promising anything.

### Exports (the easy path)

**Venmo** **[documented]** ([help](https://help.venmo.com/cs/articles/transaction-history-vhel281))
- Phone: Settings, then Statements, pick month and year, download or
  email. Web: venmo.com, Statements, pick month, Download CSV.
- One month per file. Older history by request to support.
- Columns, from a working downloader: ID, Datetime, Type, Status,
  **Note**, From, To, Amount (total), Amount (fee), Funding Source,
  Destination. **[reported]**
  ([finance-dl](https://github.com/jbms/finance-dl/blob/master/finance_dl/venmo.py))
  The file has extra header and footer rows (balances); parse by
  column name.
- This is the richest source we have: the note people wrote, the other
  person, and the funding source (which card paid).

**PayPal** **[documented, steps vary]** ([help](https://www.paypal.com/us/cshelp/article/help145))
- Web: Activity, then Statements or All Reports, then Activity
  download or custom statement. CSV, TAB, PDF, QuickBooks, Quicken. Up
  to 12 months per request, back 7 years.
- Some users find it under Settings, Data and Privacy, Download your
  data. **[reported]**
  ([community](https://www.paypal-community.com/t5/Reporting/Download-CSV-format-transaction-statements-for-personal-accounts/td-p/3007139))
- Columns are chosen by the user and change over time; PayPal says to
  parse by name, not position. Expect Date, Time, Name, Type, Status,
  Currency, Gross, Fee, Net, Transaction ID, Item Title, Note.
  **[unconfirmed for personal accounts]**
  ([fields](https://developer.paypal.com/docs/reports/online-reports/activity-download/))
- Web only in practice; the app gives monthly statements.

**Cash App** **[documented, partly]**
- Web: cash.app/account, then Activity or Statements, Export CSV.
  Monthly PDF statements in the app under Documents. A CSV export in
  the phone app is **[reported, conflicting]**.
  ([help](https://cash.app/help/us/en-us/3055-download-transaction-history))
- Completed transactions only. Column names **[unconfirmed]**; get a
  real file before building.

## 4. Duplicates

A Venmo payment funded by a card appears twice: once in Venmo (with
the person and the note) and once on the card (as "VENMO" or "PAYPAL
*merchant"). A card-to-Venmo top-up or a Venmo cash-out looks like a
transfer in both places.

How budgeting apps handle it: count each dollar once; treat the other
side as a transfer. Monarch counts the original charge and marks the
later movement as a transfer. Tiller users count the expense where it
first hits and mark the other a transfer. **[documented / reported]**
([Monarch](https://help.monarch.com/hc/en-us/articles/360048393292),
[Tiller](https://community.tiller.com/t/best-practice-for-dealing-with-unbalanced-transfers-from-venmo/19148))
Tiller warns that adding the same institution through two aggregators
also creates duplicates.

For CentMemo:
- Match on amount (exact), date (within about 3 days), and a card
  descriptor that names Venmo, PayPal, or Cash App. Venmo's "Funding
  Source" column makes this strong.
- **Link, never delete.** Keep both rows; one memo belongs to the pair.
  Show the Venmo side (person, note) as the story and the card row as
  "paid with."
- Ask the person to confirm a match the first time. Matching is a
  guess, and the person knows.
- Re-importing a CSV must not duplicate: key Venmo rows on their ID,
  PayPal on Transaction ID, and use a content hash where there is no ID.

## 5. Terms about sending data to an AI

- **FinanceKit:** Apple's Addendum 3.2 bars sharing Account Holder data
  with any third party, and 3.3 says consent does not override it. So
  CentMemo never sends FinanceKit data to Claude (see
  `apple-card-financekit-connector.md`).
- **Plaid:** no AI clause. The limits are: no selling or renting; use
  only within the approved application; consent per law. Plaid's AI
  page puts AI use under the developer's own terms. Much looser than
  Apple, but **get written confirmation** that the connector is in
  scope. **[documented terms; our reading unconfirmed]**
- **Teller, Stripe, SimpleFIN:** no AI clause found. SimpleFIN is the
  person's own data feed that they hand to us, the cleanest case.
  **[unconfirmed]**
- **CSV files:** the person downloads their own file and gives it to
  us. No aggregator terms apply. Only our privacy policy does.
- Practical point: since Claude Personal Finance already sees bank
  transactions, our connector does not need to send raw aggregator
  data. Sending the person's **memos** with date, amount, and merchant
  keeps us clear of most of this.

## Recommendation for CentMemo

Ranked cheapest and easiest first.

**1. Venmo CSV import.** Effort S. $0 a month. No approvals.
- Same pipeline as the Apple Card CSV, on web first (the file lives on
  the computer or in Files). Parse by column name; key on ID.
- Show the Venmo note and the other person as context beside the memo
  box. Do not copy the note into the memo: the memo stays the person's
  own fresh words (learning orientation). They can choose to start
  from it.
- Connector exposes: date, amount, other person, the person's memo,
  and the Venmo note if they chose to share it.
- Then build duplicate linking with Apple Card (Funding Source).

**2. PayPal and Cash App CSV import.** Effort S each. $0. No approvals.
- Get one real file of each before writing the parser. Cash App
  columns and PayPal personal columns are unconfirmed.
- Connector exposes the same fields.

**3. Memo-first connector shape.** Effort S. $0.
- Make every connector result carry date, amount, merchant or person,
  and source, so the person's Claude can match CentMemo memos against
  the transactions Claude Personal Finance already reads.
- This gives "all my banks in Claude" without CentMemo touching bank
  data. Worth doing whatever else we pick.

**4. Generic bank and card CSV import.** Effort M. $0.
- Most banks export CSV. A column-mapping step ("this is the date,
  this is the amount") covers Chase, Amex, and others for free. Manual,
  but honest and private.

**5. SimpleFIN Bridge as an option for keen users.** Effort M. $0 to
us; $15 a year to the user. No approvals.
- One Edge Function that stores the access URL encrypted and syncs
  daily. Paste-a-token setup is clunky; label it as advanced.
- Check the institution list for Venmo and PayPal first.

**6. Plaid (only if 1 to 5 prove people want automatic feeds).**
Effort L. $0 on Trial (10 Items); about $60 a month at 100 users;
about $600 a month at 1,000 users (estimate, plus possible bank-fee
pass-through).
- Owner steps: Plaid Dashboard account under Learning is Change, Inc.;
  Trial plan; Production request with the use case written plainly,
  including "the user's own Claude reads their memos through a
  read-only connector"; security questionnaire; OAuth registration for
  big banks; ask Plaid in writing whether connector access is in scope.
- Build: Hosted Link on web and in an iOS auth session (no LinkKit
  package), Edge Functions for token exchange, sync, webhooks, and
  `/item/remove` on account deletion so billing stops.
- The one real reason: Plaid is the only path to automatic Venmo,
  PayPal, and Cash App feeds, if the Venmo note comes through. Test
  that on the Trial before committing.
- Teller is a cheaper-looking alternative for banks only ($0.30, free
  100 connections) but does not appear to cover the P2P apps.

**Not worth it now:**
- MX, Mastercard Open Finance, Akoya, Yodlee: sales-led, built for
  larger companies, no gain for a small journal app.
- Stripe Financial Connections: same price as Plaid, needs a Stripe
  payments relationship, weaker P2P coverage.
- GoCardless: wrong region, closed to new signups.
- PayPal Transaction Search or any per-user developer key: too hard for
  ordinary people.
- Waiting for 1033 to make access free: it will not happen soon, and
  fees are moving the other way.
- Paying an aggregator only to show bank data to Claude: Claude already
  does that through Plaid. CentMemo's job is the memo.
