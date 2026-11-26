#if os(iOS) || os(macOS)
import SwiftUI

/// W6 (Decision 069): one Share. Ben, 2026-11-26: "Why are "share" and "make a link"
/// different things?" Inside it, the person chooses what goes out: a picture they send
/// (nothing kept online) or a page at centmemo.com they can turn off.
enum ShareKind: String, CaseIterable { case picture, link }

private struct ShareKindKey: EnvironmentKey { static let defaultValue: Binding<ShareKind>? = nil }
extension EnvironmentValues {
    var shareKind: Binding<ShareKind>? {
        get { self[ShareKindKey.self] }
        set { self[ShareKindKey.self] = newValue }
    }
}

struct OneShareSheet<Picture: View, Page: View>: View {
    @State private var kind: ShareKind
    let picture: () -> Picture
    let page: () -> Page

    init(start: ShareKind = .picture, @ViewBuilder picture: @escaping () -> Picture, @ViewBuilder page: @escaping () -> Page) {
        _kind = State(initialValue: start)
        self.picture = picture
        self.page = page
    }

    var body: some View {
        Group {
            switch kind {
            case .picture: picture()
            case .link: page()
            }
        }
        .environment(\.shareKind, $kind)
    }
}

/// The switch at the top of either studio, and the one fact each choice needs.
struct ShareKindChrome: ViewModifier {
    @Environment(\.shareKind) private var kind

    func body(content: Content) -> some View {
        if let kind {
            content
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Share as", selection: kind) {
                            Text("Picture").tag(ShareKind.picture)
                            Text("Link").tag(ShareKind.link)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        .accessibilityIdentifier("share-kind")
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    Text(kind.wrappedValue == .picture ? "A picture you send. Nothing is kept online."
                                                       : "A page at centmemo.com. You can turn it off.")
                        .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.s2)
                        .background(Color.brandBackground)
                        .accessibilityIdentifier("share-kind-fact")
                }
        } else {
            content
        }
    }
}
#endif
