# Apple Wallet data in the Claude connector: the turn-on commit

Status: **built, off.** Decision 066.

Apple answered on 2026-11-23 (Kavya, Wallet Entitlements, Case-ID 23676235):
they are "unable to provide guidance or confirmation" on whether the connector
is permitted. The reply also appreciates the decision to exclude FinanceKit
data "until you receive the appropriate clarification". So the entitlement
team won't decide this; App Review is the likely venue. Ben, 2026-11-23,
after reading that: keep it off for now and revisit it at the L2 submission.

Ben asked who can decide. Kavya, 2026-11-24, same case: "We recommend contacting
Apple Developer Support and requesting guidance from the team responsible for
the FinanceKit APIs Addendum and related contractual permissions." The
entitlement is unchanged. This is a referral, not a yes: the switch stays off.
Ben sent the question on 2026-11-24, Case ID 103023652799
(`docs/store/DEVELOPER-SUPPORT-QUESTION.md`).

Ben, 2026-11-22: "let's build everything as if we can send the apple wallet
data to claude, but let's draft the email and see what they say rather than
turning it on before any kind of response."

## What is already built

- The server reads Wallet events through `guarded()`. With
  `SHARE_FINANCEKIT = true` every tool returns them, and `spending_summary`
  stops excluding them. Accounts are labeled "from FinanceKit".
- `ConnectorPolicy.sharesWallet` (iOS) drives the disclosure shown before
  Wallet access is asked (Addendum 3.3).
- `tests/connector_policy.test.mjs` fails unless the server switch, the iPhone
  switch, and every page promise agree. A negative control is included.

## The one commit, after Apple says yes (quote Apple's reply in the message)

1. `supabase/functions/mcp/index.ts`: `const SHARE_FINANCEKIT = true;`
2. `tests/connector_guard.test.mjs`: change the "switch is off" test to expect
   `true`, and name Apple's reply in its comment.
3. `apple/Core/Finance/ConnectorPolicy.swift`: `static let sharesWallet = true`.
   `WalletSyncUITests` then expects the new disclosure ("If you connect Claude,
   it can read them too").
4. Rewrite the promises, word for word:
   - `connect/index.html`: "Purchases synced from Apple Wallet are never shared
     with Claude. ..." becomes "**Claude can read your Apple Wallet purchases
     too**, once you connect it, and never change them. Turn it off any time
     by removing the connector in Claude."
   - `support/index.html`: "and never sees Apple Wallet purchases" becomes "and
     reads Apple Wallet purchases only if you connect it".
   - `docs/store/REVIEW-NOTES.md`: "and never includes Apple Wallet (FinanceKit)
     data" becomes "and includes Apple Wallet (FinanceKit) data only after the
     person connects it, with Apple's written permission (Case-ID 23676235)".
   - `privacy/index.html`: already says data reaches Anthropic only if you
     connect Claude; add "including Apple Wallet purchases".
   - App Store listing and Connectors Directory text (`docs/store/LISTING.md`,
     `docs/store/DIRECTORY.md`): drop "never sees Apple Wallet data".
5. Run `node --test tests/*.test.mjs` (the policy test passes only when 1-4
   all changed), deploy the function, and run `tools/test_connector.mjs`.
6. If Apple allows only memos (the fallback question): don't flip the switch.
   Add a memo-only read for FinanceKit events instead (memo text, themes and
   date; no amount, Setting, or account), with its own test.
