#if os(iOS)
import SwiftUI

/// Paper behind every list and form, ink text on it (DESIGN C1). The
/// person's color is never a background (Decision 060).
struct Grounded: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.brandBackground.ignoresSafeArea())
            .foregroundStyle(Color.brandText)
    }
}

extension View {
    func grounded() -> some View { modifier(Grounded()) }
    /// A row drawn straight on the ground (plain lists).
    func onGround() -> some View { listRowBackground(Color.clear) }
}

/// Serif navigation titles in sanguine, and a bar that lets the ground show.
enum NavigationLook {
    static func apply() {
        let large = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
            .withDesign(.serif)?.withSymbolicTraits(.traitBold) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
        let inline = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline).withDesign(.serif)
            ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
        let ink = UIColor(Color.brandPrimary)  // titles are sanguine (DESIGN C2)
        let look = UINavigationBarAppearance()
        look.configureWithTransparentBackground()
        look.largeTitleTextAttributes = [.font: UIFont(descriptor: large, size: 0), .foregroundColor: ink]
        look.titleTextAttributes = [.font: UIFont(descriptor: inline, size: 0), .foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = look
        UINavigationBar.appearance().scrollEdgeAppearance = look
        UINavigationBar.appearance().compactAppearance = look
    }
}
#endif

#if os(iOS)
/// DESIGN M1: the pencil circle drawn around the Unexamined count. The same path
/// as the web's `.pencil-circle` mask (css/styles.css), in a 100x60 box scaled to
/// the content, so both platforms draw one hand-closed loop that overshoots its start.
nonisolated struct PencilCircle: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x / 100 * r.width, y: r.minY + y / 60 * r.height) }
        var path = Path()
        path.move(to: p(58, 4))
        path.addCurve(to: p(5, 31), control1: p(26, 2), control2: p(4, 14))
        path.addCurve(to: p(58, 55), control1: p(6, 49), control2: p(34, 57))
        path.addCurve(to: p(95, 27), control1: p(84, 53), control2: p(97, 42))
        path.addCurve(to: p(44, 6), control1: p(93, 12), control2: p(72, 3))
        return path
    }
}
#endif
