#if os(iOS)
import SwiftUI

/// D14: Ben's approved starter themes (Themes.starters), as the web's
/// firstRunThemes and starterRows. A mark, a name, and what it means.
struct StarterThemeLabel: View {
    let starter: Themes.Starter
    let color: String

    var body: some View {
        HStack(spacing: Spacing.s3) {
            Capsule().fill(ThemeHue.swatch(color)).frame(width: 4, height: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(starter.name).font(TypeRamp.bodyStrong).foregroundStyle(Color.brandText)
                Text(starter.meaning).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
            }
        }
    }
}

/// First run: a person with purchases and no themes is asked which fit. All
/// start unticked, so the choice is theirs; Not now hides it for good.
struct FirstRunThemesSection: View {
    let onDone: () -> Void
    @Environment(SessionStore.self) private var session
    @State private var picked: Set<String> = []
    @State private var saving = false
    @State private var note: String?
    static let seenKey = "startersSeen"

    var body: some View {
        Section {
            ForEach(Themes.starters, id: \.name) { s in
                Button {
                    if picked.contains(s.name) { picked.remove(s.name) } else { picked.insert(s.name) }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    HStack {
                        StarterThemeLabel(starter: s, color: s.color)
                        Spacer()
                        Image(systemName: picked.contains(s.name) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(picked.contains(s.name) ? Color.brandPrimary : Color.brandTextMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked.contains(s.name) ? .isSelected : [])
                .accessibilityIdentifier("starter-\(s.color)")
            }
            HStack {
                Button("Keep these") { Task { await keep() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(picked.isEmpty || saving)
                    .accessibilityIdentifier("starters-keep")
                Button("Not now") { seen(); onDone() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("starters-later")
            }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Which of these sound like you?").font(Font.system(.title3, design: .serif).weight(.semibold)).foregroundStyle(Color.brandPrimary)
                Text("Themes collect your memos. Rename or remove them any time in Settings.")
                    .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
            }
            .textCase(nil)
            .accessibilityIdentifier("first-themes")
        } footer: {
            if let note { Text(note).foregroundStyle(Color.semanticError) }
        }
    }

    static var wasSeen: Bool { UserDefaults.standard.bool(forKey: seenKey) }
    private func seen() { UserDefaults.standard.set(true, forKey: Self.seenKey) }

    private func keep() async {
        saving = true
        defer { saving = false }
        do {
            for s in Themes.starters where picked.contains(s.name) { _ = try await APIClient.shared.addValue(s.name) }
            _ = try? await APIClient.shared.values()
            seen()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            session.didChangeData()
            onDone()
        } catch {
            note = session.handle(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
#endif
