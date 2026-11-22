# Merchant tiles, filters, timeline, and color views

Research for CentMemo, 2026-11-22. The question: how to move past plain
lists. How to recognize a charge by its merchant, filter it, see the
story over time, and color it by theme, within our rules. Those rules:
native first, no third-party Swift packages, paper and ink, the
person's color only as marks, no distorted logos, no shame or scoring.

Where a source is a vendor, a forum, or a third party, this doc says so.

---

## 1. Merchant recognition

### What other apps do

- **Apple Wallet / Apple Card.** Shows a cleaned merchant name, a logo
  or a category glyph, and often a map pin. Apple says connected-card
  data "will be used to help improve the accuracy of business names in
  the Wallet card transaction history"
  ([Apple privacy](https://www.apple.com/ca/legal/privacy/data/en/connected-cards/)).
  Businesses set their own logo and name through Apple Business Connect
  ([WWDC25 session](https://developer.apple.com/videos/play/wwdc2025/201/)).
  A person can report "The merchant information for this transaction is
  incorrect" to fix Maps
  ([Apple support](https://support.apple.com/102329)). None of that
  reaches us through FinanceKit. FinanceKit gives `merchantName` and
  `merchantCategoryCode` (ISO 18245), both optional, and no location
  ([Transaction](https://developer.apple.com/documentation/financekit/transaction),
  [forum](https://developer.apple.com/forums/thread/797803)). Apple Cash
  transfers can arrive with both nil
  ([forum](https://developer.apple.com/forums/thread/797799)).
- **Monarch.** Rules rename merchants as they arrive. Bulk edit renames
  many at once. Logos show by default, and a person can upload their own.
  A merchant management page merges duplicates
  ([rules](https://help.monarch.com/hc/en-us/articles/360048393372),
  [multi-edit](https://help.monarch.com/hc/en-us/articles/4402645984916)).
  Its merchant page groups by month, quarter, or year; one user asked
  for an "all visits" view (forum report, 2025).
- **Copilot Money.** Name rules match exact or partial names to set a
  category. They apply to past and future charges. They do not rename
  ([help](https://help.copilot.money/en/articles/3971270-creating-name-rules)).
  Renaming rules are an open request
  ([roadmap](https://roadmap.copilot.money/feature-requests/p/transaction-renaming-rule)).
- **YNAB.** Renaming rules match any exact string inside the imported
  payee ([YNAB](https://support.ynab.com/en_us/how-to-rename-payees-BkotNUSyo)).
- **Lunch Money.** Renaming a payee suggests a rule. Auto rules miss
  when the raw string has unique codes in it
  ([docs](https://support.lunchmoney.app/setup/rules),
  [feedback](https://feedback.lunchmoney.app/rules/p/auto-created-rules-not-matching-apple-pay-payments-on-asn-bank)).
- **Monzo.** Staff say logos are easy to find. The hard part is
  "identifying the correct merchant from the limited information"
  the card networks send
  ([community](https://community.monzo.com/t/merchant-mysteries/70568)).
  The same brand can show up under several names and logos
  ([community](https://community.monzo.com/t/inconsistent-direct-debit-names-logos/125060/26)).
- **Rocket Money, Revolut.** Same pattern: logo when matched, glyph or
  initials when not, a rename that sticks. I found no primary source on
  their internals worth citing.

The lesson: everyone fails to match some merchants. The fallback tile is
not an edge case. It is a main case.

### Name cleaning

Raw descriptors carry processor prefixes, store numbers, and city codes.
Quicken's own example is "SQ*COFFEE1234SHOP"
([Quicken](https://info.quicken.com/win/create-a-payee-renaming-rule)).
A Tiller thread shows "SQ *JOE & TH", cut off at the network's field
length ([Tiller](https://community.tiller.com/t/formating-square-transactions/11934)).

A safe, local, deterministic cleaner:

1. Strip known processor prefixes: `SQ *`, `TST*` (Toast), `SP ` and
   `SP *` (Shopify), `PAYPAL *`, `PP*`, `GOOGLE *`, `AMZN Mktp`,
   `APLPAY`, `IC*` (Instacart), `DD *` (DoorDash), `UBER *`. Keep the
   processor as a quiet fact ("via Square").
2. Drop trailing store numbers (`#1234`, `0042`), phone numbers, state
   codes, and URL tails (`.COM`, `AMZN.COM/BILL`).
3. Title-case, but keep short all-caps brands (CVS, REI, IKEA) from a
   small list.
4. Never guess a full name from a cut-off one. "JOE & TH" stays
   "Joe & Th" until the person names it.
5. The person's rename always wins, and becomes a rule for the same
   cleaned key.

Store the raw string forever. The cleaned name is a view of it.

### Logo sources and their status

| Source | Status | Fit for CentMemo |
|---|---|---|
| Clearbit Logo API | Shut down Dec 2025 (dated Dec 1, then Dec 8) ([Clearbit](https://clearbit.com/changelog/2025-11-24), [HubSpot](https://community.hubspot.com/t/clearbit-logo-api-will-be-sunset-on-december-1-2025/134244)) | Gone |
| logo.dev | Clearbit's named successor. Free tier needs a key and, for commercial use, a visible attribution link (third-party and competitor reports) ([logo.dev](https://www.logo.dev/clearbit), [Brandfetch comparison](https://docs.brandfetch.com/comparisons/logo-dev)) | Workable, but needs a domain per merchant |
| Brandfetch Logo API | Free, "we don't ask for any attribution"; free cap stated as 500K or 1M a month in different places ([guidelines](https://docs.brandfetch.com/logo-api/guidelines)) | Workable, same domain problem |
| Favicons | No terms; low resolution; uneven | Poor |
| MapKit POI categories | `MKPointOfInterestCategory` names (bakery, cafe, gasStation, etc.) ([Apple](https://developer.apple.com/documentation/mapkit/mkpointofinterestcategory)) | Good vocabulary for glyphs; we pick the SF Symbols ourselves |

All logo APIs key on a **domain**. We have a descriptor, not a domain.
Mapping one to the other is the Monzo problem, and every API call
sends a person's merchant list to a third party. That is a privacy
cost in a finance app, and it is a dependency that can be revoked
(`third-party-revocation-resilience`).

Trademark logos are also someone else's art. Shown small and unaltered
next to the merchant's own name, it is common practice. Recoloring,
cropping, or tinting them is not respectful.

**Recommendation:** default to a typographic tile, made on device, with
no network. Treat a logo as a later, opt-in layer, only for merchants
the person confirms, shown unaltered in a fixed, matted slot
(`artwork-presentation-design`).

### The monogram tile

Precedents: Contacts and Messages initials avatars, Gmail letter tiles,
and design-system avatars that pair colors to pass WCAG AA
([Dialpad](https://dialtone.dialpad.com/deploy-previews/pr-1331/components/avatar.html)).
Good practice from those sources:

- Seed the color from a stable key (the cleaned merchant key), never the
  display name, so a rename does not change the color
  ([dev.to](https://dev.to/joshuaslate/deterministic-react-avatar-fallbacks-5ghb)).
- Use a real hash (FNV-1a), not a byte sum, which collides often
  ([Redmine](https://redmine.org/issues/29824?tab=history)).
- Fix saturation and lightness; let the hash choose the hue, or better,
  pick from a short fixed palette. Check text contrast for every pair.

CentMemo's version, within "color as pops" and "brand colors only
chrome":

- **Paper tile, ink letter.** A square tile in the paper color with a
  hairline ink border. One or two letters ("BB" for Blue Bottle) in the
  app's text face, regular weight.
- **One pencil mark.** A short drawn underline or corner tick in one of
  six or eight pencil hues. The hue comes from the merchant key hash.
  The mark helps you spot "the same place again". It means nothing.
- **Category glyph.** A small SF Symbol in the corner (fork.knife, cart,
  car, bag) from the category. Glyph, not color, carries the category,
  so meaning never rests on color alone.
- One tile, one size grid: 28pt in rows, 56pt on the merchant page.
  The web draws the same tile in inline SVG from the same hash, so a
  merchant looks the same on both. That hash needs a golden test on both
  stacks (`cross-platform-determinism`).

---

## 2. Categories

### From MCC to a human set

MCCs are four digits from ISO 18245. They group by range: 4000-4799
transportation, 4800-4999 utilities, 5000-5599 retail, and 3000-3999
named airlines, car rentals, and hotels
([Stripe](https://stripe.com/guides/merchant-category-codes),
[Ramp](https://ramp.com/blog/merchant-category-code-list),
[Wikipedia](https://en.wikipedia.org/wiki/ISO_18245)). There is no one
universal set, and networks differ
([Citi list](https://citi.com/tts/solutions/commercial-cards/assets/docs/govt/Merchant-Category-Codes.pdf)).

Apple Card uses about seven groups, each with a color (third-party
report): Health red, Food and drink orange, Shopping yellow, Travel
green, Transportation blue, Services purple, Entertainment pink
([CreditCards.com](https://www.creditcards.com/card-advice/apple-card-colors/)).

Proposal: one shared table, MCC ranges and single codes to about ten
groups: Groceries, Eating out, Shopping, Home, Getting around, Travel,
Health, Services and bills, Fun, Giving. Apple's category string is a
second source when MCC is missing (CSV imports). Publish the table once
as shared data, so iOS and web never drift.

### Recategorizing and rules

Every app above does the same three things:

1. Change one charge.
2. Offer "Do this for all [Trader Joe's]?" past and future.
3. Show what will change before it applies (Copilot warns rules cannot
   be undone).

For CentMemo, a rule is just the person's sentence: "Trader Joe's is
Groceries." Keyed on the cleaned merchant key. Shown on the merchant
page, editable there. No hidden rules screen.

### The merchant page

A page per place: the tile large, the name, "since March 2024", visit
count, total, and then every visit, newest first, memos shown in full.
This is where the story of a place lives ("every Saturday at the
farmers market"). It answers Monarch's open request for "all visits".
Totals are facts, not grades.

---

## 3. Timeline views

- **Apple Photos (iOS 26).** Years, Months, All, as a segmented control
  over one library ([9to5Mac](https://9to5mac.com/2025/07/01/heres-everything-new-for-apple-photos-in-ios-26/),
  [MacRumors](https://macrumors.com/guide/ios-26-photos-app)). Zoom
  levels of the same thing. Years show one key picture per year.
- **Day One.** A Timeline, plus a Calendar where days with entries are
  colored and empty days invite a backfill. "On This Day" brings back
  past years ([Day One](https://dayoneapp.com/guides/tips-and-tutorials/calendar-view-in-day-one)).
- **GitHub contributions.** A year of days as a grid, shaded by count.
  Critique: color alone fails in sun and low vision; GitHub added a fill
  toggle and keyboard and screen reader support
  ([Roselli](https://adrianroselli.com/2018/02/github-contributions-chart.html),
  [GitHub](https://github.blog/changelog/2023-03-02-accessibility-improvements-for-the-contribution-graph/)).
  Its streak culture is a scoring trap we refuse.
- **Strava Training Log.** Weekly rows, filtered by sport, showing time,
  distance, or elevation, with colored tags
  ([Strava](https://support.strava.com/hc/en-us/articles/206535704-Training-Log)).
- **Gyroscope.** A life dashboard of many streams. Beautiful, but it
  scores, which we don't.

**What suits "the story of my money":** the Day One and Photos model.
A month-by-month timeline where written memos read like journal entries
and unwritten purchases sit as quiet one-line rows. Zoom out to a year
of months. No streaks, no "you missed 12".

---

## 4. Visualization

### What the platform gives us

Swift Charts has `BarMark`, `RectangleMark` (iOS 16+, good for heat
maps), and `SectorMark` (iOS 17+, pie and donut)
([RectangleMark](https://developer.apple.com/documentation/charts/rectanglemark),
[SectorMark](https://developer.apple.com/documentation/charts/sectormark),
[heat map grids](https://books.nilcoalescing.com/swift-charts-beyond-the-basics/arranging-chart-content/heat-map-grids)).
There is no treemap mark. A treemap would be our own squarified layout
drawn with SwiftUI shapes or `Canvas`. On the web, all of these are a
few lines of inline SVG.

### Forms, ranked for CentMemo

1. **Month strip (small multiples).** One thin stacked bar per month,
   split by group, months in a column. Easy to compare. Labels sit
   beside the segments. Strong fit.
2. **Calendar of a month.** Days as cells. Fill = written or not (a
   pencil mark in written days), not dollars. Tap a day to see its
   charges. It shows the habit of noticing, not spending heat.
3. **Treemap of a month.** Area by amount, grouped by theme. Good for
   "where did it go". Hard at phone width with many small charges;
   needs an "everything else" tile.
4. **Donut.** Familiar from Apple Card. Weak for comparing months. Use
   only for one month, with labels.
5. **Sunburst.** Too dense on a phone. Skip.

### Color, honestly

WCAG 1.4.1 says color cannot be the only cue. Technique G111 adds
patterns; F13 calls a color-only chart a failure
([W3C](https://www.w3.org/WAI/WCAG21/Understanding/Use-of-Color.html),
[G111](https://www.w3.org/WAI/WCAG22/Techniques/general/G111.html)).
Lightness steps alone cannot separate three or more colors at 3:1
([WAI-IG thread](https://lists.w3.org/Archives/Public/w3c-wai-ig/2026AprJun/0024.html)).

So: each group gets a glyph and a direct label, and each segment gets a
pencil hatch pattern (lines, crosshatch, dots, stipple). That fits the
sanguine-pencil look and passes 1.4.1. Group colors are a domain
semantic set in `design-tokens.json` (`color.semantic`), never brand
chrome. Swift Charts supports `accessibilityLabel` per mark and Audio
Graphs; the web gets a table twin.

The person's own "value" color, if they mark a charge as one of their
values, is a mark (an underline), not a fill.

---

## 5. Filters on iOS 26 and the web

- **`.searchable` with tokens.** Tokens are chips inside the search
  field; `suggestedTokens` offers them (iOS 16+). Suggested tokens hide
  once text is typed, since iOS 17
  ([Apple](https://developer.apple.com/documentation/swiftui/view/searchable(text:tokens:suggestedtokens:placement:prompt:token:)),
  [forum](https://developer.apple.com/forums/thread/735506)). Good for
  merchant, group, and "unwritten" as combinable filters.
- **`.searchScopes`.** A picker under the field for one exclusive choice
  ([Apple](https://developer.apple.com/documentation/swiftui/scoping-a-search-operation)).
  Good for one axis: All, Written, Unwritten.
- **Filter chips in a row above a list.** Common, but custom on iOS.
  The HIG and native-first point to tokens and a toolbar `Menu` instead.

Recommendation: iOS uses a scope (All / Written / Unwritten) plus
tokens for merchant, group, month, and amount range ("over $100"). A
toolbar `Menu` holds the same filters for people who never search. The
web uses the same verbs as native `<select>` and checkbox chips in a
`<form>`, mirrored in the URL (`?scope=unwritten&group=groceries`).

---

## 6. Naming the all-purchases view

The app keeps "Unexamined" for the unwritten queue. The full list needs
a word that fits a story app.

| Name | For | Against |
|---|---|---|
| Ledger (now) | Accurate | Accountant's word; frames money as debits |
| Timeline | Plain, known from Day One, matches the view | Generic; says "how", not "what" |
| Days | Warm, simple | Weak once the view zooms to months and years |
| Moments | Warm | Overclaims for a gas charge; Apple Photos baggage |
| Record | Honest, neutral | Dry; verb/noun ambiguity |
| Chronicle | Story-first | Grand; long for a tab |
| Almanac | Charming | Means forecasts and tables, not a diary |
| Logbook | Fits pencil and paper | Sounds like maintenance |
| Diary | Fits memos | Feels private and daily; odd for numbers |
| Story | Matches "every cent tells a story" | Singular, abstract as a tab |

Best fits: **Timeline** (clearest) or **Chronicle** (most on-voice).
"Unexamined" pairs well with "Examined" as the written view, but that
splits one list into two. The owner should choose.

---

## Recommendations for CentMemo

In order.

**1. The merchant tile, everywhere.** On device, no network. Cleaned
name, monogram on paper, one pencil mark from the hash, a category
glyph. Shared golden test for the hash and the cleaner across Swift and
JS. Every row in every list gets it. *Screen:* a row reads tile, then
"Blue Bottle" in body weight, then the memo's first line in ink below
it, amount right-aligned. An unwritten row has no second line and the
name in secondary ink.

**2. Name cleaning plus "call it this".** The local cleaner, the raw
string kept, and a rename that becomes a rule for that merchant key.
*Screen:* on a purchase, tap the name; a sheet shows the raw descriptor
small, a text field, and a toggle "Use for all 14 visits".

**3. The merchant page.** *Screen:* big tile, name, "Since Mar 2024 ·
31 visits · $412". Below, the group with a "Change" control (the rule
lives here). Then every visit, newest first, written memos in full,
unwritten ones as one quiet line with a "Write" affordance.

**4. Rename Ledger and make it a timeline.** *Screen:* months as
section headers ("November 2026", written count as a fact: "9 of 23
have a story"). Written purchases show the memo like a journal entry.
Unwritten ones are single quiet lines. A segmented control at top:
Months / Years. Years shows each year as twelve thin month strips.

**5. Filters with search tokens.** Scope: All / Written / Unwritten.
Tokens: merchant, group, month, amount. A toolbar `Menu` for the same.
Web mirrors in the URL.

**6. The month strip.** *Screen:* a column of months; each is one
stacked bar by group, hatched and labeled, total at the right. Tap a
segment to open the timeline filtered to that month and group. Swift
Charts `BarMark` on iOS, inline SVG on web, a table for screen readers.

**7. The calendar of noticing.** *Screen:* one month as a grid; a day
with any written memo gets a pencil tick; tap a day for its charges.
No streaks, no counts of misses.

**8. Later, opt-in: logos.** Only after 1-7 ship and people ask. Per
merchant, the person confirms the domain; fetch from Brandfetch (no
attribution required) or logo.dev; show unaltered in the tile's matted
slot; keep the monogram if it fails. Log it in DECISIONS.md as a
third-party dependency with a revocation plan.

Before building, run `learning-orientation-design` on items 6 and 7:
a chart can invite reflection ("why was March all Eating out?") or
invite judgment. Labels are facts, never verdicts.
