#if os(iOS) || os(macOS)
import SwiftUI
import UniformTypeIdentifiers

/// N4 (DESIGN S): the person designs their share. The card takes the memo, the
/// Setting, the date and the themes; it is never given what was paid.
struct ShareMemoSheet: View {
    let entry: LedgerEntry
    let memo: String
    @State private var design = ShareDesign()
    @State private var room: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    private var content: ShareContent {
        ShareContent(memo: memo, setting: entry.displayMerchant, initials: Money.merchantInitials(entry.displayMerchant),
                     date: LedgerDate.display(entry.txnDate),
                     themes: (entry.memo?.valueNames ?? []).map { n in
                         let c = Themes.hex[Themes.colorKey(n)] ?? (0x6F6964, 0xB3ACA6)
                         return .init(name: n, paper: c.0, night: c.1)
                     })
    }

    var body: some View {
        NavigationStack {
            Group {
                if room >= 760 {
                    HStack(spacing: 0) {
                        preview(maxWidth: room - 380 - PaneEdges.pane * 2, maxHeight: 560)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Form { choices }.cardForm().frame(width: 380)
                    }
                } else {
                    Form {
                        Section {
                            preview(maxWidth: max(0, room - PaneEdges.pane * 2), maxHeight: 340)
                                .frame(maxWidth: .infinity)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        choices
                    }
                    .cardForm()
                }
            }
            .readsRoom($room)
            .grounded()
            .navigationTitle("Share this memo")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: SharedCard(content: content, design: design), preview: SharePreview("A memo")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("share-send")
                }
            }
        }
        .studioSize()
    }

    private func preview(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let size = design.shape.size
        let scale = max(0.01, min(maxWidth / size.width, maxHeight / size.height))
        return ShareCard(content: content, design: design)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
            .clipped()
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .accessibilityIdentifier("share-card")
            .padding(.vertical, Spacing.s3)
    }

    @ViewBuilder private var choices: some View {
        Section {
            FlowLayout(spacing: 6) {
                ForEach(Array(content.words.enumerated()), id: \.offset) { i, w in
                    let on = design.mark?.contains(i) ?? false
                    Button { design.tap(i); Haptic.selection() } label: {
                        Text(w).font(DisplayType.memo).foregroundStyle(Color.brandText)
                            .padding(.vertical, 4)
                            .overlay(alignment: .bottom) { if on { Capsule().fill(Color.brandPrimary).frame(height: 3) } }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("share-word-\(i)")
                }
            }
            if design.mark != nil { Button("No underline") { design.mark = nil } }
        } header: {
            Text("Underline the words that matter")
        }
        Section("Look") {
            Picker("Look", selection: $design.look) {
                Text("Page").tag(ShareDesign.Look.page)
                Text("Setting").tag(ShareDesign.Look.setting)
                Text("Theme").tag(ShareDesign.Look.theme)
                Text("Words").tag(ShareDesign.Look.words)
            }
            .pickerStyle(.segmented).labelsHidden()
            .accessibilityIdentifier("share-look")
        }
        Section("Paper") {
            Picker("Paper", selection: $design.paper) {
                Text("Paper").tag(ShareDesign.Paper.paper)
                Text("Night").tag(ShareDesign.Paper.night)
                if !content.themes.isEmpty { Text("Theme color").tag(ShareDesign.Paper.theme) }
            }
            .pickerStyle(.segmented).labelsHidden()
            .accessibilityIdentifier("share-paper")
        }
        Section("Shape") {
            Picker("Shape", selection: $design.shape) {
                Text("Square").tag(ShareDesign.Shape.square)
                Text("Tall").tag(ShareDesign.Shape.tall)
                Text("Wide").tag(ShareDesign.Shape.wide)
            }
            .pickerStyle(.segmented).labelsHidden()
            .accessibilityIdentifier("share-shape")
        }
        Section("Show") {
            Toggle("Setting", isOn: $design.showSetting).accessibilityIdentifier("share-setting")
            Toggle("Date", isOn: $design.showDate).accessibilityIdentifier("share-date")
            if !content.themes.isEmpty { Toggle("Themes", isOn: $design.showThemes).accessibilityIdentifier("share-themes") }
        }
    }
}

/// The card as a picture, drawn when the person sends it.
struct SharedCard: Transferable {
    let content: ShareContent
    let design: ShareDesign

    @MainActor func png() throws -> Data {
        let r = ImageRenderer(content: ShareCard(content: content, design: design))
        r.scale = 1
        #if os(macOS)
        guard let cg = r.cgImage, let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        #else
        guard let data = r.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
        #endif
        return data
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in try await card.png() }
            .suggestedFileName("CentMemo.png")
    }
}
#endif
