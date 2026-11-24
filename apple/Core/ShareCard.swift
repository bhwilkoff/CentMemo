#if os(iOS) || os(macOS)
import SwiftUI
import CoreText
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// What a share card is drawn from. There is no amount in it, so a card can never
/// show one (Ben, 2026-11-24; DESIGN S1). The web's twin is js/money/share-card.js.
struct ShareContent: Equatable, Sendable {
    struct Theme: Equatable, Sendable { var name: String; var paper: UInt32; var night: UInt32 }
    var memo: String
    var setting: String
    var initials: String
    var date: String
    var themes: [Theme] = []
    var words: [String] { memo.split(whereSeparator: \.isWhitespace).map(String.init) }
}

/// What the person chose (S2). `mark` is the first and last word they underlined.
struct ShareDesign: Equatable, Sendable {
    enum Look: String, CaseIterable, Sendable { case page, setting, theme, words }
    enum Paper: String, CaseIterable, Sendable { case paper, night, theme }
    enum Shape: String, CaseIterable, Sendable {
        case square, tall, wide
        var size: CGSize {
            switch self {
            case .square: CGSize(width: 1080, height: 1080)
            case .tall: CGSize(width: 1080, height: 1920)
            case .wide: CGSize(width: 1200, height: 630)
            }
        }
    }
    var look = Look.page
    var paper = Paper.paper
    var shape = Shape.square
    var showSetting = true
    var showDate = true
    var showThemes = true
    var mark: ClosedRange<Int>?

    /// First tap starts an underline, the second ends it, the third starts over.
    mutating func tap(_ i: Int) {
        if let m = mark, m.lowerBound == m.upperBound { mark = min(m.lowerBound, i)...max(m.lowerBound, i) }
        else { mark = i...i }
    }
}

/// The card at its full size in points (1080 across); scale it to show it.
struct ShareCard: View {
    let content: ShareContent
    let design: ShareDesign

    var body: some View {
        let size = design.shape.size
        Canvas { ctx, _ in Painter(ctx: ctx, c: content, d: design).paint() }
            .frame(width: size.width, height: size.height)
            .accessibilityElement()
            .accessibilityLabel("\(design.look.rawValue.capitalized) card: \(content.memo)")
    }
}

/// The drawing, step for step the web's.
private struct Painter {
    var ctx: GraphicsContext
    let c: ShareContent
    let d: ShareDesign

    struct Face { var weight: Font.Weight = .regular; var serif = true }
    struct Line { var words: [Int]; var width: CGFloat }
    struct Fitted { var size: CGFloat; var lines: [Line]; var cut = false }

    static let lead: CGFloat = 1.28

    private func hex(_ v: UInt32, _ a: Double = 1) -> Color {
        Color(.sRGB, red: Double(v >> 16 & 0xFF) / 255, green: Double(v >> 8 & 0xFF) / 255, blue: Double(v & 0xFF) / 255, opacity: a)
    }
    private var first: ShareContent.Theme? { c.themes.first }
    private var bg: Color { switch d.paper { case .paper: hex(0xFBFAF7); case .night: hex(0x171615); case .theme: hex(first?.paper ?? 0x4A1520) } }
    private var ink: Color { switch d.paper { case .paper: hex(0x231B1C); case .night: hex(0xF3EEE9); case .theme: hex(0xFBFAF7) } }
    private var muted: Color { switch d.paper { case .paper: hex(0x5F5454); case .night: hex(0xB3ACA6); case .theme: hex(0xFBFAF7, 0.82) } }
    private var pencil: Color { switch d.paper { case .paper: hex(0x4A1520); case .night: hex(0xF0B9BE); case .theme: hex(0xFBFAF7) } }
    private var accent: Color { switch d.paper { case .paper: hex(first?.paper ?? 0x4A1520); case .night: hex(first?.night ?? 0xF0B9BE); case .theme: hex(0xFBFAF7) } }

    // MARK: Type

    static func font(_ size: CGFloat, _ f: Face) -> Font { .system(size: size, weight: f.weight, design: f.serif ? .serif : .default) }

    static func ct(_ size: CGFloat, _ f: Face) -> CTFont {
        #if os(macOS)
        let base = NSFont.systemFont(ofSize: size, weight: f.weight == .semibold ? .semibold : .regular)
        return (f.serif ? base.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: size) } ?? base : base) as CTFont
        #else
        let base = UIFont.systemFont(ofSize: size, weight: f.weight == .semibold ? .semibold : .regular)
        return (f.serif ? base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? base : base) as CTFont
        #endif
    }

    static func width(_ s: String, _ font: CTFont) -> CGFloat {
        let a = NSAttributedString(string: s, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        return CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(a), nil, nil, nil))
    }

    static func lines(_ words: [String], _ font: CTFont, _ maxW: CGFloat) -> [Line] {
        let space = width(" ", font)
        var out: [Line] = [], cur = Line(words: [], width: 0)
        for (i, w) in words.enumerated() {
            let ww = width(w, font)
            if !cur.words.isEmpty, cur.width + space + ww > maxW { out.append(cur); cur = Line(words: [], width: 0) }
            cur.width += (cur.words.isEmpty ? 0 : space) + ww
            cur.words.append(i)
        }
        if !cur.words.isEmpty { out.append(cur) }
        return out
    }

    /// The largest size whose lines fit the box.
    static func fit(_ words: [String], _ face: Face, _ box: CGSize, _ top: CGFloat, _ bottom: CGFloat, _ step: CGFloat = 2) -> Fitted {
        var s = top
        while s >= bottom {
            let l = lines(words, ct(s, face), box.width)
            if CGFloat(l.count) * s * lead <= box.height, l.allSatisfy({ $0.width <= box.width }) { return Fitted(size: s, lines: l) }
            s -= step
        }
        let room = max(1, Int(box.height / (bottom * lead)))
        return Fitted(size: bottom, lines: Array(lines(words, ct(bottom, face), box.width).prefix(room)), cut: true)
    }

    private func text(_ s: String, _ size: CGFloat, _ face: Face, _ color: Color, x: CGFloat, base: CGFloat, anchor: UnitPoint = .topLeading) {
        let up = CTFontGetAscent(Self.ct(size, face))
        ctx.draw(Text(s).font(Self.font(size, face)).foregroundStyle(color), at: CGPoint(x: x, y: base - up), anchor: anchor)
    }

    private func clip(_ s: String, _ font: CTFont, _ w: CGFloat) -> String {
        if Self.width(s, font) <= w { return s }
        var t = s
        while t.count > 1, Self.width(t + "…", font) > w { t.removeLast() }
        return t + "…"
    }

    @discardableResult
    private func block(_ words: [String], _ f: Fitted, _ face: Face, x: CGFloat, y: CGFloat, _ color: Color, mark: ClosedRange<Int>? = nil) -> CGFloat {
        let font = Self.ct(f.size, face), space = Self.width(" ", font)
        var last = y
        for (n, line) in f.lines.enumerated() {
            let base = y + f.size + CGFloat(n) * f.size * Self.lead
            last = base
            var cx = x, from: CGFloat?, to: CGFloat = 0
            for (k, i) in line.words.enumerated() {
                let end = f.cut && n == f.lines.count - 1 && k == line.words.count - 1
                let t = end ? words[i] + "…" : words[i], w = Self.width(t, font)
                text(t, f.size, face, color, x: cx, base: base)
                if let mark, mark.contains(i) { if from == nil { from = cx }; to = cx + w }
                cx += w + space
            }
            if let from { stroke(from, base + f.size * 0.16, to - from, d.paper == .theme ? pencil : accent, max(3, f.size * 0.07)) }
        }
        return last + f.size * 0.3
    }

    // MARK: Marks

    private func stroke(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ color: Color, _ thick: CGFloat) {
        var p = Path()
        p.move(to: CGPoint(x: x - 4, y: y + thick * 0.4))
        p.addCurve(to: CGPoint(x: x + w + 6, y: y - thick * 0.2), control1: CGPoint(x: x + w * 0.3, y: y - thick * 1.1), control2: CGPoint(x: x + w * 0.62, y: y + thick * 1.5))
        ctx.stroke(p, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: thick, lineCap: .round))
    }

    private func loop(_ r: CGRect, _ color: Color) {
        func p(_ a: CGFloat, _ b: CGFloat) -> CGPoint { CGPoint(x: r.minX + a / 100 * r.width, y: r.minY + b / 60 * r.height) }
        var path = Path()
        path.move(to: p(58, 4))
        path.addCurve(to: p(5, 31), control1: p(26, 2), control2: p(4, 14))
        path.addCurve(to: p(58, 55), control1: p(6, 49), control2: p(34, 57))
        path.addCurve(to: p(95, 27), control1: p(84, 53), control2: p(97, 42))
        path.addCurve(to: p(44, 6), control1: p(93, 12), control2: p(72, 3))
        ctx.stroke(path, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    // MARK: The footer: themes, the Setting and the date, and whose page it is

    private func footer(_ W: CGFloat, _ H: CGFloat, _ M: CGFloat, left: CGFloat, spine: Bool) -> CGFloat {
        let s = (W * 0.026).rounded(), sans = Face(serif: false), brand = Face(weight: .semibold), y = H - M
        let bs = (s * 1.05).rounded(), bw = Self.width("CentMemo", Self.ct(bs, brand))
        text("CentMemo", bs, brand, pencil, x: W - M - bw, base: y)
        let room = W - M - left - bw - s * 1.5
        let placed = d.look == .setting
        let where_ = [d.showSetting && !placed ? c.setting : nil, d.showDate && !placed && (!spine || d.showThemes) ? c.date : nil].compactMap { $0 }.joined(separator: " · ")
        if !where_.isEmpty { text(clip(where_, Self.ct(s, sans), room), s, sans, muted, x: left, base: y) }
        if spine { return H - M - s * 2.4 }
        if d.showThemes, !c.themes.isEmpty {
            let ty = y - (where_.isEmpty ? 0 : s * 1.7)
            var tx = left
            for t in c.themes.prefix(2) {
                let w = s * 1.1 + Self.width(t.name, Self.ct(s, sans)) + s * 1.3
                if tx + w > W - M { break }
                let color = d.paper == .theme ? ink : hex(d.paper == .night ? t.night : t.paper)
                ctx.fill(Path(roundedRect: CGRect(x: tx, y: ty - s * 0.5, width: s * 0.85, height: s * 0.28), cornerRadius: s * 0.14), with: .color(color))
                text(t.name, s, sans, muted, x: tx + s * 1.1, base: ty)
                tx += w
            }
        }
        return H - M - s * 3.6
    }

    // MARK: The four looks (S3)

    func paint() {
        let size = d.shape.size, W = size.width, H = size.height, short = min(W, H)
        let M = (short * 0.09).rounded(), words = c.words
        let memo = Face(), strong = Face(weight: .semibold)
        let big = (short * (H > W * 1.5 ? 0.112 : 0.085)).rounded()
        let mark = d.mark.flatMap { m in words.isEmpty ? nil : m.clamped(to: 0...(words.count - 1)) }
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bg))

        switch d.look {
        case .theme:
            let spine = (short * 0.13).rounded()
            ctx.fill(Path(CGRect(x: 0, y: 0, width: spine, height: H)), with: .color(d.paper == .theme ? Color.black.opacity(0.18) : accent))
            let ls = (spine * 0.36).rounded(), label = d.showThemes ? (first?.name ?? c.date) : c.date
            var turned = ctx
            turned.translateBy(x: spine * 0.62, y: H - M)
            turned.rotate(by: .degrees(-90))
            let shown = clip(label, Self.ct(ls, strong), H - M * 2)
            turned.draw(Text(shown).font(Self.font(ls, strong)).foregroundStyle(d.paper == .night ? hex(0x171615) : hex(0xFBFAF7)),
                        at: CGPoint(x: 0, y: -CTFontGetAscent(Self.ct(ls, strong))), anchor: .topLeading)
            let x = spine + M * 0.8, bottom = footer(W, H, M, left: x, spine: true)
            block(words, Self.fit(words, memo, CGSize(width: W - x - M, height: bottom - M), big, 28), memo, x: x, y: M, ink, mark: mark)

        case .setting:
            let bottom = footer(W, H, M, left: M, spine: false)
            let t = (short * 0.15).rounded()
            var x = M
            if d.showSetting {
                let box = CGRect(x: M, y: M, width: t, height: t)
                ctx.stroke(Path(roundedRect: box, cornerRadius: t * 0.2), with: .color(muted), lineWidth: 3)
                let s = (t * 0.36).rounded(), w = Self.width(c.initials, Self.ct(s, strong))
                text(c.initials, s, strong, ink, x: M + (t - w) / 2, base: M + t * 0.56)
                ctx.fill(Path(CGRect(x: M + t * 0.18, y: M + t * 0.76, width: t * 0.64, height: t * 0.05)), with: .color(accent))
                x = M + t + M * 0.45
            }
            let name = (d.showSetting ? c.setting : c.date).split(whereSeparator: \.isWhitespace).map(String.init)
            let nf = Self.fit(name, strong, CGSize(width: W - x - M, height: t), (t * 0.62).rounded(), 30)
            block(name, nf, strong, x: x, y: M + max(0, (t - CGFloat(nf.lines.count) * nf.size * Self.lead) / 2), ink)
            var y = M + t + M * 0.5
            if d.showDate, d.showSetting {
                let s = (W * 0.026).rounded(), sans = Face(serif: false), w = Self.width(c.date, Self.ct(s, sans))
                text(c.date, s, sans, muted, x: M + s * 0.9, base: y + s * 1.15)
                loop(CGRect(x: M - s * 0.2, y: y - s * 0.15, width: w + s * 2.2, height: s * 2.1), pencil)
                y += s * 3
            }
            block(words, Self.fit(words, memo, CGSize(width: W - M * 2, height: bottom - y), big, 26), memo, x: M, y: y, ink, mark: mark)

        case .words:
            let bottom = footer(W, H, M, left: M, spine: false)
            let sentence = words.firstIndex { $0.hasSuffix(".") || $0.hasSuffix("!") || $0.hasSuffix("?") }.map { Array(words[...$0]) } ?? words
            let chosen = mark.map { Array(words[$0]) } ?? sentence, whole = chosen.count == words.count
            let f = Self.fit(chosen, strong, CGSize(width: W - M * 2, height: (bottom - M) * (whole ? 1 : 0.62)), (short * 0.16).rounded(), 34, 3)
            let end = block(chosen, f, strong, x: M, y: M * 0.8, d.paper == .theme ? ink : pencil)
            if !whole {
                let rest = Self.fit(words, memo, CGSize(width: W - M * 2, height: bottom - end - M * 0.4), (big * 0.6).rounded(), 24)
                block(words, rest, memo, x: M, y: end + M * 0.4, ink)
            }

        case .page:
            let bottom = footer(W, H, M, left: M, spine: false)
            block(words, Self.fit(words, memo, CGSize(width: W - M * 2, height: bottom - M), (big * 1.1).rounded(), 28), memo, x: M, y: M * 0.8, ink, mark: mark)
        }
    }
}
#endif
