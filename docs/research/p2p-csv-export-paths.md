# Exporting a CSV from Venmo, PayPal, and Cash App

Researched 2026-11-22. Question: can a person get their own transaction
history as a CSV file from the phone app, and what is in the file?

Short answer:

| App | CSV from the phone app? | Fallback |
|---|---|---|
| Venmo | **Yes.** Settings > Statements, one month per file. | venmo.com > Statements > Download CSV |
| PayPal | **Not documented.** The help center covers only the website. | paypal.com > Activity > download icon > Custom > CSV |
| Cash App | **Not documented.** The app gives monthly PDF statements. | cash.app/account > Activity > CSV button |

"Not documented" means the company's own help pages describe no in-app
CSV path. Some third-party guides claim one; they contradict each other
and are not trusted here. None of the three help centers shows a page
date, so the date on each finding is the date it was read.

Column details for PayPal come from PayPal's developer docs. Column
details for Venmo and Cash App are not published by either company;
they come from sample files and parsers in several independent
open-source projects (cited), which agree with each other.

---

## Venmo

### Phone path (confirmed by Venmo)

Venmo's help article "Transaction History" (vhel281) says:

1. Open **Settings** (in the app: the Me tab, then the gear).
2. Tap **Statements**.
3. Pick a **year and month** from the dropdown.
4. Choose to **download** the file to the device or **email** it to
   yourself. Venmo says some files are too large to download and are
   emailed instead.

The help page does not say where the download lands on iPhone. Expect
the iOS share sheet or Files; this is unconfirmed. Android uses the same
menu per the same article (it is not split by platform).

### Website fallback (confirmed by Venmo)

Sign in at venmo.com, click **Statements** in the sidebar, pick month
and year (click the year at the top of the dropdown to change it), then
**Download CSV**. Safari on iPhone: not confirmed either way.

### Limits

- **One calendar month per file.** A year is twelve files.
- How far back is not stated. Third-party guides say older history can
  be requested from Venmo Support by email. An older open-source tool
  mentions a 90-day window; that was the previous web export and
  conflicts with the current monthly design.
- Business profiles: not covered by the help article. Unconfirmed
  whether a business profile's statement comes from the same screen.

### File format (from open-source parsers, not Venmo)

The file is not a clean table. In order:

1. Title rows, such as `Account Statement - (@username)` and
   `Account Activity`.
2. The **header row**. The first column is blank. Current files (with
   tip and tax columns, seen in 2023 and later parsers):
   `(blank), ID, Datetime, Type, Status, Note, From, To, Amount (total),
   Amount (tip), Amount (tax), Amount (fee), Tax Rate, Tax Exempt,
   Funding Source, Destination, Beginning Balance, Ending Balance,
   Statement Period Venmo Fees, Terminal Location, Year to Date Venmo
   Fees, Disclaimer`.
   Older files lacked the tip, tax, and terminal columns, and some had
   `Username` first.
3. A **beginning-balance row**: no ID, only `Beginning Balance` filled.
4. Transaction rows.
5. An **ending-balance and fees row**: no ID.
6. A **Disclaimer** cell: a long quoted value with embedded newlines.

Parser traps:

- Find the header by content (`ID`, `Datetime`, `Amount (total)`), not
  by line number. Keep only rows whose ID is a long number.
- Use a real CSV parser. The disclaimer has newlines inside quotes.
- **Amount** looks like `- $65.00` or `+ $10.00`: a sign, a space, a
  dollar sign, commas in thousands. Money out is negative. Some parsers
  also handle `(12.00)`.
- **Datetime** is ISO without a zone, like `2024-03-05T18:33:12`. The
  zone is not stated; treat it as unconfirmed.
- **Type** values seen: `Payment`, `Charge`, `Standard Transfer`,
  `Merchant Transaction`, and others. **Status** seen: `Complete`,
  `Issued`.
- Transfers to a bank (`Standard Transfer`) are moving money, not
  spending.
- A merged file (several months pasted together) repeats the title and
  header rows.

### The person's notes

**Yes.** The `Note` column carries the payment note (the "what's it
for" text, often emoji). `From` and `To` carry names. This is the most
memo-rich of the three.

### What CentMemo should tell people

> In Venmo, tap **Me**, then the gear, then **Statements**. Pick a month
> and download it. Do this once for each month you want.

---

## PayPal (personal account)

### Phone path (not documented)

PayPal's help article "How do I view and download statements and
reports?" (help145) gives only website steps. A bookkeeping blog
(SaaSAnt, 2025-11-27) says the app shows Activity but the export tools
are "easier to use on the desktop site." A YouTube video is titled as an
in-app statement download; its steps could not be read. **Treat the
phone app as unable to produce the CSV.**

### Website path (confirmed by PayPal)

Activity report (the one CentMemo wants):

1. Go to **Activity** (History) on paypal.com and select the
   **download icon**.
2. Choose **Custom**, then the report type, date range, and format
   **CSV**. Fields can be customized.
3. When it is ready, select **Download**.

Monthly statements are separate, at paypal.com/reports/accountStatements
(Request, then Download). Those are summaries; use the activity report.

Safari on iPhone: PayPal's site blocks automated fetches, so this was
not tested. It is a standard web flow and likely works, possibly with
"Request Desktop Website." Unconfirmed.

### Limits (confirmed by PayPal)

- Up to **seven years** back, up to **12 months per request**.
- Small reports download at once and are not saved. **Large reports can
  take up to 5 business days**; PayPal emails when ready and keeps the
  last three.
- CSV is capped at **50,000 records**; bigger reports arrive as a ZIP
  of several files.
- Personal vs business: the help page has both tabs but does not say
  they differ. The developer docs describe the same Activity Download
  report for all accounts. Business accounts see more fields filled.

### File format (from PayPal developer docs, updated 2026-10-13)

UTF-8, often with a byte-order mark. One header row, no preamble.
Default columns in order:

`Date, Time, TimeZone, Name, Type, Status, Currency, Gross, Fee, Net,
From Email Address, To Email Address, Transaction ID, Address Status,
Item Title, Item ID, Shipping and Handling Amount, Insurance Amount,
Sales Tax, Option 1 Name, Option 1 Value, Option 2 Name, Option 2 Value,
Reference Txn ID, Invoice Number Text, Custom Number, Quantity, Receipt
ID, Balance, Address Line 1, Address Line 2 / District / Neighborhood,
Town/City, State / Province / ..., Zip/Postal Code, Contact Phone
Number, Subject, Note, Country Code, Balance Impact, Invoice Number`

Real files from earlier years (hledger and reckon samples) also have
`Shipping Address` and `Country`, and label things slightly
differently. **Map by header name, never by position.**

Parser traps:

- **Date** follows the account's country. US: `M/D/YYYY` (samples show
  no leading zeros, like `1/1/2018`). Time is `HH:MM:SS`; the zone is a
  separate column (`PST`, `PDT`).
- **Gross, Fee, Net** are plain numbers with no currency sign. Money out
  is negative (`-6.99`). Thousands may have commas inside quotes.
- **Balance Impact** is `Debit`, `Credit`, or `Memo`. `Memo` rows do
  not move money (holds, authorizations); skip them.
- A purchase paid from a bank or card often shows a second row that
  moves money in to cover it. Count the purchase, not the funding row.
- Every cell is quoted; many are empty.
- Currency conversions add extra rows per transaction.

### The person's notes

**Yes, for payments to people.** `Note` (up to 4,000 characters) and
`Subject` (up to 256) are both default fields. PayPal says the payer
writes them, so the person's own note appears on payments they sent;
on money received, it is the other person's note. Store purchases fill
`Item Title` instead.

### What CentMemo should tell people

> PayPal's app can't export a CSV. On paypal.com, open **Activity**, tap
> the download icon, choose **Custom**, pick dates (up to 12 months) and
> **CSV**. Big reports can take a while; PayPal emails you.

---

## Cash App

### Phone path (not documented)

Cash App's help article 3055, "View Account Statements," gives the
in-app path for **monthly statements**: Profile icon > **Documents** >
**Account Statements**. These are statements (PDF in practice), ready
within 5 business days after month end. No official page describes a
CSV export inside the app. Article 6498 says people can "view and
download your transaction history on our website or in the app," but
gives only the website steps. Third-party guides disagree: some show a
download icon on the mobile Activity screen, others say CSV is web-only.
One claims a 60-day limit. **Treat the phone app as unable to produce
the CSV until someone checks on a real phone.**

### Website path (confirmed by Cash App)

Article 6483: sign in at **cash.app/account**, select **Activity** on
the left, then the **CSV** button to the right of the search bar. The
file is commonly named `cash_app_report.csv`. Safari on iPhone: not
confirmed. Cash App's site may push phone visitors to the app.

### Limits

- Date range: not documented by Cash App. The web button appears to
  export the whole history; unconfirmed.
- Third-party guides say pending transactions are left out.
- Bitcoin and stocks have their own documents under Documents; they
  also appear as rows in the activity CSV.

### File format (from open-source parsers, not Cash App)

One header row, no preamble. Two column orders exist (BittyTax keeps a
parser for each):

- Older: `Transaction ID, Date, Transaction Type, Currency, Amount, Fee,
  Net Amount, Asset Type, Asset Price, Asset Amount, Status, Notes, Name
  of sender/receiver, Account`
- Newer: the same columns with **`Date` first**, then `Transaction ID`.

Parser traps:

- **Date** looks like `2023-10-07 16:12:36 EDT`, with a zone
  abbreviation.
- **Amount** looks like `$1` or `-$2.90`: a dollar sign, no forced
  decimals, minus before the sign. BittyTax also handles `($2.90)`.
  Money out is negative.
- **Transaction Type** changed names. Older: `Sent P2P`, `Received P2P`,
  `Cash Card Debit`, `Cash in`, `Cash out`, `Boost Payment`. Newer:
  `P2P`, `Deposits`, `Withdrawal`, and others. Use the amount's sign,
  not the type, for direction.
- **Status** is uppercase: `CARD CHARGED`, `PAYMENT SENT`,
  `CARD REFUNDED`, `FAILED`. Skip `FAILED`. Skip `Account
  Notifications` rows.
- Some rows leave cells truly empty (`,,`) and others quote them (`""`).

### The person's notes

**Partly.** `Notes` holds the payment note on P2P payments. On Cash
Card purchases it holds the **merchant name** (for example
`MTA*NYCT PAYGO`), and `Name of sender/receiver` is empty. So for card
spending, Notes is the payee, not a memo.

### What CentMemo should tell people

> Cash App's phone app gives PDF statements, not a CSV. On
> **cash.app/account**, open **Activity** and tap the **CSV** button next
> to search.

---

## Not confirmed

- Whether Venmo's in-app download saves to Files or opens the share
  sheet on iPhone.
- Whether PayPal's or Cash App's phone apps have a CSV export the help
  centers do not mention. Worth five minutes on a real phone before
  CentMemo ships these instructions.
- Whether paypal.com and cash.app/account export work in Safari on an
  iPhone.
- How far back Venmo and Cash App go, and Cash App's date range.
- Venmo's datetime time zone.

## Sources

- Venmo Help, "Transaction History":
  https://help.venmo.com/cs/articles/transaction-history-vhel281
- PayPal Help, "How do I view and download statements and reports?"
  (help145): https://history.paypal.com/jm/cshelp/article/how-do-i-view-and-download-statements-and-reports-help145
- PayPal Developer, "Activity Download report" (updated 2026-10-13):
  https://developer.paypal.com/docs/reports/online-reports/activity-download/
- Cash App Help 3055, "View Account Statements":
  https://cash.app/help/us/en-us/3055-download-transaction-history
- Cash App Help 6483 (CSV from Activity): https://cash.app/help/6483
- Cash App Help 6498 (personal data):
  https://cash.app/help/US/EN-US/6498-delete-personal-information
- SaaSAnt blog on PayPal history (2025-11-27):
  https://www.saasant.com/blog/learn-how-to-check-your-paypal-account-history/
- Open-source parsers and samples: BittyTax `conv/parsers/cashapp.py`;
  leonardobazico/ynab-converter README (Cash App sample);
  emersonford/lunchmoney-venmo-syncer `src/types/venmo.rs`;
  egh/ledger-autosync `converter.py` (Venmo); bdmckean/budget_cursor
  `venmo_csv.py`; hledger `examples/csv/other/paypal-2018.csv.rules`;
  cantino/reckon PayPal fixture.
