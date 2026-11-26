#if os(iOS) || os(macOS)
import SwiftUI
import UniformTypeIdentifiers

/// N4 (DESIGN S): the person designs their share. The card takes the memo, the
/// Setting, the date and the themes; it is never given what was paid.
struct ShareMemoSheet: View {
    let entry: LedgerEntry
    let memo: String
    @State private var design = ShareDesign()

    private var content: ShareContent {
        ShareContent(memo: memo, setting: entry.displayMerchant, initials: Money.merchantInitials(entry.displayMerchant),
                     date: LedgerDate.display(entry.txnDate),
                     themes: (entry.memo?.valueNames ?? []).map { n in
                         let c = Themes.hex[Themes.colorKey(n)] ?? (0x6F6964, 0xB3ACA6)
                         return .init(name: n, paper: c.0, night: c.1)
                     })
    }

    var body: some View {
        ShareStudio(title: "Share this memo", shape: design.shape, card: { ShareCard(content: content, design: design) },
                    choices: { choices }, send: { send })
    }

    private var send: some View {
        ShareLink(item: SharedPicture(render: { [content, design] in try SharedPicture.png(ShareCard(content: content, design: design)) }),
                  preview: SharePreview("A memo")) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .accessibilityIdentifier("share-send")
    }

    @ViewBuilder private var choices: some View {
        Section {
            ShareWords(words: content.words, mark: $design.mark, prefix: nil)
        } header: {
            Text("Mark the words that matter")
        }
        if design.look != .words { PencilPicker(pencil: $design.pencil) }
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
        SharePaperAndShape(paper: $design.paper, shape: $design.shape, hasTheme: !content.themes.isEmpty)
        Section("Show") {
            Toggle("Where", isOn: $design.showSetting).accessibilityIdentifier("share-setting")
            Toggle("When", isOn: $design.showDate).accessibilityIdentifier("share-date")
            if !content.themes.isEmpty { Toggle("Themes", isOn: $design.showThemes).accessibilityIdentifier("share-themes") }
        }
    }
}

/// Both studios: the card beside its choices where there is room, above them on a phone.
struct ShareStudio<Card: View, Choices: View, Send: View>: View {
    let title: String
    let shape: ShareDesign.Shape
    @ViewBuilder let card: () -> Card
    @ViewBuilder let choices: () -> Choices
    @ViewBuilder let send: () -> Send
    @State private var room: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if room >= StudioRoom.beside {
                    HStack(spacing: 0) {
                        preview(maxWidth: room - StudioRoom.choices(room) - PaneEdges.pane * 2, maxHeight: 560)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Form { choices() }.cardForm().padding(.leading, StudioRoom.gap).frame(width: StudioRoom.choices(room))
                    }
                } else {
                    Form {
                        Section {
                            preview(maxWidth: max(0, room - PaneEdges.pane * 2), maxHeight: 340)
                                .frame(maxWidth: .infinity)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        choices()
                    }
                    .cardForm()
                }
            }
            .readsRoom($room)
            .grounded()
            .navigationTitle(title)
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { send() }
            }
            .modifier(ShareKindChrome())
        }
        .studioSize()
    }

    private func preview(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let size = shape.size, scale = max(0.01, min(maxWidth / size.width, maxHeight / size.height))
        return card()
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
            .clipped()
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .accessibilityIdentifier("share-card")
            .padding(.vertical, Spacing.s3)
    }
}

/// A memo's words as buttons: first word, then last, and what is between is marked.
struct ShareWords: View {
    let words: [String]
    @Binding var mark: ClosedRange<Int>?
    let prefix: String?

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { i, w in
                let on = mark?.contains(i) ?? false
                Button {
                    var d = ShareDesign(mark: mark); d.tap(i); mark = d.mark; Haptic.selection()
                } label: {
                    Text(w).font(DisplayType.memo).foregroundStyle(Color.brandText)
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) { if on { Capsule().fill(Color.brandPrimary).frame(height: 3) } }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier(prefix.map { "share-word-\($0)-\(i)" } ?? "share-word-\(i)")
            }
        }
        if mark != nil { Button("No mark") { mark = nil }.buttonStyle(.borderless) }
    }
}

/// How the marked words are marked, on cards and on links.
struct PencilPicker: View {
    @Binding var pencil: ShareDesign.Pencil

    var body: some View {
        Section("Pencil") {
            Picker("Pencil", selection: $pencil) {
                ForEach(ShareDesign.Pencil.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            .accessibilityIdentifier("share-pencil")
        }
    }
}

struct SharePaperAndShape: View {
    @Binding var paper: ShareDesign.Paper
    @Binding var shape: ShareDesign.Shape
    let hasTheme: Bool

    var body: some View {
        Section("Paper") {
            Picker("Paper", selection: $paper) {
                Text("Paper").tag(ShareDesign.Paper.paper)
                Text("Night").tag(ShareDesign.Paper.night)
                if hasTheme { Text("Theme color").tag(ShareDesign.Paper.theme) }
            }
            .pickerStyle(.segmented).labelsHidden()
        }
        Section("Shape") {
            Picker("Shape", selection: $shape) {
                Text("Square").tag(ShareDesign.Shape.square)
                Text("Tall").tag(ShareDesign.Shape.tall)
                Text("Wide").tag(ShareDesign.Shape.wide)
            }
            .pickerStyle(.segmented).labelsHidden()
        }
    }
}

/// The card as a picture, drawn when the person sends it.
struct SharedPicture: Transferable {
    let render: @MainActor @Sendable () throws -> Data

    @MainActor static func png<V: View>(_ card: V) throws -> Data {
        let r = ImageRenderer(content: card)
        r.scale = 1
        #if os(macOS)
        guard let cg = r.cgImage, let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        #else
        guard let data = r.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
        #endif
        return data
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { p in try await p.render() }
            .suggestedFileName("CentMemo.png")
    }
}
#endif
