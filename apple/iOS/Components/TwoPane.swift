#if os(iOS) || os(macOS)
import SwiftUI

/// At regular width (the open iPhone Duo, an iPad) a list and the purchase it
/// opens sit side by side: the list on the left, the story on the right.
/// Compact width (every closed phone, the iPhone 12) keeps the push. The branch
/// is on width only, never on the device (Ear Drama iOS-DESIGN 3.6).
extension EnvironmentValues {
    /// True when a purchase is drawn as the right-hand pane: its own header carries
    /// the title, so it leaves the shared navigation title to the list.
    @Entry var inPane = false
}

/// The two edges at regular width (Ear Drama iOS-DESIGN §3.6b, §3.6e, adopted
/// 2026-11-22 after Ben: "the padding being inconsistent across multiple
/// surfaces"): words (titles, rows, totals, the month bar) stand 20pt in from
/// both edges of a column, as the screen title does; boxes (cards) stand 16pt
/// in. The right pane keeps 20pt from the divider and from the tab strip.
/// Compact width keeps the 16pt it always had.
/// DESIGN W: the room a screen has decides its layout, never the device.
enum Room {
    static let wide: CGFloat = 1100
    /// The purchase page becomes a desk (W3).
    static let desk: CGFloat = 780
    static let aside: CGFloat = 340
    /// The longest line of reading (W5).
    static let measure: CGFloat = 640
}

extension View {
    /// Reports the width this view was given.
    func readsRoom(_ room: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.width } action: { room.wrappedValue = $0 }
    }
}

/// Where a share screen puts its choices beside the preview. The open Duo gives a sheet
/// 653pt whatever is asked for (a custom PresentationSizing is ignored, 2026-11-24).
enum StudioRoom {
    static let beside: CGFloat = 640
    static func choices(_ room: CGFloat) -> CGFloat { room >= 760 ? 396 : 348 }
    /// An iOS form beside another column has no margin of its own on that side; the Mac's does.
    static var gap: CGFloat {
        #if os(macOS)
        0
        #else
        16
        #endif
    }
}

enum PaneEdges {
    static let words: CGFloat = 20
    static let box: CGFloat = 16
    static let pane: CGFloat = 20
}

/// Ear Drama's PageMargins (iOS-DESIGN §3.6a): a List counts its content margins from
/// its own edges, not the safe area, so the margin adds the List's measured safe-area
/// insets (the tab strip's, at the trailing edge). Without that the pane's cards ran
/// under the strip (seen on the open Duo, 2026-11-22).
struct PaneMargins: ViewModifier {
    let on: Bool
    @State private var safe = EdgeInsets()
    func body(content: Content) -> some View {
        if on {
            content
                .contentMargins(.leading, PaneEdges.pane + safe.leading, for: .scrollContent)
                .contentMargins(.trailing, PaneEdges.pane + safe.trailing, for: .scrollContent)
                .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { safe = $0 }
        } else {
            content
        }
    }
}

extension View {
    /// A text row's horizontal insets: the words edge at regular width, 16pt compact.
    func columnRowInsets(vertical: CGFloat? = nil) -> some View { modifier(ColumnRowInsets(vertical: vertical)) }
}

private struct ColumnRowInsets: ViewModifier {
    var vertical: CGFloat?
    @Environment(\.horizontalSizeClass) private var width
    func body(content: Content) -> some View {
        let h = width == .regular ? PaneEdges.words : Spacing.s4
        if let vertical {
            content.listRowInsets(EdgeInsets(top: vertical, leading: h, bottom: vertical, trailing: h))
        } else if #available(iOS 26.0, *) {
            content.listRowInsets(.horizontal, h)
        } else {
            content.listRowInsets(EdgeInsets(top: 11, leading: h, bottom: 11, trailing: h))
        }
    }
}

/// Every push to a purchase goes through this one route type.
struct EntryRoute: Hashable { let id: String }

@Observable final class PaneSelection {
    var route: EntryRoute?
}

/// The one link to a purchase: a push when compact, the right-hand pane when regular.
struct EntryLink<Label: View>: View {
    let id: String
    @ViewBuilder let label: () -> Label
    @Environment(\.horizontalSizeClass) private var width
    @Environment(PaneSelection.self) private var pane: PaneSelection?

    var body: some View {
        if width == .regular, let pane {
            Button { pane.route = EntryRoute(id: id) } label: {
                // No chevron: the opened row's highlight and the right pane say where it went.
                label().frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(pane.route?.id == id ? Color.brandSurfaceAlt : Color.clear)
            .accessibilityAddTraits(pane.route?.id == id ? .isSelected : [])
        } else {
            NavigationLink(value: EntryRoute(id: id), label: label)
        }
    }
}

extension View {
    /// At regular width, open the list's first purchase on the right when nothing
    /// is open yet, so the second pane is never an empty half-screen.
    func opensFirst(_ id: String?) -> some View { modifier(OpensFirst(id: id)) }
}

private struct OpensFirst: ViewModifier {
    let id: String?
    @Environment(\.horizontalSizeClass) private var width
    @Environment(PaneSelection.self) private var pane: PaneSelection?
    func body(content: Content) -> some View {
        content.task(id: id) {
            if width == .regular, let pane, pane.route == nil, let id { pane.route = EntryRoute(id: id) }
        }
    }
}

/// A tab's content: one stack when compact; at regular width the list on the
/// left and the selected purchase on the right.
struct TwoPane<List: View>: View {
    @ViewBuilder let list: () -> List
    let destinations: (AnyView) -> AnyView
    /// The Unexamined tab's stack takes inbox pushes (deep links, test doors).
    var path: Binding<NavigationPath>? = nil
    @Environment(\.horizontalSizeClass) private var width
    @Environment(AppStore.self) private var store
    @State private var pane = PaneSelection()
    @State private var room: CGFloat = 0

    var body: some View {
        if width == .regular {
            // Ear Drama's pattern (iOS-DESIGN §3.6e, ProductionScreen): ONE stack for the
            // screen, the list as a plain column beside the detail. A stack per pane is a
            // navigation controller of its own that takes the whole window's safe area,
            // so the list ended 84pt (the tab strip's inset) short of the divider
            // (measured on the open Duo, 2026-11-22).
            screenStack {
                HStack(spacing: 0) {
                    destinations(AnyView(list()))
                        .frame(width: room >= Room.wide ? 440 : 380)  // W2
                    Divider()
                    Group {
                        if let r = pane.route {
                            EntryDetailView(entryID: r.id).id(r.id)
                        } else {
                            ContentUnavailableView("Choose a purchase", systemImage: "square.and.pencil")
                        }
                    }
                    .environment(\.inPane, true)
                    .frame(maxWidth: .infinity)
                }
                .readsRoom($room)
            }
            .environment(pane)
            // A link that opened an item (the inbox) shows it on the right, not
            // pushed onto the list's stack.
            .onChange(of: store.openedItem, initial: true) { _, id in
                guard let path, let id else { return }
                pane.route = EntryRoute(id: id)
                path.wrappedValue = NavigationPath()
            }
        } else {
            leftStack
        }
    }

    @ViewBuilder private func screenStack<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        if let path {
            NavigationStack(path: path) { content() }
        } else {
            NavigationStack { content() }
        }
    }

    @ViewBuilder private var leftStack: some View {
        screenStack { destinations(AnyView(list())) }
    }
}
#endif
