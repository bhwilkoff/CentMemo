# Memo writing: research and the design it leads to (W0, 2026-11-26)

Ben asked for the whole memo writing experience to be improved "through
research and design" (backlog W0 to W8 in `AUTONOMOUS_PROGRESS.md`). Two
research passes: Apple's frameworks, checked against the local iPhoneOS 27.1
and macOS 27.0 SDKs, and the writing apps people already know.

## What the best writing apps do

- **No Save button anywhere.** Notes, Journal, Bear, Craft and Things save as
  you type and say nothing about it. Only a problem speaks (a sync warning).
  "Done" on iPhone only puts the keyboard away.
- **Formatting is a few marks, reached through the system.** Journal: bold,
  italic, underline, strikethrough, lists, quote. Bear mixes typed Markdown with
  a format bar. iOS 18 gives any rich text view Apple's own Format panel
  (`UITextFormattingViewController`, iOS 18.0), and ⌘B / ⌘I work everywhere.
- **Handwriting.** Scribble turns Apple Pencil writing into typed text in any
  text view, with no code. Notes places ink inline as a block in the text, and
  the ink stays searchable. Whole-page canvases (GoodNotes) are wrong for a
  short memo.
- **Photos.** Journal places them inline. Craft styles a page and publishes it
  from the same Share. Lesson: the placement and style should carry into what
  is shared, or the share feels like a lesser copy.
- **Starter content in place.** Day One offers templates and suggestions inside
  the entry; Notion offers starters in the sidebar. No slide decks.
- **One Share.** Notes and Freeform put the choice (send a copy or collaborate)
  at the top of one share sheet; Craft's Share holds both Publish and Export.

## Apple's frameworks, against the iOS 18 floor

| Need | iOS 18 to 25 | iOS 26+ and the Mac |
|---|---|---|
| Styled text | `UITextView` in a representable, `allowsEditingTextAttributes`, `textFormattingConfiguration` (18.0) | SwiftUI `TextEditor(text: Binding<AttributedString>)` (26.0) |
| Handwriting to text | Scribble, on by default in text views | same; Mac: none |
| Ink | `PKCanvasView` + `PKToolPicker`; `drawingPolicy .anyInput` for a finger, or only Pencil draws when no tool picker shows | Mac SDK has `PKDrawing` but no `PKCanvasView`: show ink, don't draw it |
| Ink to text | `VNRecognizeTextRequest` on the rendered drawing (accuracy on handwriting to be measured) | same |
| Inline images | `NSTextAttachment` (15.0) works but breaks the plain-text memo | — |

`AttributedString(markdown:)` has no underline. Headings, lists and quotes
come only with `.full` parsing, which collapses whitespace. There is no
AttributedString-to-Markdown writer, so CentMemo writes its own small one, with
a golden round-trip test.

## Decisions (logged as Decision 069)

1. **Autosave (W3).** No Save button and no "Saved" text. The memo is kept on
   the device at each pause (about one second) and sent quietly; leaving the
   page or the app sends it at once. Only failure speaks, as a warning ("Not
   sent yet. It's kept on this iPhone."). Undo stays the text view's own.
2. **Styled text (W4).** Stored as a small Markdown subset in the existing
   memo column, so Claude and the web read it as plain text and every old memo
   is already valid: bold, italic, strikethrough, one heading level, bulleted
   lists, quote. No underline in the memo: Markdown has none, and underline is
   the share's pencil mark (DESIGN S), so one mark would mean two things.
   Reached through the system Format panel, ⌘B / ⌘I, and the Mac's Format menu.
3. **Handwriting (W5).** Scribble works in the memo with no code. Ink is a
   memo part: a PencilKit drawing as wide as the memo, sanguine by default,
   kept as the drawing plus a rendered picture. Typed text from the ink only
   when the person asks for it, and they can edit it. The Mac shows ink.
4. **One Share (W6).** Share and Make a link become one Share. Inside it, at
   the top: Picture (a card you send, nothing kept on a server) or Link (a page
   at centmemo.com you can turn off).
5. **Photos and files in the share (W7).** The memo's photos are listed in the
   Share, each off until the person turns it on. A Link carries a copy of each
   chosen photo, deleted when the link is turned off. Never money: a photo
   that reads as a receipt gets a warning before it can go.
6. **Photo styles (W8).** A memo is its words, then its parts in order. Photo
   styles: Plate (its own shape, no border), Mounted (a paper mat, as an
   archival print), Strip (two to four side by side). No filters, tilted
   polaroids or drawn tape (DESIGN M). The style is kept with the photo and
   carried into the share.

Sizes: iPhone pushes to the memo with the parts after the words; the open Duo
and iPad keep the list on the left and the memo on the right, the memo at most
640pt wide; the Mac puts parts beside the memo from 1100pt (DESIGN W).
