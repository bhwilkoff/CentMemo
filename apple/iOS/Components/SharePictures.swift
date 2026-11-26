#if os(iOS) || os(macOS)
import SwiftUI
import Vision
import Photos

/// W7 (Decision 069): the memo's photos and drawings, offered for the share one by one,
/// each off until the person turns it on. Ben, 2026-11-26: "When I add images or files,
/// shouldn't they also come into the shared memo?" A picture that reads as money (a price,
/// a total, a receipt) can't go: sharing never shows money (Ben, 2026-11-24).
@MainActor @Observable
final class SharePictureChoices {
    struct Candidate: Identifiable {
        let id: String
        var picture: SharePicture?
        var showsMoney = false
        var missing = false
    }
    static let most = 3
    private(set) var candidates: [Candidate] = []
    var chosen: [String] = []

    var pictures: [SharePicture] { chosen.compactMap { id in candidates.first { $0.id == id }?.picture } }

    func toggle(_ id: String) {
        if let i = chosen.firstIndex(of: id) { chosen.remove(at: i) }
        else if chosen.count < Self.most, candidates.first(where: { $0.id == id }).map({ $0.picture != nil && !$0.showsMoney }) == true { chosen.append(id) }
    }

    func load(_ attachments: [APIClient.Attachment]) async {
        let shown = attachments.filter { $0.kind == "photo" || $0.kind == "ink" }
        candidates = shown.map { Candidate(id: $0.id) }
        for a in shown {
            let image = await Self.image(a)
            guard let i = candidates.firstIndex(where: { $0.id == a.id }) else { continue }
            if let image {
                candidates[i].picture = SharePicture(id: a.id, image: image, whole: a.kind == "ink")
                candidates[i].showsMoney = await Self.readsAsMoney(image)
            } else {
                candidates[i].missing = true
            }
        }
    }

    private static func image(_ a: APIClient.Attachment) async -> CGImage? {
        var data: Data?
        if let path = a.storagePath { data = try? await APIClient.shared.copyData(path) }
        #if os(iOS)
        if data == nil, a.kind == "photo", let ref = a.deviceRef,
           [.authorized, .limited].contains(PHPhotoLibrary.authorizationStatus(for: .readWrite)) {
            data = await AttachedPhoto.copyForUpload(ref: ref)
        }
        #endif
        guard let data, let img = PlatformImage(data: data) else { return nil }
        #if os(iOS)
        return img.cgImage
        #else
        return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }

    /// Words that are money: a currency sign or code by a number, a price with cents, or a
    /// receipt's own words. Read on the device; nothing is sent anywhere to check.
    nonisolated static func readsAsMoney(_ image: CGImage) async -> Bool {
        await Task.detached {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try? VNImageRequestHandler(cgImage: image).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            return MoneyWords.found(in: text)
        }.value
    }
}

/// The choices row: the memo's pictures as thumbnails to turn on, up to three.
struct SharePictureRow: View {
    @Bindable var choices: SharePictureChoices

    var body: some View {
        if !choices.candidates.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.s2) {
                        ForEach(choices.candidates) { c in
                            let on = choices.chosen.contains(c.id)
                            Button { choices.toggle(c.id); Haptic.selection() } label: { thumb(c, on: on) }
                                .buttonStyle(.plain)
                                .disabled(c.picture == nil || c.showsMoney)
                                .accessibilityLabel(c.showsMoney ? "A picture that shows money, which can't be shared" : (on ? "Picture, on the card" : "Picture"))
                                .accessibilityAddTraits(on ? .isSelected : [])
                                .accessibilityIdentifier("share-picture-\(c.id)")
                        }
                    }
                    .padding(.vertical, Spacing.s1)
                }
            } header: {
                Text("Pictures")
            } footer: {
                if choices.candidates.contains(where: \.showsMoney) {
                    Text("A picture that shows a price or a total can't be shared.")
                }
            }
        }
    }

    private func thumb(_ c: SharePictureChoices.Candidate, on: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let p = c.picture {
                    Image(decorative: p.image, scale: 1).resizable().scaledToFill()
                } else if c.missing {
                    Image(systemName: "photo").foregroundStyle(Color.brandTextMuted)
                } else {
                    ProgressView()
                }
            }
            .frame(width: 72, height: 72)
            .background(Color.brandSurfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(c.showsMoney ? 0.35 : 1)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(on ? Color.brandPrimary : Color.brandBorder, lineWidth: on ? 3 : 1))
            if on { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brandPrimary).background(Circle().fill(Color.brandBackground)).padding(4) }
            if c.showsMoney { Image(systemName: "dollarsign.circle").foregroundStyle(Color.brandTextMuted).padding(4) }
        }
    }
}
#endif
