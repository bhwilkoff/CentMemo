#if os(iOS)
import SwiftUI

/// Paper behind every list and form (DESIGN C1). No screen-wide foreground:
/// it would outrank the sanguine tint on every button (DESIGN C2, iOS note).
/// The person's color is never a background (Decision 060).
struct Grounded: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.brandBackground.ignoresSafeArea())
    }
}

extension View {
    func grounded() -> some View { modifier(Grounded()) }
    /// A row drawn straight on the ground (plain lists).
    func onGround() -> some View { listRowBackground(Color.clear) }
}

/// Serif navigation titles in sanguine, and a bar that lets the ground show.
enum NavigationLook {
    static func apply() {
        let large = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
            .withDesign(.serif)?.withSymbolicTraits(.traitBold) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
        let inline = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline).withDesign(.serif)
            ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
        let ink = UIColor(Color.brandPrimary)  // titles are sanguine (DESIGN C2)
        let look = UINavigationBarAppearance()
        look.configureWithTransparentBackground()
        look.largeTitleTextAttributes = [.font: UIFont(descriptor: large, size: 0), .foregroundColor: ink]
        look.titleTextAttributes = [.font: UIFont(descriptor: inline, size: 0), .foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = look
        UINavigationBar.appearance().scrollEdgeAppearance = look
        UINavigationBar.appearance().compactAppearance = look
    }
}
#endif

#if os(iOS)
/// DESIGN M1: the pencil circle drawn around the Unexamined count. The same path
/// as the web's `.pencil-circle` mask (css/styles.css), in a 100x60 box scaled to
/// the content, so both platforms draw one hand-closed loop that overshoots its start.
nonisolated struct PencilCircle: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x / 100 * r.width, y: r.minY + y / 60 * r.height) }
        var path = Path()
        path.move(to: p(58, 4))
        path.addCurve(to: p(5, 31), control1: p(26, 2), control2: p(4, 14))
        path.addCurve(to: p(58, 55), control1: p(6, 49), control2: p(34, 57))
        path.addCurve(to: p(95, 27), control1: p(84, 53), control2: p(97, 42))
        path.addCurve(to: p(44, 6), control1: p(93, 12), control2: p(72, 3))
        return path
    }
}
#endif

#if os(iOS)
import Photos

/// A photo attached by reference: drawn from this device's library when the
/// asset is here and the person has allowed access; otherwise a plain tile
/// that says why it can't be shown (the photo may live on another device).
struct AttachedPhoto: View {
    let ref: String
    @State private var image: UIImage?
    @State private var note: String?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.brandSurface)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let note {
                Text(note).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                    .multilineTextAlignment(.center).padding(6)
            } else {
                ProgressView()
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(image != nil ? "Attached photo" : (note ?? "Attached photo"))
        .task(id: ref) { await load() }
    }

    private func load() async {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined { status = await PHPhotoLibrary.requestAuthorization(for: .readWrite) }
        guard status == .authorized || status == .limited else { note = "Allow Photos access to show it"; return }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [ref], options: nil).firstObject else {
            note = "On another device"; return
        }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        image = await withCheckedContinuation { done in
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 288, height: 288),
                                                  contentMode: .aspectFill, options: opts) { img, _ in done.resume(returning: img) }
        }
        if image == nil { note = "Couldn't load it" }
    }
}
#endif
