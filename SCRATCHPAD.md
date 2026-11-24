# Project Scratchpad: CentMemo

> Active working notes, loaded into every session, so keep it small.
> Keep only the two most recent session-log entries; roll older ones
> word for word into `docs/SESSION-LOG.md` (create it on the first roll).
>
> See `PARITY.md` for the cross-platform feature matrix (the single
> source of truth; don't duplicate rows here).
>
> The Current State block below is injected at every session start.
> If it drifts behind the code, fix it FIRST, then work. A stale
> scratchpad is worse than none.

## Current state

- **CentMemo**, 2026-11-21. Bundle `com.learningischange.centmemo`, team
  `L2G756LY8N`, repo `bhwilkoff/CentMemo` (public), Supabase
  `qucsmmazfalbyduxlavl`. Ben's words: `docs/WHAT-CENTMEMO-IS.md`. Decisions 054-061.
- **Live**: centmemo.com over HTTPS (web app, `/connect/`, `/privacy/`,
  `/terms/`, `/brand/`). Apple sign-in on the web verified by Ben.
- **Connector**: verified end to end as Claude drives it (`tools/test_connector.mjs`);
  read-only enforced in SQL; Wallet rows never shared (Addendum 3.2).
- **iOS**: every major update ships to TestFlight (Ben, 2026-11-24). 1.0 (17)
  and 1.0.17 (18) add the Wallet background delivery extension; a delivery is not yet seen.
- **Testing** (`docs/TESTING.md`): `tools/test_all.sh` off-device (RLS,
  connector, web states at 375px, Swift Core, builds); iPhone 12 tap and
  glass tiers; iPad Pro glass tier only.
- **Look**: paper, ink, sanguine pencil; the person's color as marks only
  (`docs/DESIGN.md`, Decision 060).
- **Waiting on Apple**: Addendum 3.2, Developer Support case 103023652799.
- **Blocked on Ben**: iPhone Apple sign-in (via TestFlight); the Duet live and
  scheduled test; iPad UI Automation (Settings >
  Developer).
- **Loop**: stopped by Ben 2026-11-24. Start at "Resume here" in
  `AUTONOMOUS_PROGRESS.md` (unverified device checks, Ben's open choices,
  the FinanceKit walletdelivery grant, Screen Time hours).

## Milestones

- **M0 (done 2026-11-21)**: the owner's words in AGENTS.md; centmemo.com live
  over HTTPS; real data (an Apple Card CSV) through the web; the owner signed
  in (Apple, web).
- **M1 (done)**: backend, read-only Claude connector, web app, finance skills
  (plan: `~/.claude/plans/mighty-percolating-simon-*.md`).
- **M2 (in progress)**: iPhone app on TestFlight; FinanceKit once Apple grants
  it; photos by reference; shared stories. Tick-level work and the backlog:
  `AUTONOMOUS_PROGRESS.md`.

## Out of scope (intentionally)

| Idea | Why declined | Revisit when |
|---|---|---|
| Handwriting or informal typefaces | Ben: "read like elementary school kids are writing financial memos" (memory no-handwriting-fonts) | Never |
| The person's color as a page background | Ben: "reads as too much color ... harder to read" (Decision 060) | Never |
| Claude writing memos or values | The memo is the person's act of examining (Decision 056); FinanceKit Addendum 3.2 | A new decision |
| FinanceKit rows in the Claude connector | Addendum 3.2: no third-party disclosure without Apple's written permission | Apple grants it |
| Email sign-in or codes | Apple sign-in covers web and iPhone with two-factor; email codes need SMTP (Decision 058) | Non-Apple users appear |
| Shortcuts-only Apple Card capture | Sees only Apple Pay taps; FinanceKit is the full path | Never |
| tvOS and Android apps | FinanceKit is iPhone-only; not lean-back (Decision 055) | A CSV-only audience asks |

## Session log

The tick-by-tick log is `AUTONOMOUS_PROGRESS.md`; earlier sessions are in the
git history and DECISIONS.md.
