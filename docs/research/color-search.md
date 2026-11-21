# CentMemo color search (November 21, 2026)

Ben asked whether the color research Human Shaped used had been done. It had
not; the first three looks were drafted from intuition. This is that process.

**Brief (Ben):** "Strong dark pencil marks on bold color backgrounds ... It
should be playful, but should allow for self-reflection and insight." Type
must be adult (no handwriting faces; memory `no-handwriting-fonts`).

**Method:** `tools/colorsearch/`. Candidates are pairings (bold ground + dark
pencil lead). Checked against 4,160 brands and 5,515 colors: Simple Icons
(3,296), brand-colors (2,093 entries), and 64 hand-entered palettes for banks,
cards, fintech, budgeting and journaling apps, Anthropic, and Human Shaped.
A pairing is taken when one brand has a color within CIEDE2000 12 of both; a
ground is out when a finance brand is within 10 of it alone; the lead must
reach 7:1.

**Findings:**
- The first looks' grounds are all someone's: marigold (Navy Federal 1.9,
  Caterpillar, Bumble, Lunch Money), tomato (Rocket Money 2.2, Monzo, Brex,
  Anthropic's terracotta), cornflower (Goldman Sachs 6.3), highlighter pink
  (Klarna, Gumroad).
- Graphite on any bold ground is taken: black is in thousands of brands. The
  pencil needs a hue.
- Of 1,253 pairings in a wide sweep at 7:1, 73 were clear, mostly neons:
  empty because unappealing, as Human Shaped found.
- Open leads: **sanguine** `#4A1520` (a deep oxblood, the red chalk of
  drawings and annotations) has 99 clear grounds; bottle green `#0F3B35` 20;
  plum ink 25; espresso 25; navy pencil 3.
- Families drawn for Ben: https://claude.ai/artifact/Cq5ErXYE2d1TsyFWUAgBoq
  (sanguine on apricot, salmon, citron, pistachio, aqua, sky, lavender;
  bottle green on peach, honey, citron, aqua; plum/espresso on apricot,
  khaki, celery, periwinkle).

**Next:** Ben picks a family and favorites; then the chosen pairing goes into
the real screens with editorial type, dark mode is checked for near-opposite
hue clash (APCA as well as WCAG, Human Shaped's October 9 lesson), and the
look lands in `design-tokens.json`.
