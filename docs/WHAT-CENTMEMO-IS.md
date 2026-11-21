# What CentMemo is, in Ben's words

These are the owner's words, kept verbatim. AGENTS.md carries a short form
and points here. Add new statements below with their date; never rewrite old
ones.

## 2026-11-21, first statement (as "Duet Connect")

"make an app that can provide information to Claude Duet that the app/service doesn't currently have access to. The primary purpose of this is to provide Apple Card purchase to be seen by the app with an approved pathway via fincancekit or some other means. I'd also like to provide access to things like my iCloud Drive and my iCloud Photos library. The goal would be for the app to either use a fully documented pathway or to create one of its own. It is possible that this could only work as a native app, but much research will have to be done before we can fully decide on that."

## 2026-11-21, second statement (the app becomes CentMemo)

"If I'm going to all of the trouble of solving this problem for myself, I'd like the ability to solve it for others. I'm aware that this is the first time we've attempted to create a finance app, but I think we need to build out that muscle (and build the set of claude skills that make it work). The Tidbits Trivia app is the closest one that I have to creating a financial model and or dealing with money (it has in-app purchases and has been through some of the approvals that this app will require). Duet connect should certainly be able to pass along the financial data from your Apple Card account (and the other accounts connected to FinanceKit), but it should also help you tell the story of your money through your purchases. Each purchase made on the apple card was done with intention. It is a marker of something that happened in your life, and it is a story worth telling if it helps you deepen your understanding of what you value and what you are "investing" in (experiences with your kids, great meals that you have had, etc.). I have just purchased a domain at centmemo.com. The idea is that every cent tells a story and you are writing out that memo/story within the app based upon the transactions from your apple pay card. The benefit of being able to connect CentMemo to your Claude Duet is that it can help you to understand and do things about your money, but the story is being told and captured in CentMemo. This will also allow us to do things like pull in the Photos and files that help to tell the story and potentially pass those along to Claude duet as well. While the claude duet connection is the major thing that I want for the future, I also want a better way to tell the story of my finances to myself and others. There are far too many charges on my card that go unexamined. Please proceed with building out the lightweight tools and versions for making sure the functionality of the app works well for our Claude duet purpose, but also so that we have full functionality as a finance app that could potentially help me (and other people) with understanding the story of their finances."

## Choices Ben made the same day

- Bundle ID: `com.learningischange.centmemo`.
- What Claude may do through the connector: read only.
- Backend: a new free Supabase project.
- Web: GitHub Pages at centmemo.com; the repository is renamed CentMemo.
