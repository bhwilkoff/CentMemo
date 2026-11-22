// Joins timestamped PNG frames (<unix time>.png) into a 1920x1080 H.264 video,
// each frame held for as long as it was on screen, centered on CentMemo paper.
// AVFoundation only (Homebrew's ffmpeg broke on a missing x265 library).
//   swift tools/frames_to_video.swift <frames dir> <out.mp4>
import AVFoundation
import AppKit

let args = CommandLine.arguments
guard args.count == 3 else { print("usage: frames_to_video <dir> <out.mp4>"); exit(2) }
let dir = URL(fileURLWithPath: args[1]), out = URL(fileURLWithPath: args[2])
let shots = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    .filter { $0.hasSuffix(".png") }.compactMap { name -> (Double, URL)? in
        Double(name.dropLast(4)).map { ($0, dir.appendingPathComponent(name)) } }.sorted { $0.0 < $1.0 }
guard shots.count >= 10 else { print("only \(shots.count) frames"); exit(1) }
try? FileManager.default.removeItem(at: out)
let W = 1920, H = 1080
let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
let t0 = shots[0].0
func frame(_ url: URL) -> CVPixelBuffer? {
    guard let img = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(nil, W, H, kCVPixelFormatType_32BGRA, nil, &pb)
    guard let pb else { return nil }
    CVPixelBufferLockBaseAddress(pb, []); defer { CVPixelBufferUnlockBaseAddress(pb, []) }
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: W, height: H, bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.setFillColor(CGColor(red: 0xFB/255, green: 0xFA/255, blue: 0xF7/255, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    let h = Double(H), w = h * Double(img.width) / Double(img.height)
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: (Double(W) - w) / 2, y: 0, width: w, height: h))
    return pb
}
var written = 0
for (i, shot) in shots.enumerated() {
    guard let pb = frame(shot.1) else { continue }
    while !input.isReadyForMoreMediaData { usleep(5000) }
    adaptor.append(pb, withPresentationTime: CMTime(seconds: shot.0 - t0, preferredTimescale: 600))
    written += 1
    if i == shots.count - 1 {   // hold the last frame for two seconds
        while !input.isReadyForMoreMediaData { usleep(5000) }
        adaptor.append(pb, withPresentationTime: CMTime(seconds: shot.0 - t0 + 2, preferredTimescale: 600))
    }
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print(writer.status == .completed ? "\(out.path): \(written) frames over \(Int(shots.last!.0 - t0)) s" : "failed: \(String(describing: writer.error))")
exit(writer.status == .completed ? 0 : 1)
