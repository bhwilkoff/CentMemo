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

## Work items (D = design before submission; L2 waits on all of them)

- D1 ✅ Research: journaling apps, check-in habits, prompts for what to write
  (`docs/research/story-design-research.md`).
- D2 ✅ Research: merchant recognition and tiles (vendor/company/store), richer
  categories, timeline and color-coded visualization, sets and sharing.
- D3 🟡 (design_shots.py on both phones ✅; Duo layout rules ⏳) Device tools: the iPhone Duo design and test harness, ported from Ben's
  other repos; every screen checked on the Duo AND the iPhone 12.
- D4 Language: keep "Unexamined" (the unexamined life); propose options for
  "Ledger" and every other screen word. Ben chooses.
- D5 Directions: three design directions drawn from the research; Ben chooses
  or mixes (propose, don't decide).
- D6 Memo as achievement: a written memo reads as a moment in a life, not a
  debit.
- D7 Writing tools: friendly regular check-in, recommendations of what to
  write about.
- D8 Merchant tiles and categories.
- D9 Filters (show only some kinds of items).
- D10 Timeline view: progress over time.
- D11 Visualization: color-coded charges or themes.
- D12 Sets: collect stories into sets by value; share a story or a set.

Each tick: take the top open D item, ship it with verification on BOTH phones
(screenshots read before "done"), log it in AUTONOMOUS_PROGRESS.md.
Guardrails: learning-orientation-design and money-story-design (no shame,
streaks, scores, AI-written memos or lists); DESIGN.md (paper, ink, sanguine
pencil, color as marks; no handwriting fonts).
