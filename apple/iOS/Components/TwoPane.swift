#if os(iOS)
import SwiftUI

/// At regular width (the open iPhone Duo, an iPad) a list and the purchase it
/// opens sit side by side: the list on the left, the story on the right.
/// Compact width (every closed phone, the iPhone 12) keeps the push. The branch
/// is on width only, never on the device (Ear Drama iOS-DESIGN 3.6).
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
                HStack { label(); Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.brandTextMuted.opacity(0.6)) }
                    .contentShape(Rectangle())
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
    @State private var pane = PaneSelection()

    var body: some View {
        if width == .regular {
            HStack(spacing: 0) {
                leftStack
                    .frame(minWidth: 320, idealWidth: 420, maxWidth: 480)
                Divider()
                NavigationStack {
                    Group {
                        if let r = pane.route {
                            EntryDetailView(entryID: r.id).id(r.id)
                        } else {
                            ContentUnavailableView("Choose a purchase", systemImage: "square.and.pencil")
                        }
                    }
                    .grounded()
                }
                .frame(maxWidth: .infinity)
            }
            .environment(pane)
        } else {
            leftStack
        }
    }

    @ViewBuilder private var leftStack: some View {
        if let path {
            NavigationStack(path: path) { destinations(AnyView(list())) }
        } else {
            NavigationStack { destinations(AnyView(list())) }
        }
    }
}
#endif
