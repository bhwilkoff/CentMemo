# Duet Connect: pathways for Apple Card, iCloud Drive, and iCloud Photos

Research brief, November 21, 2026. Every claim is marked **[documented]** with
its source, or **[inferred]** when it is a reading of the evidence rather than
something a primary source states. Third-party reporting is marked
**[reported]**.

## The short answer

Claude Duet has no device-side integration and no Duet-specific API; it runs
in Anthropic's cloud and uses the connectors already on the owner's Claude
account, so the only way to give it data it does not have is a **remote MCP
server reachable from the internet**, added once on claude.ai as a custom
connector (authless, or OAuth with Dynamic Client Registration or a Client ID
Metadata Document). One early review reports that Duet's *scheduled* runs
cannot reach custom connectors, which matters for a proactive agent and needs
to be tested on the owner's own account before anything else is built. For
Apple Card, **FinanceKit is the only documented programmatic pathway, and it is
out of reach for a personal app**: Apple grants it only to organization-level
developer accounts, for apps listed in the Finance category and distributed
through the App Store that provide real financial management tools. The
workable personal pathways are a Shortcuts **Transaction** automation that POSTs
each Apple Pay tap to a small server (fast, but incomplete and unreliable), plus
the documented date-range **export** from Wallet or card.apple.com (complete,
but manual). iCloud Drive and iCloud Photos have no public web API, so the
data has to leave from one of the owner's own devices; a Mac app that stays on
is the strongest shape for both, because macOS PhotoKit and file access are far
less constrained in the background than iOS, and the Mac can hold an outbound
connection to a free Cloudflare Worker that serves MCP to Duet without opening
any inbound port.

| Data source | Pathway | Documented? | Needs Apple approval? | Platform |
|---|---|---|---|---|
| Apple Card | FinanceKit query APIs (full history, long-running) | Yes | Yes: managed entitlement, organization account, App Store Finance app | iPhone (iOS 17.4+); APIs also list iPadOS |
| Apple Card | FinanceKit background delivery extension | Yes | Yes (same entitlement) | iOS / iPadOS 26+ |
| Apple Card | FinanceKitUI `TransactionPicker` (user picks transactions, ephemeral) | Yes (API); entitlement need unclear | Likely yes [inferred] | iOS / iPadOS 18+ |
| Apple Card | Shortcuts Transaction automation, Get Contents of URL POST | Yes (trigger, run without asking, POST) | No | iPhone (iOS 17+) |
| Apple Card | Shortcuts automation calling the app's own App Intent | Yes (App Intents) | No | iPhone |
| Apple Card | Wallet / card.apple.com export by date range (CSV, OFX, QFX, QBO) | Yes | No | iPhone, iPad, any browser |
| iCloud Drive | iOS document picker on a folder, saved bookmark | Yes | No | iOS / iPadOS |
| iCloud Drive | macOS app reading the iCloud Drive folder (sandboxed with user-chosen folder, or Developer ID) | Partly; iCloud Drive is a privacy-protected location | No | macOS |
| iCloud Drive | iCloud web endpoints (unofficial libraries) | No | n/a (unsupported) | Server |
| iCloud Photos | PhotoKit full library access, metadata, `isNetworkAccessAllowed` downloads | Yes | No | iOS, macOS |
| iCloud Photos | PhotoKit captions, keywords, original filename, rating | Yes | No | iOS / macOS 27+ |
| iCloud Photos | PhotoKit background resource upload extension | Yes | No | iOS 26.1+, macOS 27+ |
| iCloud Photos | People and face names | No public API | n/a | none |
| Any | Remote MCP server added as a custom connector on claude.ai | Yes | No (Anthropic does not review custom connectors) | Server |
| Any | MCP tunnels (outbound-only, Anthropic-hosted) | Yes | Enterprise plan only | Server |

---

## 1. How Claude Duet takes in outside data

**Documented path: the Claude account's connectors.**

- Duet "carries over your memory, skills, and connected apps from your Claude
  account" and "can use the over 6,000 connectors and plugins in the Claude
  Marketplace" **[documented]**
  ([Introducing Claude Duet](https://claude.com/resources/articles/claude-duet)).
  The product FAQ says "Claude Duet uses your Claude account, including memory,
  skills, and connectors" **[documented]**
  ([Claude Duet](https://claude.com/product/claude-duet)).
- Duet "has a virtual machine with its own browser" and "checks your connected
  accounts every few hours" **[documented]** (same article). It works "on its
  own computer in the cloud" **[documented]** (product page).
- Neither page mentions custom connectors, MCP, local servers, or any device
  access such as Photos, Files, or Wallet **[documented by absence]**. There is
  no Duet page in the Claude docs index (`claude.com/docs/llms.txt`) and no
  Duet-specific integration API **[documented by absence, checked November 21,
  2026]**.

**Custom connectors (remote MCP).** A connector added on claude.ai is an
account-level connector; Claude's connector docs say the same infrastructure
backs "claude.ai, Claude Desktop, Claude mobile, Claude Code, and Cowork"
**[documented]**
([Authentication for connectors](https://claude.com/docs/connectors/building/authentication.md)).
Because Duet inherits the account's connectors, a custom connector added on
claude.ai should appear in Duet **[inferred]**; setup guides say the same
**[reported]**. Requirements for the server **[documented]**
([Build an MCP server](https://claude.com/docs/connectors/building/index.md),
[Add a connector that isn't in the directory](https://claude.com/docs/connectors/custom/add-unlisted.md)):

- Reachable over the public internet over HTTPS; Anthropic's traffic comes from
  `160.79.104.0/21`, "rather than from your local device."
- Streamable HTTP transport (legacy SSE still accepted).
- Tool results up to about 150,000 characters; 240-second tool call timeout.
  Resource subscriptions and sampling are not supported, so the server cannot
  push to Duet; Duet must pull.
- Individual Pro, Max, and Ultra users add custom connectors themselves (Free
  allows one).
- Authentication choices: **No sign-in** (authless, "anyone with access to the
  server URL can use the connector"); **OAuth 2.0** with Dynamic Client
  Registration or Anthropic's Client ID Metadata Document, PKCE S256, and the
  callback `https://claude.ai/api/mcp/auth_callback`; or **request headers**
  (static API key), which is "in beta and available to a limited set of
  organizations." The `client_credentials` grant is not supported.

**Local MCP servers.** Supported only in Claude Desktop as MCPB desktop
extensions **[documented]** (add-unlisted page). Duet runs in Anthropic's
cloud and cannot reach a process on the owner's Mac **[inferred, and reported
by setup guides]**. **MCP tunnels**, which would let Claude reach a private
server through an outbound-only connection, are "available to organizations on
the Claude Enterprise plan by request" **[documented]**
([MCP tunnels](https://claude.com/docs/connectors/mcp-tunnels/overview.md)),
so they are not available to this owner.

**The scheduled-run caveat.** Dan Shipper's early review says Duet's
"scheduled runs can't reach my custom connectors" **[reported]**
([Every](https://every.to/vibe-check/vibe-check-duet-anthropic-s-always-on-agent)).
If that holds, Duet can use a Duet Connect server when the owner asks it
something, but not in its unattended checks every few hours. Marketplace
connectors such as Google Drive or Gmail are not reported to have this limit.

**Claude's own iOS app.** The Claude iOS app reads Calendar, Reminders,
Location, and (beta, US) Apple Health on-device **[documented]**
([Use Claude with iOS apps](https://support.claude.com/en/articles/11869619-use-claude-with-ios-apps)).
That article does not mention Duet, Photos, Files, or Wallet, and there is no
documented way for a third-party app to feed data into those on-device tools
**[documented by absence]**.

**Workable alternatives to a custom connector.**

- **Write into a source Duet already reads.** A Shortcut, iOS app, or Mac app
  can append Apple Card transactions to a Google Sheet or write a file to
  Google Drive (for example through a free Google Apps Script web endpoint),
  and Duet reads it through the marketplace Google Drive connector, which
  should work in scheduled runs **[inferred]**. The cost is that the data then
  lives in Google as well.
- **Hand data to Duet in conversation**: share an exported CSV in a chat. This
  is manual and not proactive.

## 2. Apple Card transactions

### 2a. FinanceKit

**Eligibility [documented]**
([Get started with FinanceKit](https://developer.apple.com/financekit/),
[FinanceKit documentation](https://developer.apple.com/documentation/financekit)):

- "To access someone's financial data, you must meet the criteria outlined in
  Get started with FinanceKit, request the FinanceKit managed entitlement, hold
  an organization-level Apple Developer account, be logged in as Account
  Holder, and include the `NSFinancialDataUsageDescription` string."
- "Entitlement requests may be submitted by an Account Holder and are granted
  per bundle ID." Apple "reviews each application using defined criteria" and
  adds the entitlement through managed capabilities.
- The app must "Be listed in the Finance category in App Store Connect and
  distributed through the App Store for iPhone in the United States or United
  Kingdom" and "Provide financial management tools (for example, a
  comprehensive view of net worth, spending trends, budgeting)."
- US data: Apple Card (excluding Apple Card Family participants), Apple Cash,
  and Savings, on iPhone with iOS 17.4 or later.

**Can a personal app qualify?** Not as written. A personal relay app is
neither an App Store Finance app nor a financial management tool, and an
individual developer account is excluded outright **[inferred from the
documented criteria]**. Apple staff on the forums restate the
organization-only rule **[reported]**
([thread 746770](https://developer.apple.com/forums/thread/746770)). App
Review Guideline 5.1.1(ix) separately says apps in "banking and financial
services ... or that require sensitive user information should be submitted
by a legal entity ... and not by an individual developer" **[documented]**
([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)).
To qualify, the owner would need an organization account (a legal entity with
a D-U-N-S number) and would need Duet Connect to be a real budgeting app in the
Finance category, with the Duet bridge as one feature.

**Development and TestFlight without approval.** No documented route. The
entitlement must be assigned before a provisioning profile carries it, and
apps without it crash with "Process is not entitled" **[reported]**
([thread 756843](https://developer.apple.com/forums/thread/756843),
[thread 773595](https://developer.apple.com/forums/thread/773595)). Apple's
WWDC24 session says "If you've decided you want to make your app available on
the App Store, you'll need to request a distribution entitlement"
**[documented]**
([Meet FinanceKit](https://developer.apple.com/videos/play/wwdc2024/2023/)),
which hints at a separate development grant, but no page explains how to get
one, and the simulator has no Wallet data **[inferred]**.

**Off-device sharing and AI.** The FinanceKit page and docs do not address
sending data off the device **[documented by absence]**. The page stresses
that data "is retrieved directly from the on-device data store and never seen
by Apple" and that the app must give "full transparency into the information it
requests and how the requested information will be used." Guideline 5.1.2(i)
requires that you "clearly disclose where personal data will be shared with
third parties, including with third-party AI, and obtain explicit permission
before doing so," and says data "may only be shared with third parties to
improve the app or serve advertising" **[documented]**. Sending Apple Card data
to the owner's own server, which Anthropic's servers then read, is sharing with
a third-party AI; whether App Review accepts it as user-directed is untested
**[inferred]**. The binding terms are in the entitlement request (behind
sign-in) and were not readable for this brief.

**Platforms [documented].** `Transaction`, `transactions(query:)`, and
`requestAuthorization()` are marked iOS and iPadOS 17.4. `FinanceStore` lists
Mac Catalyst, but the transaction APIs do not, and there is no macOS
availability. Eligibility names iPhone only.

**Background [documented].** The `BackgroundDeliveryExtension` is iOS, iPadOS,
and Mac Catalyst 26.0+. The app calls `enableBackgroundDelivery(for:frequency:)`
for `transactions`, `accounts`, or `accountBalances`, with a frequency of
`hourly`, `daily`, or `weekly`, which is "the expected minimum interval between
updates." It requires an App Group and the same entitlement
([Implementing a background delivery extension](https://developer.apple.com/documentation/financekit/implementing-a-background-delivery-extension)).
Whether the extension may make a network request in its window is not stated
**[inferred: likely, as other extensions can]**.

**History [documented, WWDC24].** At authorization, people choose accounts and
"indicate for each one the earliest activity that will be available to your
app," and can change that later in Settings. There is no fixed look-back; "FinanceKit tries to preserve as is at least some months of history," and old
change history can be compacted.

**TransactionPicker.** An iOS 18 view in which the person picks transactions;
"access to the shared transactions is ephemeral" and the picker "has fewer
requirements" **[documented, WWDC24]**. Whether it needs the entitlement is not
stated; it lives in FinanceKit, which requires it **[inferred: assume yes]**.

**Note on the issuer change.** Chase is to become Apple Card's issuer in about
24 months from January 2026 **[documented]**
([Apple Newsroom](https://www.apple.com/newsroom/2026/01/chase-to-become-new-issuer-of-apple-card/)).
Nothing says FinanceKit or the Wallet export will change, but any pathway
should be rechecked at the transition **[inferred]**.

### 2b. Pathways with no entitlement

**Shortcuts Transaction automation.**

- Transaction is an automation trigger that "can be run automatically": turn
  on **Allow Running When Locked** under the shortcut's Privacy settings, and
  "you won't get a notification" when it runs; individual actions may also need
  to be allowed **[documented]**
  ([Add automations](https://support.apple.com/guide/shortcuts/apdfbdbd7123/ios)).
- Fields on the Shortcut Input: Transaction, Card, Merchant, Amount, and Name
  **[reported]**
  ([Apple Community](https://discussions.apple.com/thread/256252606)). Apple's
  guide does not list them. There is no category or transaction ID exposed
  **[inferred]**.
- **Get Contents of URL** can send a POST with a JSON body **[documented]**
  ([Request your first API](https://support.apple.com/guide/shortcuts/request-your-first-api-apd58d46713f/ios)),
  and the action also takes custom headers, so a shared secret can go in a
  header **[inferred from the action's UI]**.
- Instead of a URL, the shortcut can call an **App Intent** exposed by Duet
  Connect, passing the fields as parameters, and the app stores and forwards
  them without opening **[documented for App Intents in general]**
  ([App Intents](https://developer.apple.com/documentation/appintents)).
- **Limits.** The trigger fires on Apple Pay use with a Wallet card ("When I
  tap"), so purchases made with the physical card or the card number, refunds,
  interest, payments, and later adjustments are not captured **[inferred]**.
  Developers report timeouts when Wallet's notification arrives late, firing on
  declined transactions, and regressions since iOS 18, with feedback reports
  FB14035016 and FB16379100 and no Apple fix **[reported]**
  ([thread 765516](https://developer.apple.com/forums/thread/765516)).

**Wallet and card.apple.com export.** In Wallet (Apple Card, Card Balance,
Export Transactions) or at card.apple.com (Statements, Export Transactions),
"Choose a start date and end date, choose the file format for the
transactions" **[documented]**
([Apple Support 102284](https://support.apple.com/en-us/102284)). The formats
are CSV, OFX, QFX, and QBO **[reported]**; the support page does not list them.
This is complete and authoritative but manual. A Shortcut can save the export
into a folder the app watches, or the owner can share it to Duet Connect with a
share extension **[inferred]**.

**Not recommended.** Scraping card.apple.com breaks Apple's terms and the
guideline against scraping Apple sites (4.5.1) **[documented]**. Apple Card is
not offered through aggregators like Plaid **[inferred; not verified]**.

## 3. iCloud Drive

**No web API.** Apple publishes CloudKit Web Services only for an app's own
container, not for a person's iCloud Drive files **[documented]**
([CloudKit API tokens](https://developer.apple.com/documentation/cloudkit/obtaining-an-api-token-for-an-icloud-container));
unofficial libraries (rclone, icloudpy) call undocumented iCloud.com endpoints,
which break without notice and do not work when Advanced Data Protection turns
off web access **[reported / inferred]**.

**iOS [documented]**
([Providing access to directories](https://developer.apple.com/documentation/uikit/providing-access-to-directories)):
`UIDocumentPickerViewController` with the folder type returns a
security-scoped URL that "lets your app recursively access the directory and
all of its contents," including future items, and the app "can even save a
bookmark for this URL." The person can revoke access in Settings > Privacy >
Files and Folders. Reads should use a file coordinator, and
`startDownloadingUbiquitousItem(at:)` fetches evicted files. Background work on
iOS is opportunistic (`BGAppRefreshTask`), so an iPhone is a poor always-on file
server **[inferred]**.

**macOS.** iCloud Drive lives at `~/Library/Mobile Documents/com~apple~CloudDocs`.
A sandboxed app reaches it through an open panel and a security-scoped
bookmark (`withSecurityScope`) **[documented]**. iCloud Drive is a
privacy-protected location under TCC, and developers report denial being hard
to undo on macOS 26 and silent blocks for Developer ID apps on macOS 27
**[reported]**
([thread 827374](https://developer.apple.com/forums/thread/827374),
[Eclectic Light](https://eclecticlight.co/2025/11/08/explainer-permissions-privacy-and-tcc/)).
Evicted ("dataless") files download when read or with
`startDownloadingUbiquitousItem`; check `ubiquitousItemDownloadingStatusKey`
first to avoid pulling a whole library by accident **[documented for the keys;
inferred for behavior]**. The safest design is a user-chosen folder plus
bookmark, which works sandboxed and in the Mac App Store **[inferred]**.

## 4. iCloud Photos

**Access [documented]**
([PhotoKit](https://developer.apple.com/documentation/photokit),
[PHAsset](https://developer.apple.com/documentation/photos/phasset)): full
library access via `requestAuthorization(for: .readWrite)` on iOS 14+ and
macOS 11+. "Assets contain only metadata. The underlying image or video data
... might not be stored on the local device." With
`PHImageRequestOptions.isNetworkAccessAllowed`, Photos downloads from iCloud;
otherwise `PHImageResultIsInCloudKey` reports it is unavailable.

**Metadata available without downloading originals [documented]:** media type
and subtypes, pixel size, `creationDate`, `addedDate`, `modificationDate`,
`location` (CLLocation), duration, favorite, hidden, and burst information;
albums and smart albums through `PHAssetCollection`. New in iOS and macOS 27:
`extendedMetadata` with **caption**, **keywords**, **originalFilename**, and
**timeZone**, plus a **rating**, and a `PHPhotoLibraryPersistentChangesObserver`
for change tracking. Thumbnails come from `PHImageManager` at small sizes.

**Not available:** people and face names. There is no public API for them;
`albumSyncedFaces` is a legacy synced-album type **[documented by absence]**.
Tools like osxphotos read the Photos database directly on a Mac, which is
unsupported and needs Full Disk Access **[inferred]**. Place names would come
from reverse geocoding `location` **[inferred]**.

**Background [documented]**
([Uploading asset resources in the background](https://developer.apple.com/documentation/photokit/uploading-asset-resources-in-the-background)):
the Background Resource Upload extension (iOS 26.1+, macOS and Mac Catalyst
27+) lets the system upload asset resources to a `BackgroundUploadURLBase`
server "even when people switch to other apps or lock their devices." It needs
full library access, no special entitlement is mentioned, and it is built for
backup of whole resources, not for answering queries. On a Mac app that stays
open, ordinary PhotoKit calls work at any time **[inferred]**.

## 5. Architecture shapes

The common piece is a **small remote MCP server on Cloudflare Workers' free
plan** (100,000 requests a day, D1 with 5 GB, Durable Objects on SQLite, R2 with
10 GB and free egress) **[documented]**
([Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/)).
Supabase's free tier also works but pauses idle projects **[inferred]**. Add it
once on claude.ai as a custom connector with OAuth (Cloudflare publishes an
OAuth provider library for MCP servers) or, at minimum, authless behind an
unguessable URL, which is weak protection for financial data **[inferred]**.

### A. iOS app with FinanceKit, pushing to a remote MCP server

- **Documented:** FinanceKit queries and the iOS 26 background extension; the
  MCP connector model.
- **Needs approval:** the FinanceKit entitlement, an organization account, and
  public App Store distribution as a Finance app with budgeting features, plus
  a 5.1.2(i) consent screen for sharing with Anthropic.
- **What leaves the device:** transactions (merchant, amount, dates, MCC,
  status) stored in D1; Anthropic reads them per tool call.
- **Risks:** a breach of the Worker exposes full card history; review
  rejection on the AI-sharing question; the app becomes a product with support
  duties.
- **Cost:** $0 hosting; the existing $99 developer fee; possibly forming a
  legal entity.

### B. Mac app that stays on, serving iCloud Drive and Photos through an outbound relay

- **Shape:** the Mac app opens an outbound WebSocket to a Durable Object. The
  Worker's MCP endpoint receives Duet's tool call (for example
  `search_photos`, `read_file`), forwards it over the socket, and the Mac
  answers from PhotoKit or the bookmarked folder. Nothing is stored in the
  cloud except an optional metadata index; files and photos are fetched on
  demand **[inferred design; each piece is documented]**.
- **Documented:** PhotoKit on macOS, security-scoped bookmarks, the MCP limits
  (240 seconds, about 150,000 characters, image results allowed).
- **Needs approval:** nothing from Apple if signed with Developer ID or run as
  a development build; Mac App Store review if distributed there.
- **What leaves the device:** only what Duet requests, passing through
  Cloudflare and Anthropic.
- **Risks:** the Mac must be awake and online; a prompt-injected request could
  read anything in scope, so scope the folder, cap results, and log every call;
  the relay URL must not be guessable; TCC changes on macOS 27.
- **Cost:** $0 (Durable Objects free tier).

### C. Shortcuts only, for Apple Card

- **Shape:** a Transaction automation set to run without asking sends Merchant,
  Amount, Card, Name, and the current date by POST to the Worker, with a secret
  header; the Worker stores rows in D1 and exposes `list_transactions`. Monthly
  or date-range exports from Wallet backfill and correct the record.
- **Documented:** the trigger, run-without-asking, POST, and the export.
- **Needs approval:** none.
- **What leaves the device:** each Apple Pay tap, as it happens.
- **Risks:** missed and declined transactions; no transaction IDs, so the
  backfill must reconcile by date, merchant, and amount.
- **Cost:** $0, and no app is needed at all; an iOS app with an App Intent is
  optional polish.

### D. Feed an existing marketplace connector instead of a custom one

- **Shape:** the same Shortcut, or the Mac app, writes to a Google Sheet or
  Drive folder that Duet already reads.
- **Why consider it:** sidesteps the reported scheduled-run gap and needs no
  OAuth server.
- **Risks:** Apple Card data and personal files are copied into Google.

**Recommended order [inferred]:** first, test whether Duet sees a trivial
authless custom connector in both a live conversation and a scheduled task.
Then build C (a day of work) and B, sharing one Worker. Keep A as a later
decision that depends on the owner's account type and appetite for shipping a
public Finance app.

## Open questions only the owner can decide

1. **Developer account type.** Is the account an individual or an organization
   (a legal entity with a D-U-N-S number)? FinanceKit is impossible on an
   individual account.
2. **Do you want to ship a public budgeting app** in the Finance category to
   earn FinanceKit, or keep Duet Connect personal and accept Shortcuts plus
   exports?
3. **Where may your data rest?** Cloudflare D1 (encrypted at rest by
   Cloudflare, readable by your Worker), Google Drive, or nowhere (Mac answers
   live).
4. **What Duet may see:** all transactions or a time window; which iCloud Drive
   folders; whether photo thumbnails (not only metadata) may leave the Mac.
5. **Authentication strength:** authless with a secret URL for a first test, or
   full OAuth from the start.
6. **Is an always-on Mac acceptable**, given sleep, power, and travel?
7. **Distribution of the Mac app:** Developer ID outside the store, or Mac App
   Store review.

## Sources

Anthropic

- Introducing Claude Duet: https://claude.com/resources/articles/claude-duet
- Claude Duet product page: https://claude.com/product/claude-duet
- Add a connector that isn't in the directory: https://claude.com/docs/connectors/custom/add-unlisted.md
- Build an MCP server for Claude: https://claude.com/docs/connectors/building/index.md
- Authentication for connectors: https://claude.com/docs/connectors/building/authentication.md
- MCP tunnels: https://claude.com/docs/connectors/mcp-tunnels/overview.md
- Use Claude with iOS apps: https://support.claude.com/en/articles/11869619-use-claude-with-ios-apps
- Get started with custom connectors: https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp

Apple

- Get started with FinanceKit: https://developer.apple.com/financekit/
- FinanceKit documentation: https://developer.apple.com/documentation/financekit
- Implementing a background delivery extension: https://developer.apple.com/documentation/financekit/implementing-a-background-delivery-extension
- TransactionPicker: https://developer.apple.com/documentation/financekitui/transactionpicker
- Meet FinanceKit (WWDC24): https://developer.apple.com/videos/play/wwdc2024/2023/
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Add automations (Shortcuts): https://support.apple.com/guide/shortcuts/apdfbdbd7123/ios
- Request your first API (Shortcuts): https://support.apple.com/guide/shortcuts/request-your-first-api-apd58d46713f/ios
- Download Apple Card statements or export transactions: https://support.apple.com/en-us/102284
- Providing access to directories: https://developer.apple.com/documentation/uikit/providing-access-to-directories
- startDownloadingUbiquitousItem(at:): https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:)
- PhotoKit: https://developer.apple.com/documentation/photokit
- PHAsset: https://developer.apple.com/documentation/photos/phasset
- PHAssetExtendedMetadata: https://developer.apple.com/documentation/photos/phassetextendedmetadata
- Uploading asset resources in the background: https://developer.apple.com/documentation/photokit/uploading-asset-resources-in-the-background
- isNetworkAccessAllowed: https://developer.apple.com/documentation/photos/phimagerequestoptions/isnetworkaccessallowed
- CloudKit API tokens: https://developer.apple.com/documentation/cloudkit/obtaining-an-api-token-for-an-icloud-container
- Chase to become new issuer of Apple Card: https://www.apple.com/newsroom/2026/01/chase-to-become-new-issuer-of-apple-card/

Cloudflare

- Workers pricing and free limits: https://developers.cloudflare.com/workers/platform/pricing/

Reported (secondary)

- Every, Vibe Check: Duet: https://every.to/vibe-check/vibe-check-duet-anthropic-s-always-on-agent
- Apple Developer Forums, FinanceKit not entitled: https://developer.apple.com/forums/thread/746770, https://developer.apple.com/forums/thread/756843
- Apple Developer Forums, Transaction trigger timeouts: https://developer.apple.com/forums/thread/765516
- Apple Community, Transaction fields: https://discussions.apple.com/thread/256252606
- Apple Developer Forums, iCloud TCC on Tahoe: https://developer.apple.com/forums/thread/827374
- Eclectic Light, Permissions, privacy and TCC: https://eclecticlight.co/2025/11/08/explainer-permissions-privacy-and-tcc/
