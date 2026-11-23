# CentMemo design rules (binding, all platforms)

Rules every platform follows; per-platform idioms differ (web views, SwiftUI
lists), the rules do not (`binding-design-doc-discipline`). Quote the rule
before proposing UI; when a proposal and a rule conflict, fix this doc first.
Sources: `mobile-first-density-design`, `money-story-design`, Human Shaped's
palette lessons (DECISIONS, October 6 and 9), Ben's notes (memories
`color-as-pops`, `no-handwriting-fonts`).

## C. Color placement (Decision 060, replaces the full-screen ground of 059)

**C1. The page is paper and the text is ink.** Every screen's background is
paper (near-white; near-neutral in dark mode). Body text is ink (near-black
with a faint sanguine warmth), because reading comes first. Ben: "having an
entire background of an app be aqua ... reads as too much color. It also
makes the text harder to read."

**C2. Sanguine is the pencil (brand).** Page titles, actions, links, the
selected tab, focus rings, and every drawn mark (the circled count, rules)
are sanguine. It never carries content meaning.
*iOS*: ink is the system label color, set by nothing. A screen-wide
`.foregroundStyle(ink)` outranks the tint, which turned every button ink
(measured on the iPhone 12, 2026-11-22); give ink only to the views that
need it, never to a whole screen.

**C3. The person's color (aqua by default) has exactly two jobs, both
meaning, never chrome:**
1. **What still needs you.** On the Unexamined screen, where every row is
   waiting, only the count sits on the person's color (one mark, not fifteen).
   In the Ledger, where examined and waiting purchases mix, a purchase
   without a memo carries a stroke of the color behind its amount, like a
   highlighter; writing the memo removes it. When everything is examined, the
   color is gone from the screen: the reward is a calm page, not a badge.
   On the light page the color is soft (about 1.8:1), so it is never the only
   signal: the waiting row also has no memo line, and the count is ink text.
2. **What you value.** The values the person names (chips on a memo and in
   the story) are filled with their color, because they are theirs.

Nothing else is colored: no colored headers, bands, cards, tab bars, or
backgrounds.

**C4. One focal point per screen.** If a screen has nothing unexamined and no
values, it has no bold color. That is correct.

**C5. Pops keep their light value in dark mode.** The person's color stays
bright on the dark page (it is a mark, not a ground), and text on it is ink
in both modes. `tools/test_grounds.mjs` checks ink on every color at 4.5:1
and every color against the dark page at 3:1 (non-text marks).

**C6. Semantic colors stay semantic.** Credits are green, errors red, on
paper. Spending is ink, never red.

## T. Type

**T1. Six levels, no seventh** (`mobile-first-density-design` rule 2).
Display serif (Newsreader on web, New York on Apple) for L1 page titles and
for the person's memos; the system face for everything else; tabular
figures for money.

**T2. No handwriting or informal typefaces anywhere.** The pencil is drawn,
not typeset.

## M. Marks

**M1. Drawn marks are few and mean something:** a circle around the
Unexamined count; a faint wavy rule between rows (web) or the system divider
(iOS). No doodles for decoration.

## D. Density

**D1. No tinted boxes on rows.** Paper cards only where the person reads or
writes at length (the memo field, story entries).

**D2. Test at 375px first,** light and dark, before desktop.

## L. Regular width: the open iPhone Duo (and any wide window)

Ben, 2026-11-22: *"The duo column design still looks terrible. With the
padding being inconsistent across multiple surfaces."* These rules follow Ear
Drama's iOS-DESIGN §3.6, which already solved this. They are measured, not
guessed: `tools/design_shots.py --device duo`, with guide lines drawn on the
inner-display frame.

- **L1. One stack per screen.** At regular width a list and the purchase it
  opens are a plain column beside a pane, inside ONE NavigationStack
  (`TwoPane`). A stack per pane picks up the tab strip's 84pt inset, and the
  list ended short of the divider.
- **L2. Two edges in the column.** Words (the screen title, rows, totals,
  the month bar, the thread) stand **20pt** in from both edges of the column
  (`PaneEdges.words`, `columnRowInsets()`). Boxes (suggestion cards) stand
  **16pt** in (`PaneEdges.box`). Amounts end on the words edge, never at the
  divider.
- **L3. The pane keeps 20pt from the divider and from the strip**
  (`PaneMargins`). A List counts content margins from its own edges, so the
  margin adds the List's measured safe-area insets; the header stands on the
  cards' edge.
- **L4. Compact is unchanged.** Every closed phone and the iPhone 12 keep
  16pt. The branch is on width only, never on the device.
- **L5. Seeing it.** Any regular-width change is captured on the Duo's inner
  display and checked against the guides at 16, 20, column−20, column−16,
  divider+20 and strip−20 before it is called done.
