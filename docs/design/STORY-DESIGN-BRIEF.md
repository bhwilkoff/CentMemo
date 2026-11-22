# Story design brief (binding for the launch loop until Ben signs off)

Ben, 2026-11-22, verbatim:

> Before we submit the iOS app, we need to do a lot more design work for how
> the memos show and the diffrent views for the financial data. I've opened my
> iPhone Duo for you to use for testing and design. Right now, everything in
> the app seems like a list and entirely unfriendly to someone who cares about
> building out a story with their money. Can you do some research for how to
> best build out the memo writing tools and making it friendly to regularly
> check in and write stories about your charges. We also need some more
> sophisticated ways of categorizing and displaying different charges to
> different vendors/companies/stores. The app should always be beautiful and
> encourage users to tell stories. They should be able to share their stories
> or collect them into sets that are about the kinds of values the user wants
> to highlight. There should be recommendations for what to write memos about.
> Each memo should show as an achievement in your life rather than a debit to
> your bank account. Please continue to research journaling apps, storytelling
> categories, ways of recognizing individual items with well-designed tiles (or
> some other design element). Please build out the tools to design and test on
> the iPhone duo (from the other apps that have done this) and also make sure
> that they look great on the iPhone 12 as well. Add these instructions to the
> loop so that you can keep on improving things, including all language (I like
> unexamined as a category... "the unexamined life" being the reference there,
> but what about "ledger"? Is that the right way to help show the items? Should
> you be able to filter things and show just some kinds of items? Is there a
> timeline view that could help show progress over time? Is there a
> visualization view that we could utilize to show color coded charges or
> themes?). Lots of work to do before we submit the first version of our app to
> the app store.

## Ben's choices, 2026-11-22 (from the directions page), verbatim

> 1. The word Memo is literally in our app name, so we really should be
> leveraging it as much as possible. By keeping the word as "memo" it keeps the
> barrier to entry very low. The idea is that the sum of all of the memos is the
> story of your life, not that you are turning a single memo into a story.
> 2. The Chronicle view is the most polished and it shows the timeline well, but
> the word Chronicle is not going to be interesting to very many people. I think
> "Narrative" is probably the best word to describe all of the events as they
> come in from your Apple Card. You are writing memos into the narrative and
> when they are put together, they become the story.
> 3. I like themes as the collections naming and they came be used as shorthand
> for different types of events within the narrative or they can describe your
> values and what you want the events to show.
> 4. You should be able to ignore, skip, or otherwise swipe away the individual
> events from the narrative, as if they were unimportant details to the story.
> Only the important "plot points" will show in the story and not everything
> that is charged to the card.
> 5. Merchant doesn't really fit with the metaphor that the app is attempting to
> create. We are talking about parts of a story. The "places" that a story
> happens is generally known as the Setting, so we should make use of that as
> well.
>
> So, overall, the chronicle is the design I'd like to iterate on and take
> components of the other designs when they are relevant. Let's continue to
> iterate on the language based upon my recommendations as well.

**Vocabulary (binding, Decision 065):**

| Thing | Word | Never |
|---|---|---|
| A charge as it arrives | an event in the **Narrative** | transaction (on screen), Ledger, Chronicle |
| The view of every event in order | **Narrative** | Ledger, Chronicle, Timeline |
| What a person writes on one event | a **memo** | a story (one memo is not a story) |
| All memos put together | the **Story** | |
| An event worth a memo | a **plot point** | |
| Swiping an event away | **Skip** (a detail, left out of the Story) | delete, hide |
| A collection, a value, a kind of event | a **Theme** | value, set, category |
| Where it happened | the **Setting** | merchant, vendor, store |
| Purchases with no memo yet | **Unexamined** | |

Direction: C (the Chronicle design) is the base; components from A (three
suggestions with reasons, the memo as headline) and B (theme collections,
the Setting page) join where they fit.

## Work items (D = design before submission; L2 waits on all of them)

- D1 ✅ Research: journaling apps, check-in habits, prompts for what to write
  (`docs/research/story-design-research.md`).
- D2 ✅ Research: merchant recognition and tiles (vendor/company/store), richer
  categories, timeline and color-coded visualization, sets and sharing.
- D3 ✅ (design_shots.py on both phones; two panes at regular width, DuoTwoPaneUITests) Device tools: the iPhone Duo design and test harness, ported from Ben's
  other repos; every screen checked on the Duo AND the iPhone 12.
- D4 🟡 (vocabulary chosen by Ben, table above; applying it everywhere ⏳) Language: keep "Unexamined" (the unexamined life); propose options for
  "Ledger" and every other screen word. Ben chooses.
- D5 ✅ (Ben chose C, with parts of A and B; https://claude.ai/artifact/TtRywFmQhiiq9Mdg1Q2jPu) Directions: three design directions drawn from the research; Ben chooses
  or mixes (propose, don't decide).
- D6 🟡 (event page leads with the Setting tile and the memo; money and bank facts in a footnote; a pencil stroke draws in on save ✅ iPhone 12 + Duo; Narrative/Story rows next) Memo as achievement: a written memo reads as a moment in a life, not a
  debit.
- D7 Writing tools: friendly regular check-in, recommendations of what to
  write about.
- D8 🟡 (name cleaning + store tiles on iPhone and web ✅; store page, renames, categories ⏳) Merchant tiles and categories.
- D9 Filters (show only some kinds of items).
- D10 Timeline view: progress over time.
- D11 Visualization: color-coded charges or themes.
- D13 🟡 (iOS swipe + detail menu, web detail button, Narrative 'N skipped' group, Unexamined excludes ✅; connector tool ⏳) Skip: swipe an event away as a detail; only plot points reach the Story.
- D12 Themes (Ben's word for sets): collect stories into sets by value; share a story or a set.

## Sources (Ben, 2026-11-22)

> So long as the CSV pathway works from the venmo, paypal, and cashapp mobile
> apps, we should build for it.

- S1 Venmo CSV import (the monthly statement export exists on the phone; its
  Note column arrives as the memo).
- S2 PayPal and Cash App CSV import, once a real export from each phone app
  confirms the pathway and the columns.
- S3 The connector returns memos with date, amount, and Setting, so a
  person's Claude can match them to the bank data Claude Personal Finance
  already reads (Plaid).
- S4 FinanceKit rows in the connector: Ben's direction is to build it whole
  and let App Review judge it inside the app (see AUTONOMOUS_PROGRESS.md,
  2026-11-22, for the adversarial read and the open choice).

Each tick: take the top open D item, ship it with verification on BOTH phones
(screenshots read before "done"), log it in AUTONOMOUS_PROGRESS.md.
Guardrails: learning-orientation-design and money-story-design (no shame,
streaks, scores, AI-written memos or lists); DESIGN.md (paper, ink, sanguine
pencil, color as marks; no handwriting fonts).
