# Question for Apple Developer Support (FinanceKit APIs Addendum 3.2)

Status: **sent by Ben 2026-11-24, Case ID 103023652799.** The reply goes to Ben's
Apple Account email. Sent from Apple's developer Contact Us page: Membership and Account >
Agreements and Contracts > Email (phone was unavailable that day). The form has no
subject field, so the subject goes on the first line. Why: `WALLET-IN-CONNECTOR.md`.

**Subject:** Written permission under FinanceKit APIs Addendum Section 3.2 (Team L2G756LY8N, referred by case 23676235)

**Message:**

Hello,

Wallet Entitlements (Kavya, Case-ID 23676235) referred me to Developer Support
and recommended I request guidance from the team responsible for the FinanceKit
APIs Addendum and related contractual permissions. Could you please route this
to that team?

I am the Account Holder for Learning is Change, Inc. (Team ID L2G756LY8N). Our
app is CentMemo (com.learningischange.centmemo, App Apple ID 6837824241), which
has the FinanceKit entitlement. People use it to write a short memo about each
Apple Card purchase.

My question: will Apple give written permission under Section 3.2 for CentMemo
to include FinanceKit data in a read-only connector that a person turns on for
their own AI assistant, such as Claude by Anthropic?

How it would work:
- Off by default. Only the person can turn it on, and they approve it on a
  CentMemo consent page that lists what the assistant can read.
- Read only, enforced in our database. The assistant can never move money or
  change anything.
- Transactions, balances, and the person's own memos and themes only. No
  account numbers and no credentials.
- The person can disconnect it at any time. FinanceKit data is deleted within
  30 days when Wallet access is revoked or the account is deleted.
- Never sold, and never used for marketing, advertising, or personalization.

If the answer is no, would Apple permit the connector to include only the memos
a person wrote about FinanceKit purchases, with no amount, merchant, or account?

If this needs a signed agreement or a different process, please tell me where
to start. Until we have written permission, the connector excludes all
FinanceKit data. I can send screenshots, the consent page, or a test account.

Thank you,
Ben Wilkoff
Learning is Change, Inc.
