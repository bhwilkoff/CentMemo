#if os(iOS) || os(macOS)
import SwiftUI

/// W5 (Decision 069): ink is a memo part, drawn on paper in the pencil's color. The PNG
/// is always made in the light appearance on paper, so it reads the same on every page.
enum InkPaper {
    #if os(iOS)
    static let paper = UIColor(red: 0xFB / 255, green: 0xFA / 255, blue: 0xF7 / 255, alpha: 1)
    static let pencil = UIColor(red: 0x4A / 255, green: 0x15 / 255, blue: 0x20 / 255, alpha: 1)
    #endif
}

/// A drawing as it was kept, as wide as the memo and never taller than its own shape.
struct InkPicture: View {
    let path: String
    @State private var image: PlatformImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                #if os(iOS)
                Image(uiImage: image).resizable().scaledToFit()
                #else
                Image(nsImage: image).resizable().scaledToFit()
                #endif
            } else if failed {
                Label("This drawing couldn't be loaded.", systemImage: "scribble").font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 360)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card / 2))
        .overlay(RoundedRectangle(cornerRadius: Radius.card / 2).strokeBorder(Color.brandBorder))
        .accessibilityElement()
        .accessibilityLabel("Drawing")
        .accessibilityIdentifier("ink-picture")
        .task(id: path) {
            if let data = try? await APIClient.shared.copyData(path), let img = PlatformImage(data: data) { image = img } else { failed = true }
        }
    }
}

#if os(iOS)
import PencilKit
import Vision

/// Drawing with Apple Pencil or a finger, with the system's tool picker. Done keeps it;
/// "Add as words" reads the handwriting into the memo, only when the person asks.
struct InkSheet: View {
    /// The strokes to draw on again; nil for a new drawing.
    let load: () async -> Data?
    let keep: (PKDrawing) async -> Bool
    let words: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var drawing = PKDrawing()
    @State private var keeping = false
    @State private var reading = false
    @State private var note: String?

    var body: some View {
        NavigationStack {
            InkCanvas(drawing: $drawing)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Drawing")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            Task {
                                keeping = true
                                let kept = drawing.strokes.isEmpty ? true : await keep(drawing)
                                if kept { dismiss() } else { note = "This drawing wasn't kept. Try again." }
                                keeping = false
                            }
                        }
                        .disabled(keeping)
                        .accessibilityIdentifier("ink-done")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add as words", systemImage: "character.cursor.ibeam") { Task { await read() } }
                            .disabled(drawing.strokes.isEmpty || reading)
                    }
                }
                .safeAreaInset(edge: .top) {
                    if let note {
                        Text(note).font(TypeRamp.caption).padding(Spacing.s2).frame(maxWidth: .infinity).background(Color.brandSurfaceAlt)
                    }
                }
        }
        .task { if let data = await load(), let d = try? PKDrawing(data: data) { drawing = d } }
    }

    /// The person's own handwriting as text they can edit in the memo, never words written for them.
    private func read() async {
        reading = true
        defer { reading = false }
        guard let png = InkRender.png(drawing), let cg = UIImage(data: png)?.cgImage else { return }
        let found: String = await Task.detached {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try? VNImageRequestHandler(cgImage: cg).perform([request])
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }.value
        if found.isEmpty { note = "No handwriting was found to read." } else { words(found); note = "Added to the memo, where you can change it." }
    }
}

/// PencilKit's canvas: paper, the pencil's color, the system tool picker. A finger draws
/// on iPhone; on iPad the person's own Pencil setting decides (Only Draw with Apple Pencil).
struct InkCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let c = PKCanvasView()
        c.overrideUserInterfaceStyle = .light
        c.backgroundColor = InkPaper.paper
        c.drawing = drawing
        let pencil = PKInkingTool(.pen, color: InkPaper.pencil, width: 4)
        c.tool = pencil
        c.drawingPolicy = UIDevice.current.userInterfaceIdiom == .pad ? .default : .anyInput
        c.alwaysBounceVertical = true
        c.delegate = context.coordinator
        c.accessibilityIdentifier = "ink-canvas"
        let picker = context.coordinator.picker
        // The picker hands the canvas its own selected tool (a black pen), so it starts on ours.
        picker.selectedTool = pencil
        picker.setVisible(true, forFirstResponder: c)
        picker.addObserver(c)
        DispatchQueue.main.async { c.becomeFirstResponder() }
        return c
    }

    func updateUIView(_ c: PKCanvasView, context: Context) {
        if c.drawing != drawing { c.drawing = drawing }
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: InkCanvas
        let picker = PKToolPicker()
        init(_ p: InkCanvas) { parent = p }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { parent.drawing = canvasView.drawing }
    }
}

enum InkRender {
    /// The drawing on paper, 24pt of paper around it, at twice the screen's points.
    static func png(_ d: PKDrawing) -> Data? {
        guard !d.strokes.isEmpty else { return nil }
        let rect = d.bounds.insetBy(dx: -24, dy: -24)
        var out: Data?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            let ink = d.image(from: rect, scale: 2)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            out = UIGraphicsImageRenderer(size: rect.size, format: format).pngData { ctx in
                InkPaper.paper.setFill()
                ctx.fill(CGRect(origin: .zero, size: rect.size))
                ink.draw(in: CGRect(origin: .zero, size: rect.size))
            }
        }
        return out
    }
}
#endif
#endif
