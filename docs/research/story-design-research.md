# Story design research: writing memos as moments

Date: 2026-11-22. Scope: how CentMemo should invite, shape, celebrate,
collect, and share the short memo ("story") a person writes for a
purchase. Constraints held throughout: no AI-written memos, summaries,
or lists; no shame, streaks, scores, or guilt budgeting; no handwriting
fonts; paper, ink, sanguine pencil, and the person's color as marks only.

Sources are linked inline. Third-party reviews and store listings are
marked as such; check them before quoting in product copy.

---

## 1. Journaling apps and check-in design

**Apple Journal.** Suggestions are built on device from "new places
they've visited, photos they've taken, songs they've played, workouts
they've completed." Daily reflection prompts "focus on gratitude,
kindness, purpose, and more." Scheduled notifications "help make
journaling a consistent practice." Entries are end-to-end encrypted
([Apple Newsroom](https://www.apple.com/newsroom/2023/12/apple-launches-journal-app-a-new-app-for-reflecting-on-everyday-moments/)).
Reviewers note prompts tied to a suggestion, such as "What was the
highlight of your trip?", and a separate notice when new suggestions
are ready ([MacStories](https://www.macstories.net/reviews/apples-journal-app-journaling-for-all/),
[MacRumors](https://www.macrumors.com/how-to/use-apple-journal-app)).
Key lesson: the prompt names a moment the person already lived. It
does not ask them to perform.

**Journaling Suggestions API.** Third-party apps get a system picker.
The app sees nothing until the person picks a suggestion. Asset types
include locations (with place names and a work flag), contacts,
workouts, photos, media, reflections, and State of Mind
([Apple docs](https://developer.apple.com/documentation/journalingsuggestions),
[WWDC24](https://developer.apple.com/videos/play/wwdc2024/10209/),
[Tech Talk](https://developer.apple.com/videos/play/tech-talks/111384)).
Day One adopted it with the same rule: no data access until the person
chooses ([Day One](https://dayoneapp.com/features/journaling-suggestions/)).
For CentMemo, a place or person suggestion could sit beside a purchase
("who were you with?"). That is optional, iPhone only, and later.

**Day One.** On This Day shows entries from the same date in past
years, newest year first, from Today view, a widget, and the web
([On This Day](https://dayoneapp.com/features/on-this-day/),
[Today view](https://dayoneapp.com/guides/tips-and-tutorials/today-view/)).
It has daily prompts, Prompt Packs (themed human-written banks),
templates, multiple journals, and printed books
([App Store](https://apps.apple.com/us/app/day-one-2-journal-notes/id1044867788)).
Lesson: the archive becomes the reward. Your own past words are the
best prompt.

**Stoic.** Morning "prepare" and evening "reflect" flows with
editable questions. Reviewers complain when prompts repeat
([App Store](https://apps.apple.com/us/app/stoic/id1312926037)).
Lesson: a bank needs size and rotation, and the person must be able to
switch prompts off.

**Five Minute Journal.** A fixed, short morning and evening flow
built on gratitude, with custom questions
([App Store](https://apps.apple.com/app/id1062945251)). Lesson: a
fixed tiny form lowers the cost of starting.

**Grid Diary.** An entry is a grid of questions. The classic version
put eight prompts around a center square holding the date and mood.
"Randomize" swaps only unanswered prompts
([Macworld](https://www.macworld.com/article/2055508/grid-diary-makes-keeping-a-journal-as-easy-as-filling-out-a-form.html),
[griddiaryapp.com](https://griddiaryapp.com/)). Lesson: let people
skip a prompt without skipping the entry.

**Daylio.** One-tap mood plus activity icons, a preset list the person
edits, and custom activities with a large icon set
([Wikipedia](https://en.wikipedia.org/wiki/Daylio),
[daylio.net](https://daylio.net/)). A clinical review frames it as
tracking moods and activities to find patterns
([JMIR mHealth](https://pmc.ncbi.nlm.nih.gov/articles/PMC5344152)).
Lesson: tags are a micro-entry. A tag with no words still counts.

**Journey, Momento, Reflectly.** Journey offers 60+ guided programs
with human-written prompts, and now an AI layer
([App Store](https://apps.apple.com/app/id1300202543)). Momento pulls
in posts and check-ins as raw material
([App Store](https://apps.apple.com/app/id980592846)). Reflectly leans
on AI conversation. CentMemo should borrow Momento's "your life is
already the outline" idea, which matches purchases as raw material. It
should refuse the AI layers.

**What makes check-ins inviting without streaks.**
- The prompt points at a real, recent event, not a blank page.
- The smallest valid entry is tiny: one value tag, or one line.
- Gaps are silent. No "you missed 4 days," no broken chain.
- Past entries come back as gifts (On This Day), not as debts.
- Prompts can be skipped, swapped, or turned off.

**Notifications that respect people.** Apple's HIG asks for explicit
consent for promotional notices, warns against several notices about
one thing, and asks for honest interruption levels
([HIG: Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications),
[HIG: Managing notifications](https://developer.apple.com/design/human-interface-guidelines/managing-notifications)).
Nielsen Norman Group makes the same case
([NN/g](https://www.nngroup.com/articles/push-notification/)).
For CentMemo: off by default; the person picks a weekly or daily time;
one notice at most, naming one moment ("Saturday at the farmers
market"), never a count of unwritten purchases; passive interruption
level; no notice when nothing is worth writing about.

---

## 2. Prompt design: what to write about

Good suggestions come from the data, are shown with their reason, and
are few. Apple's model is "first visit to a place, a trip, a person."
The purchase version is below.

FinanceKit gives each transaction a date (`transactionDate`,
`postedDate`), amount and `creditDebitIndicator`, `merchantName`,
`merchantCategoryCode` (MCC), `transactionType`, `status`, a
description, and `foreignCurrencyAmount` when abroad
([Apple FinanceKit](https://developer.apple.com/documentation/financekit/transaction)).
There is no location. "Far from home" must come from foreign currency
or a merchant city in the description.

**Draft rule set.** Each rule shows its reason on the card ("First time
here"). Each draws its prompt line from a human-written bank keyed by
rule. At most three suggestions show at once.

| Rule | Fires when | Data needed | Example prompt (human bank) |
|---|---|---|---|
| First visit | Merchant never seen before in history | merchantName (normalized), date | "A first time. What brought you here?" |
| Return to a favorite | 5th, 10th, 25th purchase at one merchant | merchantName, count | "You keep coming back. What keeps it good?" |
| Biggest this month | Largest debit in the calendar month | amount, date, indicator | "The big one this month. What did it make possible?" |
| Away from home | foreignCurrencyAmount present, or city differs from usual | foreignCurrencyAmount, description | "Where were you, and who was there?" |
| Start of a trip | First of 3+ travel MCCs (airline, lodging, car rental) within 7 days | MCC, date | "A trip begins. What are you hoping for?" |
| Gift-like | Florist, gift shop, toy, bookstore, jewelry MCC, or near a date the person marked | MCC, date | "Who was this for?" |
| Shared meal | Restaurant MCC above the person's usual meal amount | MCC, amount | "Who was at the table?" |
| Busy day | 4+ purchases on one day | date, count | "A full day. What was it about?" |
| Weekend | Purchases on Saturday or Sunday, grouped | date | "What did the weekend hold?" |
| A year ago | A memo exists for the same date a year back | memo date | "A year ago you wrote: '...'. What is the same now?" |
| Same place, a year later | Merchant has a memo from 11 to 13 months ago | merchantName, memo date | "Last time here you wrote '...'." |
| Learning | Bookstore, education, courses MCC | MCC | "What are you learning?" |
| Giving | Charity MCC or donation description | MCC, description | "What moved you to give?" |
| Returned | Credit at a merchant with a prior debit | indicator, merchantName | No prompt. Offer to link it to the original story. |

Rules never fire on: bills, utilities, fees, interest, transfers,
payments, ATM, or refunds as stories of their own. Those stay
bookkeeping, and the person is not asked to journal about them. A
person can mute any rule. The "a year ago" quote is the person's own
words, verbatim, never paraphrased.

---

## 3. Storytelling categories and value themes

**Reference taxonomies.**
- Ramit Sethi's ten Money Dials: Convenience, Travel, Health/Fitness,
  Experiences, Freedom, Relationships, Generosity, Luxury, Social
  status, Self-improvement. The rule is to spend freely on the dials
  you love and cut the rest
  ([IWT](https://www.iwillteachyoutoberich.com/money-dials/),
  [Kitces](https://www.kitces.com/blog/ramit-sethi-design-rich-life-spending-money-dials-i-will-teach-you-to-be-rich/)).
- Dunn and Norton, *Happy Money*: buy experiences, make it a treat,
  buy time, pay now and consume later, invest in others
  ([Kitces](https://www.kitces.com/blog/happy-money-and-the-science-of-spending-how-money-really-can-sometimes-buy-happiness/),
  [PBS](https://www.pbs.org/newshour/economy/money-can-buy-happiness-especially-when-you-invest-it-in-others)).
- Schwartz's ten basic values: self-direction, stimulation, hedonism,
  achievement, power, security, conformity, tradition, benevolence,
  universalism
  ([Wikipedia](https://en.wikipedia.org/wiki/Theory_of_basic_human_values)).
- VIA's 24 character strengths under six virtues (wisdom, courage,
  humanity, justice, temperance, transcendence)
  ([VIA Institute](https://www.viacharacter.org/character-strengths)).
- Apple Journal moment types: places, people, photos, music, workouts,
  trips. Daylio activities: people, hobbies, food, chores, sleep.

**Pattern.** The useful sets are about 10 items, named in everyday
words, and editable. Academic lists (Schwartz, VIA) are good checks for
coverage but too abstract as labels. Sethi's list is closest to money
but includes "Social status," which reads as judgment on a tag.

**Starter set (a starting suggestion; the person renames, removes, and
adds).** Fourteen themes:

1. **People I love**: time and care for family and friends.
2. **Great meals**: food worth remembering, alone or shared.
3. **Home**: the place I live and the comfort in it.
4. **Health**: my body, rest, movement, and care.
5. **Learning**: books, classes, tools that grow a skill.
6. **Making**: materials and tools for things I create.
7. **Adventure**: trips, firsts, and getting out of routine.
8. **Joy**: small treats that make a day better.
9. **Generosity**: gifts, tips, and giving to causes.
10. **Time back**: paying so I can spend time on what matters.
11. **Work I care about**: tools and costs of my work or craft.
12. **Community**: local places, events, and belonging.
13. **Beauty**: things made well that I enjoy looking at or using.
14. **Taking care of things**: the steady costs that keep life running.

Theme 14 gives routine costs an honest, non-shaming home. Onboarding
shows the set as editable marks and asks the person to keep the ones
that sound like them. A purchase can hold more than one theme.

---

## 4. Memo as achievement

**Precedents.**
- **Letterboxd** calls a log a *diary* entry, not a review. An entry is
  a date, an optional rating, an optional line, a heart, and a rewatch
  mark ([design analysis](https://blakecrosley.com/guides/design/letterboxd),
  [example diary](https://letterboxd.com/as/diary/)). The naming shapes
  behavior. A logged film feels like a memory kept.
- **Strava** share stickers are a transparent overlay on the person's
  own photo. Hidden stats stay hidden on the sticker
  ([Strava support](https://support.strava.com/en-us/articles/17718841-how-do-i-share-my-strava-activity-to-instagram-stories-as-a-transparent-sticker),
  [BikeRadar](https://www.bikeradar.com/news/strava-sticker-stats-spring-2025-updates)).
  The respectful part is that the person's photo leads and the privacy
  settings carry over. The gamified parts are segment leaderboards and
  kudos counts.
- **Untappd** badges and **Apple Fitness** awards celebrate milestones.
  Fitness awards honor a personal first (a first workout type, a
  personal record). Streak awards and "move goal" pressure are the part
  that tips into compulsion.
- **Goodreads Year in Books, Apple Books Year in Review, Spotify
  Wrapped** turn a year's logs into a story
  ([TechCrunch](https://techcrunch.com/2024/12/03/spotify-wrapped-2024-is-almost-here-its-time-to-explore-all-the-copycats/),
  [Spotify](https://newsroom.spotify.com/2025-wrapped-user-experience/)).
  Wrapped's rankings ("top 0.5% of listeners") are comparison bait.
  Its story format is good.

**Respectful vs gamified.**

| Respectful | Gamified |
|---|---|
| A personal first, named once | Streaks and chains |
| The person's words as the hero | Counts as the hero |
| Celebrating what happened | Celebrating frequency |
| Private by default | Public by default, leaderboards |
| Quiet, once | Confetti every time, badges to collect |

**How a written memo should look and feel.** The moment of saving is
the moment the purchase stops being a debit. Recommend:

- On save, the row turns from ledger to story. The memo text becomes
  the title in ink. Merchant and date drop to a small caption line.
  The amount moves to the end in a lighter weight. It stays there,
  honest, but no longer leads.
- The person's color appears as a single mark: an underline under the
  memo, or a small tick beside each value theme. A sanguine-pencil
  stroke draws in once (about 300 ms, a drawn mark, not a font) and
  stays.
- A one-time, quiet note for true firsts only: "Your first story about
  Adventure." Never a count, never a badge shelf.
- The story view looks like a page: date as a dateline, memo in body
  type, themes as marked words, amount as a footnote figure.
- A light `success` haptic on save; nothing else.

---

## 5. Collections and sharing

**Precedents.** Day One lets people keep several journals and print a
journal as a book. Letterboxd lists are ordered, titled, can carry
notes, and can be public or private. Pinterest boards can be secret.
Apple Photos Memories are generated sets the person can edit, rename,
or say "feature less." Wrapped is a once-a-year recap built for
sharing.

**For CentMemo.**
- **Every value theme is already a collection.** "People I love" shows
  all its stories as a paper stack, newest first. No new object needed.
- **Hand-made sets** for things that cross themes: "Lisbon, May 2026,"
  "Building the garden." The person names and orders them. Suggested
  sets come only from data rules (a trip cluster from the travel rule,
  a merchant with 5+ stories), labeled with the rule, never titled by
  AI.
- **A year in stories** each December: a page of the person's own memos
  grouped by theme, with plain counts per theme. No rankings, no
  percentiles, no "top spender." The person picks which stories appear
  before anything can be shared.
- **A printed book** later (Day One shows demand).

**Sharing defaults.**
- Everything private. Sharing is a deliberate act on one story or one
  set.
- A share card shows the memo, the themes, and the date. The amount
  and merchant are **off** by default, each a separate toggle. Card
  style: paper ground, ink type, one color mark.
- A public link is unguessable, read-only, listed in Settings, and can
  be revoked. Revoking kills the link at once.
- No social graph, likes, or follower counts.

---

## Recommendations for CentMemo

In priority order.

1. **Call it a story, everywhere.** The row is a "story to write" or a
   "story," never a "transaction to categorize." Letterboxd shows the
   noun shapes the act.
2. **Make saving the turn.** On save, the memo becomes the headline in
   ink, the amount moves to a light footnote, and one sanguine stroke
   draws in once. This is the "achievement" without points.
3. **Ship the 14-theme starter set as an editable suggestion.**
   Onboarding asks people to keep the ones that sound like them, rename
   freely, and add their own. Allow more than one theme per story.
4. **The smallest story is one theme tag.** Words are welcome but not
   required. This removes the blank-page cost.
5. **Rule-based suggestions, three at most, each showing its reason.**
   Start with First visit, Biggest this month, Away from home, Gift-like,
   Busy day, and A year ago. Prompt lines come from a human-written
   bank. Each rule can be muted.
6. **Never prompt for bills, fees, transfers, or payments.** Those get
   the "Taking care of things" theme silently if the person wants it.
7. **"A year ago you wrote..." as the main return ritual.** Quote the
   person's words verbatim. This is the On This Day lesson: the archive
   is the reward.
8. **No streaks, counts of unwritten purchases, or gap messages.** An
   unwritten purchase is just quiet. Add a check that greps product
   copy for "streak," "missed," and "behind."
9. **Notifications off by default; opt-in to one quiet notice at a
   time the person picks,** naming one moment, never a backlog count.
   Send nothing when no rule fired.
10. **Themes are collections.** Each theme opens a page of its stories.
    Add hand-made sets next; suggested sets only from named data rules.
11. **Share one story or one set, privately by default.** Amount and
    merchant off on the card by default. Revocable, unguessable links.
    No likes or followers.
12. **Firsts only, once, quietly.** "Your first story about Learning."
    No badge shelf.
13. **A year in stories each December,** made of the person's own memos
    and plain counts, with the person choosing what is shareable. No
    rankings.
14. **Later, on iPhone: Journaling Suggestions picker** to add a place
    or person to a story, using Apple's privacy model.
15. **Later: print a set as a book.** A year of stories on paper fits
    the visual language and Day One shows people want it.
