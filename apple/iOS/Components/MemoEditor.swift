#if os(iOS) || os(macOS)
import SwiftUI
#if os(iOS)
import UIKit
typealias MemoFont = UIFont
typealias MemoColor = UIColor
typealias MemoNativeTextView = UITextView
#else
import AppKit
typealias MemoFont = NSFont
typealias MemoColor = NSColor
typealias MemoNativeTextView = NSTextView
#endif

/// W4 (Decision 069): the memo written with styles, kept as MemoText's Markdown. A native
/// text view (UITextView on iOS 18, NSTextView on the Mac): the styled SwiftUI TextEditor is
/// iOS 26 only. Bold and italic come from the system (⌘B, ⌘I, the edit menu); strikethrough,
/// heading, list and quote from the format bar on iOS and the Format menu on the Mac.
/// Underline is refused: it is the share's pencil mark.
enum MemoStyle {
    static let block = NSAttributedString.Key("centmemo.block")
    static let marker = NSAttributedString.Key("centmemo.marker")
    static let bullet = "• "

    static func font(bold: Bool, italic: Bool, heading: Bool) -> MemoFont {
        #if os(iOS)
        let base = UIFont.preferredFont(forTextStyle: heading ? .title3 : .body)
        var d = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        var traits = d.symbolicTraits
        if bold || heading { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        d = d.withSymbolicTraits(traits) ?? d
        return UIFont(descriptor: d, size: 0)
        #else
        let base = NSFont.preferredFont(forTextStyle: heading ? .title3 : .body)
        var d = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        var traits = d.symbolicTraits
        if bold || heading { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        d = d.withSymbolicTraits(traits)
        return NSFont(descriptor: d, size: 0) ?? base
        #endif
    }

    static func traits(_ f: MemoFont?) -> (bold: Bool, italic: Bool) {
        guard let f else { return (false, false) }
        #if os(iOS)
        let t = f.fontDescriptor.symbolicTraits
        return (t.contains(.traitBold), t.contains(.traitItalic))
        #else
        let t = f.fontDescriptor.symbolicTraits
        return (t.contains(.bold), t.contains(.italic))
        #endif
    }

    static var ink: MemoColor {
        #if os(iOS)
        .label
        #else
        .textColor
        #endif
    }
    static var quiet: MemoColor {
        #if os(iOS)
        .secondaryLabel
        #else
        .secondaryLabelColor
        #endif
    }

    static func paragraph(_ b: MemoText.Block) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 3
        switch b {
        case .bullet: p.headIndent = 18
        case .quote: p.firstLineHeadIndent = 16; p.headIndent = 16
        case .heading: p.paragraphSpacingBefore = 6
        case .paragraph: break
        }
        return p
    }

    static func attributes(_ b: MemoText.Block, bold: Bool = false, italic: Bool = false, strike: Bool = false) -> [NSAttributedString.Key: Any] {
        var a: [NSAttributedString.Key: Any] = [
            .font: font(bold: bold, italic: italic || b == .quote, heading: b == .heading),
            .foregroundColor: b == .quote ? quiet : ink,
            .paragraphStyle: paragraph(b),
            block: b.rawValue,
        ]
        if strike { a[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        return a
    }

    // MARK: Markdown <-> attributed text

    static func attributed(_ markdown: String) -> NSAttributedString {
        let out = NSMutableAttributedString()
        for (i, l) in MemoText.parse(markdown).enumerated() {
            if i > 0 { out.append(NSAttributedString(string: "\n", attributes: attributes(.paragraph))) }
            if l.block == .bullet {
                var a = attributes(.bullet); a[marker] = true
                out.append(NSAttributedString(string: bullet, attributes: a))
            }
            for r in l.runs {
                out.append(NSAttributedString(string: r.text, attributes: attributes(l.block, bold: r.bold, italic: r.italic, strike: r.strike)))
            }
        }
        return out
    }

    static func markdown(_ a: NSAttributedString) -> String {
        MemoText.markdown(lines(a))
    }

    static func lines(_ a: NSAttributedString) -> [MemoText.Line] {
        let s = a.string as NSString
        var result: [MemoText.Line] = []
        var start = 0
        repeat {
            let nl = s.range(of: "\n", range: NSRange(location: start, length: s.length - start))
            let end = nl.location == NSNotFound ? s.length : nl.location
            result.append(line(a, NSRange(location: start, length: end - start)))
            start = end + 1
        } while start <= s.length
        return result
    }

    private static func line(_ a: NSAttributedString, _ range: NSRange) -> MemoText.Line {
        var l = MemoText.Line()
        guard range.length > 0 else { return l }
        l.block = (a.attribute(block, at: range.location, effectiveRange: nil) as? String).flatMap(MemoText.Block.init) ?? .paragraph
        a.enumerateAttributes(in: range) { attrs, r, _ in
            if attrs[marker] != nil { return }
            let text = (a.string as NSString).substring(with: r).replacingOccurrences(of: "\u{2028}", with: " ")
            let t = traits(attrs[.font] as? MemoFont)
            let run = MemoText.Run(text: text, bold: t.bold && l.block != .heading, italic: t.italic && l.block != .quote,
                                   strike: (attrs[.strikethroughStyle] as? Int ?? 0) != 0)
            if let last = l.runs.last, last.bold == run.bold, last.italic == run.italic, last.strike == run.strike {
                l.runs[l.runs.count - 1].text += run.text
            } else if !text.isEmpty {
                l.runs.append(run)
            }
        }
        // A bullet's marker typed over or deleted leaves a plain line.
        if l.block == .bullet, (a.string as NSString).substring(with: range).hasPrefix(bullet) == false { l.block = .paragraph }
        return l
    }
}

/// The text view's styling verbs, shared by the iOS format bar and the Mac's Format menu.
@MainActor
final class MemoFormatter {
    enum Mark { case bold, italic, strike }
    weak var view: MemoNativeTextView?
    var changed: () -> Void = {}
    /// The Mac's Format menu acts on the memo being written.
    static weak var active: MemoFormatter?

    private var storage: NSMutableAttributedString? {
        #if os(iOS)
        view?.textStorage
        #else
        view?.textStorage
        #endif
    }
    private var selection: NSRange {
        #if os(iOS)
        view?.selectedRange ?? NSRange(location: 0, length: 0)
        #else
        view?.selectedRange() ?? NSRange(location: 0, length: 0)
        #endif
    }

    func toggle(_ m: Mark) {
        guard let view, let storage else { return }
        let sel = selection
        if sel.length == 0 {
            var t = typing
            t = flip(m, in: t, on: !has(m, t))
            typing = t
            return
        }
        let on = !allHave(m, storage, sel)
        storage.beginEditing()
        storage.enumerateAttributes(in: sel) { attrs, r, _ in
            if attrs[MemoStyle.marker] != nil { return }
            storage.setAttributes(flip(m, in: attrs, on: on), range: r)
        }
        storage.endEditing()
        _ = view
        changed()
    }

    func setBlock(_ b: MemoText.Block) {
        guard let storage else { return }
        let s = storage.string as NSString
        var sel = selection
        let paragraphs = s.paragraphRange(for: sel)
        // Every paragraph already this block: turn it back into a plain one.
        var all = true, seen = false
        s.enumerateSubstrings(in: paragraphs, options: .byParagraphs) { _, r, _, _ in
            seen = true
            let have = (r.length > 0 ? storage.attribute(MemoStyle.block, at: r.location, effectiveRange: nil) as? String : self.typing[MemoStyle.block] as? String) ?? "paragraph"
            if have != b.rawValue { all = false }
        }
        // An empty line (an empty memo, or after Return at the end) has no paragraph to
        // enumerate: what the person is about to type decides.
        if !seen { all = (typing[MemoStyle.block] as? String) == b.rawValue }
        let target: MemoText.Block = all ? .paragraph : b
        storage.beginEditing()
        var ranges: [NSRange] = []
        s.enumerateSubstrings(in: paragraphs, options: [.byParagraphs, .substringNotRequired]) { _, r, _, _ in ranges.append(r) }
        if ranges.isEmpty { ranges = [NSRange(location: paragraphs.location, length: 0)] }
        var shift = 0
        for r0 in ranges {
            var r = NSRange(location: r0.location + shift, length: r0.length)
            let current = storage.string as NSString
            let hasMarker = r.length >= MemoStyle.bullet.count && current.substring(with: NSRange(location: r.location, length: MemoStyle.bullet.count)) == MemoStyle.bullet
            if hasMarker && target != .bullet {
                storage.deleteCharacters(in: NSRange(location: r.location, length: MemoStyle.bullet.count))
                r.length -= MemoStyle.bullet.count; shift -= MemoStyle.bullet.count
                if sel.location > r.location { sel.location = max(r.location, sel.location - MemoStyle.bullet.count) }
            } else if !hasMarker && target == .bullet {
                var a = MemoStyle.attributes(.bullet); a[MemoStyle.marker] = true
                storage.insert(NSAttributedString(string: MemoStyle.bullet, attributes: a), at: r.location)
                r.length += MemoStyle.bullet.count; shift += MemoStyle.bullet.count
                if sel.location >= r.location { sel.location += MemoStyle.bullet.count }
            }
            storage.enumerateAttributes(in: r) { attrs, rr, _ in
                let t = MemoStyle.traits(attrs[.font] as? MemoFont)
                var next = MemoStyle.attributes(target, bold: t.bold && (attrs[MemoStyle.block] as? String) != "heading",
                                                italic: t.italic && (attrs[MemoStyle.block] as? String) != "quote",
                                                strike: (attrs[.strikethroughStyle] as? Int ?? 0) != 0)
                if attrs[MemoStyle.marker] != nil { next[MemoStyle.marker] = true }
                storage.setAttributes(next, range: rr)
            }
        }
        storage.endEditing()
        select(sel)
        typing = MemoStyle.attributes(target)
        changed()
    }

    func done() {
        #if os(iOS)
        view?.resignFirstResponder()
        #else
        view?.window?.makeFirstResponder(nil)
        #endif
    }

    // MARK: helpers

    var typing: [NSAttributedString.Key: Any] {
        get {
            #if os(iOS)
            view?.typingAttributes ?? MemoStyle.attributes(.paragraph)
            #else
            view?.typingAttributes ?? MemoStyle.attributes(.paragraph)
            #endif
        }
        set { view?.typingAttributes = newValue }
    }

    private func select(_ r: NSRange) {
        guard let storage else { return }
        let clamped = NSRange(location: min(r.location, storage.length), length: min(r.length, max(0, storage.length - r.location)))
        #if os(iOS)
        view?.selectedRange = clamped
        #else
        view?.setSelectedRange(clamped)
        #endif
    }

    private func has(_ m: Mark, _ a: [NSAttributedString.Key: Any]) -> Bool {
        switch m {
        case .bold: MemoStyle.traits(a[.font] as? MemoFont).bold
        case .italic: MemoStyle.traits(a[.font] as? MemoFont).italic
        case .strike: (a[.strikethroughStyle] as? Int ?? 0) != 0
        }
    }

    private func allHave(_ m: Mark, _ s: NSAttributedString, _ r: NSRange) -> Bool {
        var all = true
        s.enumerateAttributes(in: r) { a, _, stop in
            if a[MemoStyle.marker] == nil, !has(m, a) { all = false; stop.pointee = true }
        }
        return all
    }

    private func flip(_ m: Mark, in a: [NSAttributedString.Key: Any], on: Bool) -> [NSAttributedString.Key: Any] {
        let b = (a[MemoStyle.block] as? String).flatMap(MemoText.Block.init) ?? .paragraph
        let t = MemoStyle.traits(a[.font] as? MemoFont)
        var bold = t.bold && b != .heading, italic = t.italic && b != .quote
        var strike = (a[.strikethroughStyle] as? Int ?? 0) != 0
        switch m {
        case .bold: bold = on
        case .italic: italic = on
        case .strike: strike = on
        }
        var next = MemoStyle.attributes(b, bold: bold, italic: italic, strike: strike)
        if a[MemoStyle.marker] != nil { next[MemoStyle.marker] = true }
        return next
    }

    /// Return in a list continues it; Return on an empty item ends it. A heading ends at Return.
    func newline(at range: NSRange) -> Bool {
        guard let storage else { return true }
        let s = storage.string as NSString
        let p = s.paragraphRange(for: NSRange(location: min(range.location, s.length), length: 0))
        let b = (p.length > 0 && p.location < storage.length ? storage.attribute(MemoStyle.block, at: p.location, effectiveRange: nil) as? String : nil)
            .flatMap(MemoText.Block.init) ?? .paragraph
        switch b {
        case .bullet:
            let text = s.substring(with: p).trimmingCharacters(in: .newlines)
            if text == MemoStyle.bullet.trimmingCharacters(in: .whitespaces) || text == MemoStyle.bullet || text.isEmpty {
                select(NSRange(location: p.location, length: 0))
                setBlock(.bullet)  // the empty item becomes a plain line
                return false
            }
            var a = MemoStyle.attributes(.bullet); a[MemoStyle.marker] = true
            let insert = NSMutableAttributedString(string: "\n", attributes: MemoStyle.attributes(.bullet))
            insert.append(NSAttributedString(string: MemoStyle.bullet, attributes: a))
            storage.replaceCharacters(in: range, with: insert)
            select(NSRange(location: range.location + insert.length, length: 0))
            typing = MemoStyle.attributes(.bullet)
            changed()
            return false
        case .heading:
            storage.replaceCharacters(in: range, with: NSAttributedString(string: "\n", attributes: MemoStyle.attributes(.paragraph)))
            select(NSRange(location: range.location + 1, length: 0))
            typing = MemoStyle.attributes(.paragraph)
            changed()
            return false
        case .quote, .paragraph:
            return true
        }
    }
}

#if os(iOS)
/// Underline is the share's pencil mark, never a memo style.
final class MemoTextView: UITextView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(toggleUnderline(_:)) { return false }
        return super.canPerformAction(action, withSender: sender)
    }
    override func toggleUnderline(_ sender: Any?) {}
}

struct MemoEditor: UIViewRepresentable {
    @Binding var markdown: String
    var minHeight: CGFloat
    var focused: Binding<Bool>?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MemoTextView {
        let v = MemoTextView()
        v.backgroundColor = .clear
        v.isScrollEnabled = false
        v.allowsEditingTextAttributes = true
        v.adjustsFontForContentSizeCategory = true
        v.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        v.delegate = context.coordinator
        v.attributedText = MemoStyle.attributed(markdown)
        v.typingAttributes = MemoStyle.attributes(.paragraph)
        v.accessibilityLabel = "Memo"
        v.accessibilityIdentifier = "memo-editor"
        context.coordinator.last = markdown
        let f = context.coordinator.formatter
        f.view = v
        f.changed = { [weak coordinator = context.coordinator] in coordinator?.publish() }
        v.inputAccessoryView = Self.bar(f)
        return v
    }

    func updateUIView(_ v: MemoTextView, context: Context) {
        context.coordinator.parent = self
        if markdown != context.coordinator.last {
            let sel = v.selectedRange
            v.attributedText = MemoStyle.attributed(markdown)
            context.coordinator.last = markdown
            v.selectedRange = NSRange(location: min(sel.location, v.textStorage.length), length: 0)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MemoTextView, context: Context) -> CGSize? {
        let w = proposal.width ?? 320
        let h = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height
        return CGSize(width: w, height: max(minHeight, h))
    }

    /// The format bar over the keyboard, drawn like the keyboard: six styles, then Done.
    /// Plain buttons, not a UIToolbar: on iOS 26 a toolbar folded Quote and Done into "…"
    /// on the iPhone 12, and a menu took the caret away from the line it was styling.
    static func bar(_ f: MemoFormatter) -> UIView {
        let bar = UIInputView(frame: CGRect(x: 0, y: 0, width: 320, height: 48), inputViewStyle: .keyboard)
        // Opaque, so it reads alone when a hardware keyboard hides the software one; the
        // pencil's color for its controls (DESIGN C2).
        bar.backgroundColor = .secondarySystemBackground
        bar.tintColor = UIColor(Color.brandPrimary)
        func button(_ symbol: String, _ label: String, _ id: String, _ act: @escaping () -> Void) -> UIButton {
            var c = UIButton.Configuration.plain()
            c.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(textStyle: .body))
            let b = UIButton(configuration: c, primaryAction: UIAction { _ in act() })
            b.accessibilityLabel = label
            b.accessibilityIdentifier = id
            b.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
            return b
        }
        var done = UIButton.Configuration.plain()
        done.title = "Done"
        let doneButton = UIButton(configuration: done, primaryAction: UIAction { _ in f.done() })
        doneButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        let styles = UIStackView(arrangedSubviews: [
            button("bold", "Bold", "format-bold") { f.toggle(.bold) },
            button("italic", "Italic", "format-italic") { f.toggle(.italic) },
            button("strikethrough", "Strikethrough", "format-strike") { f.toggle(.strike) },
            button("textformat.size.larger", "Heading", "format-heading") { f.setBlock(.heading) },
            button("list.bullet", "List", "format-list") { f.setBlock(.bullet) },
            button("text.quote", "Quote", "format-quote") { f.setBlock(.quote) },
        ])
        styles.distribution = .equalSpacing
        let row = UIStackView(arrangedSubviews: [styles, doneButton])
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: bar.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: bar.layoutMarginsGuide.trailingAnchor),
            row.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])
        doneButton.setContentHuggingPriority(.required, for: .horizontal)
        return bar
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MemoEditor
        var last = ""
        let formatter = MemoFormatter()
        init(_ p: MemoEditor) { parent = p }

        func publish() {
            guard let v = formatter.view else { return }
            let md = MemoStyle.markdown(v.attributedText)
            last = md
            if parent.markdown != md { parent.markdown = md }
            v.invalidateIntrinsicContentSize()
        }
        func textViewDidChange(_ textView: UITextView) {
            // Underline from a paste is dropped, as from the menu.
            textView.textStorage.removeAttribute(.underlineStyle, range: NSRange(location: 0, length: textView.textStorage.length))
            publish()
        }
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            text == "\n" ? formatter.newline(at: range) : true
        }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.focused?.wrappedValue = true }
        func textViewDidEndEditing(_ textView: UITextView) { parent.focused?.wrappedValue = false }
    }
}
#else
/// Underline is the share's pencil mark, never a memo style.
final class MemoTextView: NSTextView {
    override func underline(_ sender: Any?) {}
    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(underline(_:)) { return false }
        return super.validateUserInterfaceItem(item)
    }
}

struct MemoEditor: NSViewRepresentable {
    @Binding var markdown: String
    var minHeight: CGFloat
    var focused: Binding<Bool>?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> MemoTextView {
        let v = MemoTextView()
        v.drawsBackground = false
        v.isRichText = true
        v.allowsUndo = true
        v.isVerticallyResizable = true
        v.isHorizontallyResizable = false
        v.textContainer?.widthTracksTextView = true
        v.textContainerInset = NSSize(width: 0, height: 8)
        v.delegate = context.coordinator
        v.textStorage?.setAttributedString(MemoStyle.attributed(markdown))
        // Every change counts, not only typing: accessibility (VoiceOver, dictation, the tap
        // tier) sets the text without the text view's change notice.
        v.textStorage?.delegate = context.coordinator
        v.typingAttributes = MemoStyle.attributes(.paragraph)
        v.setAccessibilityLabel("Memo")
        v.setAccessibilityIdentifier("memo-editor")
        context.coordinator.last = markdown
        let f = context.coordinator.formatter
        f.view = v
        f.changed = { [weak coordinator = context.coordinator] in coordinator?.publish() }
        return v
    }

    func updateNSView(_ v: MemoTextView, context: Context) {
        context.coordinator.parent = self
        if markdown != context.coordinator.last {
            v.textStorage?.setAttributedString(MemoStyle.attributed(markdown))
            context.coordinator.last = markdown
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: MemoTextView, context: Context) -> CGSize? {
        let w = proposal.width ?? 480
        guard let lm = nsView.layoutManager, let tc = nsView.textContainer else { return CGSize(width: w, height: minHeight) }
        tc.containerSize = NSSize(width: w, height: .greatestFiniteMagnitude)
        lm.ensureLayout(for: tc)
        let h = lm.usedRect(for: tc).height + nsView.textContainerInset.height * 2
        return CGSize(width: w, height: max(minHeight, h))
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: MemoEditor
        var last = ""
        let formatter = MemoFormatter()
        init(_ p: MemoEditor) { parent = p }

        func publish() {
            guard let v = formatter.view, let s = v.textStorage else { return }
            let md = MemoStyle.markdown(s)
            last = md
            if parent.markdown != md { parent.markdown = md }
            v.invalidateIntrinsicContentSize()
        }
        nonisolated func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            DispatchQueue.main.async { [weak self] in MainActor.assumeIsolated { self?.publish() } }
        }
        func textDidChange(_ notification: Notification) {
            formatter.view?.textStorage?.removeAttribute(.underlineStyle, range: NSRange(location: 0, length: formatter.view?.textStorage?.length ?? 0))
            publish()
        }
        func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
            text == "\n" ? formatter.newline(at: range) : true
        }
        func textDidBeginEditing(_ notification: Notification) {
            MemoFormatter.active = formatter
            parent.focused?.wrappedValue = true
        }
        func textDidEndEditing(_ notification: Notification) { parent.focused?.wrappedValue = false }
    }
}

/// The Mac's Format menu for the memo being written (W4).
struct MemoFormatCommands: Commands {
    var body: some Commands {
        CommandMenu("Format") {
            Button("Bold") { MemoFormatter.active?.toggle(.bold) }.keyboardShortcut("b", modifiers: .command)
            Button("Italic") { MemoFormatter.active?.toggle(.italic) }.keyboardShortcut("i", modifiers: .command)
            Button("Strikethrough") { MemoFormatter.active?.toggle(.strike) }.keyboardShortcut("x", modifiers: [.command, .shift])
            Divider()
            Button("Heading") { MemoFormatter.active?.setBlock(.heading) }.keyboardShortcut("h", modifiers: [.command, .option])
            Button("List") { MemoFormatter.active?.setBlock(.bullet) }.keyboardShortcut("l", modifiers: [.command, .option])
            Button("Quote") { MemoFormatter.active?.setBlock(.quote) }.keyboardShortcut("'", modifiers: [.command, .option])
        }
    }
}
#endif
#endif
