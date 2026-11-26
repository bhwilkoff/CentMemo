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

**C3. Color means something, never chrome. The person's color (aqua by
default) and each theme's color have these jobs:**
1. **What still needs you.** On the Unexamined screen, where every row is
   waiting, only the count sits on the person's color (one mark, not fifteen).
   In the Ledger, where examined and waiting purchases mix, a purchase
   without a memo carries a stroke of the color behind its amount, like a
   highlighter; writing the memo removes it. When everything is examined, the
   color is gone from the screen: the reward is a calm page, not a badge.
   On the light page the color is soft (about 1.8:1), so it is never the only
   signal: the waiting row also has no memo line, and the count is ink text.
2. **What you value.** Each theme carries its own color (D14). On a memo and
   in the Story a theme chip shows it as a mark: a dot beside the name, and a
   stroke of the color when the theme is on. The words stay ink. (Was: chips
   filled with the person's one color; Ben, 2026-11-26: "they are not
   color-coded as they should be".)
3. **Starter themes where there are none** (W1). With no themes, the memo's
   Themes row and the Story's shelf offer Ben's starters in place, each with a
   dashed outline or mark in the color it would take; a tap adds it. Settings
   lists the starters not yet held. No slide deck.

On screen it is called **Color** (Ben, 2026-11-24). "Ground" survives only in
code and the database, from 059.

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

## W. Every width, designed on purpose

Ben, 2026-11-24: *"The design of any app layout should be done with design
skills for that specific device size. Design and implement for every screen
size."* The branch is on the room a screen has, never on the device.

| Class | Room | Where it happens |
|---|---|---|
| Compact | under 700 | iPhone 12, the closed Duo, a phone browser |
| Medium | 700 to 1099 | the open Duo, iPad portrait, a small Mac window, a tablet browser |
| Wide | 1100 and up | iPad landscape, a Mac window, a desktop browser |

- **W1. Compact is one column that pushes** (D2 first). Nothing below changes it.
- **W2. The list gets the room its words need.** 380 at medium, 440 at wide: a
  row's date and place stay on one line, and names the year only when it isn't
  this one.
- **W3. The purchase page is a desk at wide.** The memo is the page you write
  on (taller, never wider than 640); what belongs to it (themes, photos, files,
  the place, the bank's facts) stands beside it in a 340 column. Below that room
  they follow the memo, as on the phone. The pane needs 780 for the desk.
- **W4. The Story is read, not managed.** At medium and wide its themes and
  months are a shelf on the left; the memos are one reading column on the right,
  in the memo's own serif, with the Setting and the date beneath each. Opening
  one pushes its page.
- **W5. A line of reading is never longer than 640.** The column is centered in
  its room; the room is left empty on purpose.
- **W6. A Setting's place stands beside its visits at wide**, a 340 card with
  the map, not a strip across the page.
- **W7. Seeing it.** Every class is captured and read before a change is called
  done: iPhone 12 and the Duo both ways, iPad both ways, the Mac at 900, 1180 and
  1600, the web at 375, 768, 1024 and 1440 (`tools/test_web_states.mjs --widths`).
- **W8. A column's title belongs to its column.** With two columns the section's name
  stands over the left one and never moves when the right one scrolls (Ben, 2026-11-25:
  "That shouldn't happen"). The navigation bar's large title follows whichever column
  scrolls, so it is not used there (`columnTitle`, `TwoColumnUITests`).

## S. The share (N4)

Ben, 2026-11-24: *"It should be well designed to highlight the 'setting', the
'MEMOry', and the themes. No amount of money should ever be shared. You should
be able to design your 'share'."*

- **S1. The card is never given an amount.** The drawing takes the memo, the
  Setting, the date and the themes (`js/money/share-card.js`, `apple/Core/ShareCard.swift`). `tests/share_no_money.test.mjs` holds it.
- **S2. The person designs it, and CentMemo suggests nothing.** They underline
  the words that matter in their own memo (first word, then last), and choose a
  look, a paper, a shape, and what shows.
- **S3. Four looks, each leading with one thing.** Page: the memory. Setting: the
  place, its tile, the date in a pencil loop. Theme: the theme as the card's
  spine. Words: the underlined words, large, with the whole memo beneath.
- **S4. The memo sets its own size:** the largest that fits. A memo too long for
  its shape ends in an ellipsis on the card, never in smaller type than reads.
- **S5. A card may wear its theme's color as its paper.** This is the one place
  color is a ground (C1 is about the app's pages): the card is an object someone
  sends, and cream on every theme color passes 4.5:1.
- **S6. A whole theme has three looks.** Cover: its name and its Settings. Pages:
  its memos, each with its Setting and date. Lines: the words the person
  underlined in each memo, one under another, so a theme reads as a poem of their
  own words (a memo with no underline gives its first sentence). Any memo can be
  left out; what does not fit is counted ("and 12 more"), never shrunk past reading.
- **S7. A story link is a page, not a picture.** Ben, 2026-11-24: *"I really like the
  bold colors and the touch of the pencil marks. I'd like to be able to choose which
  words get the underline."* Bold (the theme's color as the page) is where it starts;
  the writer chooses the marked words, the pencil (underline, two lines, circle,
  highlight), the color, what leads, the parts of a theme's page, and the place, time
  and name in their own words, beside the reader's page, live. One module draws both
  (`js/money/story-page.js`). What may be published is Decision 067.
- **S8. The pencil is the same four marks on cards and links** (underline, two lines,
  circle, highlight). The circle clears the first and last letters; the highlighter
  sits under the words and, on a color page, darkens it (a white one measured 2.97:1;
  dark is 7:1 or better). A look that draws no mark hides the choice.
- **S9. On Apple devices the link's preview is the site's own page code**, bundled
  (`StoryPagePreview`), with no network. Beside the choices from 640pt (the open Duo gives a
  sheet 653pt whatever is asked for); above them on a
  phone, shrinking while typing. Every filled field keeps its label.


## E. The memo editor (W3 and W4, Decision 069, Ben 2026-11-26)

**E1. No Save button.** The memo sends itself after a pause and at once on leaving.
Nothing says "Saved"; only a failure speaks, under the memo, in ink with a cloud-slash.
**E2. Six styles, no seventh.** Bold, italic, strikethrough, a heading (the memo's
serif at title3, bold), a bulleted line, a quote (indented, italic, quiet ink). No
underline in a memo: underline is the share's pencil mark (S). No colors or sizes.
**E3. Where the styles live.** iPhone and iPad: a bar over the keyboard drawn like the
keyboard, the six styles in sanguine, then Done; never a menu (it moved the caret).
Mac: the Format menu and its shortcuts. Web: a bar of six buttons above the memo.
