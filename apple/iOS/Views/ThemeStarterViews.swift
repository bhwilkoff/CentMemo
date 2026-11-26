#if os(iOS) || os(macOS)
import SwiftUI

/// D14: Ben's approved starter themes (Themes.starters), as the web's
/// starterRows. A mark, a name, and what it means.
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

/// W1: where a person has no themes yet, the starters are offered in place, each in
/// its color, so the first theme is made by doing (Ben, 2026-11-26: "We need to at
/// least suggest that they be added within an onboarding interface").
struct StarterThemeRows: View {
    let held: [LifeValue]
    let add: (Themes.Starter) async -> Void
    @State private var adding: String?

    var body: some View {
        let have = Set(held.map { Themes.key($0.name) })
        ForEach(Themes.starters.filter { !have.contains(Themes.key($0.name)) }, id: \.name) { s in
            HStack {
                StarterThemeLabel(starter: s, color: Themes.nextColor(joining: held, name: s.name))
                Spacer()
                Button("Add") { Task { adding = s.name; await add(s); adding = nil } }
                    .buttonStyle(.bordered)
                    .disabled(adding != nil)
                    .accessibilityIdentifier("add-starter-\(s.color)")
            }
        }
    }
}

/// W1 on a memo with no themes yet: the starters as chips; a tap adds the theme and
/// gives it to this memo.
struct StarterThemeChips: View {
    let add: (Themes.Starter) async -> Void
    @State private var adding: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("Start with one of these, or name your own.").font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
            FlowLayout(spacing: 8) {
                ForEach(Themes.starters, id: \.name) { s in
                    Button { Task { adding = s.name; await add(s); adding = nil } } label: {
                        HStack(spacing: Spacing.s1) {
                            Image(systemName: "plus").font(TypeRamp.caption)
                            Text(s.name).font(TypeRamp.caption)
                        }
                        .padding(.horizontal, Spacing.s3).padding(.vertical, Spacing.s1)
                        .overlay(Capsule().strokeBorder(ThemeHue.swatch(s.color), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                        .foregroundStyle(Color.brandText)
                    }
                    .buttonStyle(.plain)
                    .disabled(adding != nil)
                    .accessibilityLabel("Add \(s.name)")
                    .accessibilityIdentifier("memo-starter-\(s.color)")
                }
            }
        }
    }
}
#endif
