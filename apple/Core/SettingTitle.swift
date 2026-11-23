import SwiftUI

/// A Setting's name as a page title that never breaks a word: it steps down a
/// size when the name's longest word would not fit on one line. ("AutoNation"
/// split as "AutoNa-tion" at Ben's text size in the open Duo's pane, 2026-11-23.)
struct SettingTitle: View {
    let name: String
    var sizes: [Font] = [DisplayType.title,
                         Font.system(.title, design: .serif).weight(.bold),
                         Font.system(.title2, design: .serif).weight(.bold)]

    static func longestWord(_ name: String) -> String {
        name.split(separator: Character(" ")).map(String.init).max { $0.count < $1.count } ?? name
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Array(sizes.enumerated()), id: \.offset) { _, font in
                // Its ideal width is the longest word's, so ViewThatFits takes the
                // largest size at which every word fits whole.
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).font(font).lineLimit(3)
                        .frame(minWidth: 0, idealWidth: 0, maxWidth: .infinity, alignment: .leading)
                    Text(Self.longestWord(name)).font(font).fixedSize()
                        .frame(height: 0).hidden().accessibilityHidden(true)
                }
            }
        }
    }
}
