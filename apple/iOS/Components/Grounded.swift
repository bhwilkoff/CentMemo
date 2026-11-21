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
