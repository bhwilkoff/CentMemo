# Connectors Directory submission: answers, ready for the session with Ben

Form: claude.ai/directory/manage > Submit new > MCP connector (7 steps).
Ben's parts: adding the connector at the new address (his Apple sign-in),
the listing words (AGENTS.md: no AI-written copy), the Compliance
acknowledgments, pasting the reviewer password into Additional notes
(Decision 064), and Submit.

## 1. Source
- Server: add a custom connector at **https://mcp.centmemo.com** (Ben's
  current "Centmemo" connector uses the old Supabase address; remove it or keep
  it, both work). Sign in with Apple when Claude asks.
- URL configuration: Everyone uses the same URL.
- Authentication requirement: Always required.
- Method: OAuth sign-in, **Dynamic Client Registration** (RFC 7591; PKCE S256).
- No additional headers.

## 2. Content
- Six tools, detected from the server: List accounts, Get balances, Search
  transactions, Spending summary, Unexamined purchases, Get memos. Every one
  read-only (readOnlyHint true, destructiveHint false, openWorldHint false),
  with a title.

## 3. Listing (DRAFT, Ben edits; from his own words)
- Name: CentMemo
- Tagline: Every cent tells a story            <- Ben
- Description: Each purchase on your card is a marker of something that
  happened in your life. CentMemo is where you write the memo for each one;
  this connector lets your own Claude read those memos and your imported
  purchases, so it can help you understand your money. It can read, never
  change, and it never sees Apple Wallet data.   <- adapted from Ben's
  "It is a marker of something that happened in your life" and "it can help
  you to understand and do things about your money, but the story is being
  told and captured in CentMemo"
- Use cases (examples people can ask):
  - Which purchases this month don't have a memo yet?
  - What did I spend on things I tagged "time with my kids" this fall?
  - Read me my memos from October.
- Icon: assets/brand/icon-512.png (the circled cent, Decision 061).
- Links: website https://centmemo.com, docs https://centmemo.com/connect/,
  support https://centmemo.com/support/, privacy https://centmemo.com/privacy/.
- Company: Learning is Change, Inc.; contact hello@centmemo.com.

## 4. Test & launch
- Reviewer account: **review@centmemo.com** (Decision 063), seeded with the
  synthetic sample (22 purchases, 4 memos). The password is in
  ~/.centmemo/test-users.json on Ben's Mac; **send it by email**, never in
  the portal. Sign-in path: the consent page's "Reviewer sign-in".
- Verified end to end: tools/test_connector.mjs (25 checks through
  https://mcp.centmemo.com) and the reviewer path in tools/test_web_states.mjs.

## 5. Data handling
- Reads: accounts, balances, transactions from imported Apple Card exports,
  memos, and values, as the signed-in person under row-level security.
- Never: Apple Wallet (FinanceKit) data (Addendum 3.2; SHARE_FINANCEKIT =
  false); writes of any kind (refused in SQL for agent tokens).
- CentMemo receives no conversation data: Claude calls the tools; CentMemo
  stores nothing from the call.
- Retention: data lives in the person's CentMemo account until they delete it
  (Settings > Delete account removes everything at once).
- Privacy policy: https://centmemo.com/privacy/

## 6. Compliance (Ben acknowledges)
- Financial transactions: read-only; cannot move money, change records, or
  initiate anything.
- Prompt injection: merchant names, descriptions, and memos are returned as
  labeled data with control characters removed and lengths capped, with a note
  that they are data, never instructions.
- Conversation data: not collected.

## 7. Review and submit (Ben)
