#if os(iOS) || os(macOS)
import SwiftUI
import Photos

/// W8 (Decision 069): photos stand in the memo, each in a style the person chose. Ben,
/// 2026-11-26: "I'd like to be able to style the photos as a part of the memo."
/// Plate: the photo's own shape. Mounted: on a paper mat with room for words, as an
/// archival print. Strip: beside the strip photos next to it, square, one caption.
/// No filters, tilts or tape (DESIGN M).
enum PhotoStyle: String, CaseIterable, Identifiable {
    case plate, mounted, strip
    var id: String { rawValue }
    var title: String { switch self { case .plate: "Plate"; case .mounted: "Mounted"; case .strip: "Strip" } }
    var symbol: String { switch self { case .plate: "photo"; case .mounted: "photo.artframe"; case .strip: "square.split.2x1" } }
}

struct MemoPhotos: View {
    let photos: [APIClient.Attachment]
    let restyle: (APIClient.Attachment, PhotoStyle) -> Void
    let caption: (APIClient.Attachment) -> Void
    let more: (APIClient.Attachment) -> AnyView

    /// Neighbouring strip photos make one strip (up to four); the rest stand alone.
    private var groups: [[APIClient.Attachment]] {
        var out: [[APIClient.Attachment]] = []
        for a in photos {
            if Self.style(a) == .strip, let last = out.last, last.count < 4, Self.style(last[0]) == .strip { out[out.count - 1].append(a) }
            else { out.append([a]) }
        }
        return out
    }
    static func style(_ a: APIClient.Attachment) -> PhotoStyle { PhotoStyle(rawValue: a.style ?? "") ?? .plate }

    var body: some View {
        ForEach(groups, id: \.first!.id) { g in
            Group {
                switch Self.style(g[0]) {
                case .strip:
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        HStack(spacing: 6) {
                            ForEach(g) { a in
                                MemoPhotoImage(attachment: a, fill: true)
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .contextMenu { menu(a) }
                                    .accessibilityIdentifier("memo-photo-strip")
                            }
                        }
                        words(g.first { !($0.caption ?? "").isEmpty })
                    }
                case .mounted:
                    let a = g[0]
                    VStack(alignment: .leading, spacing: Spacing.s3) {
                        MemoPhotoImage(attachment: a, fill: false)
                        words(a)
                    }
                    .padding(EdgeInsets(top: 14, leading: 14, bottom: 22, trailing: 14))
                    .background(Color.brandSurface)
                    .overlay(Rectangle().strokeBorder(Color.brandBorder, lineWidth: 1))
                    .contextMenu { menu(a) }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("memo-photo-mounted")
                case .plate:
                    let a = g[0]
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        MemoPhotoImage(attachment: a, fill: false)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        words(a)
                    }
                    .contextMenu { menu(a) }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("memo-photo-plate")
                }
            }
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder private func words(_ a: APIClient.Attachment?) -> some View {
        if let c = a?.caption, !c.isEmpty, a?.kind == "photo" {
            Text(c).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
        }
    }

    @ViewBuilder private func menu(_ a: APIClient.Attachment) -> some View {
        Picker("Style", selection: Binding(get: { Self.style(a) }, set: { restyle(a, $0) })) {
            ForEach(PhotoStyle.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
        }
        Button((a.caption ?? "").isEmpty ? "Add words under it" : "Change the words under it", systemImage: "text.below.photo") { caption(a) }
        more(a)
    }
}

/// A memo photo at the memo's width: the kept copy if there is one, else the library's.
struct MemoPhotoImage: View {
    let attachment: APIClient.Attachment
    let fill: Bool
    @State private var image: PlatformImage?
    @State private var note: String?

    var body: some View {
        Group {
            if let image {
                if fill { Color.clear.overlay(Image(platform: image).resizable().scaledToFill()).clipped() }
                else { Image(platform: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 520) }
            } else if let note {
                Text(note).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted).frame(maxWidth: .infinity, minHeight: 96).background(Color.brandSurfaceAlt)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120).background(Color.brandSurfaceAlt)
            }
        }
        .accessibilityLabel(attachment.caption.flatMap { $0.isEmpty ? nil : $0 } ?? "A photo in this memo")
        .task(id: attachment.id) { await load() }
    }

    private func load() async {
        if let path = attachment.storagePath, let data = try? await APIClient.shared.copyData(path), let img = PlatformImage(data: data) { image = img; return }
        guard let ref = attachment.deviceRef else { note = "Couldn't load it"; return }
        #if os(iOS)
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined { status = await PHPhotoLibrary.requestAuthorization(for: .readWrite) }
        guard status == .authorized || status == .limited else { note = "Allow Photos access to show it"; return }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [ref], options: nil).firstObject else { note = "On another device"; return }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        image = await withCheckedContinuation { done in
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1400, height: 1400), contentMode: .aspectFit, options: opts) { img, info in
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                done.resume(returning: img)
            }
        }
        if image == nil { note = "Couldn't load it" }
        #else
        note = "On your iPhone or iPad"
        #endif
    }
}
#endif
