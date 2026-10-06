import AVFoundation
import ImageIO
import Photos
import UIKit
import UniformTypeIdentifiers

// Live wallpapers. iOS plays a Live Photo on the Lock Screen when the
// screen wakes, so an animated scene is rendered here into a Live Photo: a
// still image and a short video that carry the same identifier. iOS has no
// way for an app to set it; the person picks it in the wallpaper chooser.

/// An animated scene, drawn with Core Graphics as a function of how far
/// through the clip it is. Ports of the website's Live wallpapers.
struct LiveScene: Identifiable, Hashable {
    enum Kind { case orbs, warp, sphere }

    let id: String
    let name: String
    let kind: Kind
    let palette: [String]

    static let all: [LiveScene] = [
        LiveScene(id: "glass-orbs", name: "Glass Orbs", kind: .orbs,
                  palette: ["#120b2e", "#2b1055", "#ff7ab6", "#7afcff", "#b18cff", "#ffd36e"]),
        LiveScene(id: "warp-speed", name: "Warp Speed", kind: .warp,
                  palette: ["#03030b", "#3a2a8c", "#9ad8ff", "#ffffff"]),
        LiveScene(id: "dot-sphere", name: "Dot Sphere", kind: .sphere,
                  palette: ["#05101f", "#0b2440", "#7cf3ff", "#2b59c3"]),
    ]

    static func scene(id: String) -> LiveScene? { all.first { $0.id == id } }

    /// Draws the frame `progress` (0...1) of the way through the clip into
    /// a context whose origin is bottom-left, as bitmap contexts are.
    func draw(in ctx: CGContext, width: Int, height: Int, progress: Double) {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        // The same seed every frame, so only time moves things.
        let p = Painter(ctx: ctx, width: Double(width), height: Double(height), rand: Rand(seed: fnvHash(name)))
        let c = palette.map { RGB(hex: $0) }
        switch kind {
        case .orbs: orbs(p, c, progress)
        case .warp: warp(p, c, progress)
        case .sphere: sphere(p, c, progress)
        }
        ctx.restoreGState()
    }

    func cgImage(width: Int, height: Int, progress: Double) -> CGImage? {
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        draw(in: ctx, width: width, height: height, progress: progress)
        return ctx.makeImage()
    }

    // palette: [top, bottom, ...orb colors]
    private func orbs(_ p: Painter, _ c: [RGB], _ progress: Double) {
        let phase = progress * 2 * .pi
        let w = p.w
        let h = p.h
        p.vertical([c[0], c[1]], y0: 0, y1: h)
        let colors = Array(c.dropFirst(2))
        struct Orb { var x, y, z, size: Double; var color: RGB; var k1, k2, p1, p2: Double }
        var orbs: [Orb] = []
        for i in 0..<14 {
            let x = p.r(), y = p.r(), z = 0.35 + p.r() * 0.65, size = 0.08 + p.r() * 0.1
            let k1 = 1 + (p.r() * 2).rounded(.down), k2 = 1 + (p.r() * 2).rounded(.down)
            let p1 = p.r() * 2 * .pi, p2 = p.r() * 2 * .pi
            orbs.append(Orb(x: x, y: y, z: z, size: size, color: colors[i % colors.count], k1: k1, k2: k2, p1: p1, p2: p2))
        }
        // Far orbs first; near ones drift further, which reads as depth.
        orbs.sort { $0.z < $1.z }
        for o in orbs {
            let x = (o.x + sin(phase * o.k1 + o.p1) * 0.07 * o.z) * w
            let y = (o.y + cos(phase * o.k2 + o.p2) * 0.06 * o.z) * h
            let rad = o.size * o.z * w
            let col = c[1].mix(o.color, 0.35 + o.z * 0.65)
            p.radial(center: p.pt(x, y + rad * 0.3), r0: 0, r1: rad * 2.2, stops: [(col, 0.28 * o.z, 0), (col, 0, 1)])
            if let g = p.gradient([(col.mix(.white, 0.7), 1, 0), (col, 1, 0.4), (col.mix(.black, 0.45), 1, 1)]) {
                p.clipped(p.circle(x, y, rad)) {
                    p.ctx.drawRadialGradient(
                        g, startCenter: p.pt(x - rad * 0.35, y - rad * 0.4), startRadius: CGFloat(rad * 0.05),
                        endCenter: p.pt(x, y), endRadius: CGFloat(rad), options: [.drawsAfterEndLocation])
                }
            }
            p.ctx.setStrokeColor(RGB.white.cg(0.22))
            p.ctx.setLineWidth(CGFloat(rad * 0.04))
            p.ctx.addArc(center: p.pt(x, y), radius: CGFloat(rad * 0.96), startAngle: .pi * 1.05, endAngle: .pi * 1.6, clockwise: false)
            p.ctx.strokePath()
        }
    }

    // palette: [background, core glow, star A, star B]
    private func warp(_ p: Painter, _ c: [RGB], _ progress: Double) {
        let w = p.w
        let cx = w / 2
        let cy = p.h * 0.45
        p.fill(c[0])
        p.radial(center: p.pt(cx, cy), r0: 0, r1: w * 0.9, stops: [(c[1], 0.35, 0), (c[1], 0, 1)])
        let f = w * 0.35
        p.ctx.setLineCap(.round)
        for _ in 0..<260 {
            let a = p.r() * 2 * .pi
            let rr = 0.15 + p.r() * 0.85
            let speed = 1 + (p.r() * 3).rounded(.down)
            // Each star flies toward the viewer a whole number of times, so
            // the clip ends where it began.
            let turns = p.r() - progress * speed
            let z = 0.02 + (turns - turns.rounded(.down)) * 0.98
            let color = c[2].mix(c[3], p.r())
            let x3 = cos(a) * rr
            let y3 = sin(a) * rr
            let z0 = min(1, z + 0.05)
            let fade = pow(1 - z, 0.7)
            p.ctx.setStrokeColor(color.cg(fade))
            p.ctx.setLineWidth(CGFloat((0.8 + fade * 3.6) * p.u * 1.5))
            p.ctx.move(to: p.pt(cx + x3 * f / z0, cy + y3 * f / z0))
            p.ctx.addLine(to: p.pt(cx + x3 * f / z, cy + y3 * f / z))
            p.ctx.strokePath()
        }
    }

    // palette: [top, bottom, near dots, far dots]
    private func sphere(_ p: Painter, _ c: [RGB], _ progress: Double) {
        let phase = progress * 2 * .pi
        let w = p.w
        let cx = w / 2
        let cy = p.h * 0.47
        let radius = w * 0.62
        p.vertical([c[0], c[1]], y0: 0, y1: p.h)
        p.radial(center: p.pt(cx, cy), r0: 0, r1: radius * 1.9, stops: [(c[2], 0.22, 0), (c[2], 0, 1)])
        let tilt = 0.4 + p.r() * 0.2 + sin(phase) * 0.12
        // A fifth of a turn over the clip: fast enough to see, slow enough to follow.
        let yaw = phase / 5 + p.r() * 2 * .pi
        let n = 900
        let golden = Double.pi * (3 - 5.0.squareRoot())
        var dots: [(x: Double, y: Double, z: Double)] = []
        dots.reserveCapacity(n)
        for i in 0..<n {
            let y = 1 - Double(i) / Double(n - 1) * 2
            let ring = (1 - y * y).squareRoot()
            let a = Double(i) * golden
            let x = cos(a) * ring
            let z = sin(a) * ring
            // Turn about the vertical axis, then tip toward the viewer.
            let x1 = x * cos(yaw) - z * sin(yaw)
            let z1 = x * sin(yaw) + z * cos(yaw)
            dots.append((x: x1, y: y * cos(tilt) - z1 * sin(tilt), z: y * sin(tilt) + z1 * cos(tilt)))
        }
        dots.sort { $0.z < $1.z }
        for dot in dots {
            let depth = (dot.z + 1) / 2
            let scale = 1 / (1.6 - dot.z * 0.45)
            let color = c[3].mix(c[2], depth)
            let r = (1.6 + depth * 4) * p.u * 1.7
            p.fill(p.circle(cx + dot.x * radius * scale, cy + dot.y * radius * scale, r), color, alpha: 0.2 + depth * 0.8)
        }
    }
}

/// Turns a scene into a Live Photo and saves it.
enum LivePhoto {
    /// Length of the clip, and where in it the still image is taken.
    static let seconds = 3.0
    static let framesPerSecond: Int32 = 30
    static let stillProgress = 0.5

    struct Files {
        let photo: URL
        let video: URL
        let identifier: String
    }

    enum MakeError: LocalizedError {
        case render, video(String)

        var errorDescription: String? {
            switch self {
            case .render: return "The wallpaper couldn't be drawn. Try again."
            case .video(let reason): return "The Live Photo's video couldn't be made (\(reason))."
            }
        }
    }

    /// Renders the scene to a still image and a video in the temporary
    /// folder. Slow (a few seconds): call it off the main thread. `progress`
    /// is called with 0...1 as frames are written.
    static func make(scene: LiveScene, pixelWidth: Int, pixelHeight: Int, progress: @escaping @Sendable (Double) -> Void) throws -> Files {
        let identifier = UUID().uuidString
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("live-" + identifier, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let photoURL = folder.appendingPathComponent(scene.id + ".jpg")
        let videoURL = folder.appendingPathComponent(scene.id + ".mov")

        // The still: full resolution, tagged with the shared identifier.
        guard let still = scene.cgImage(width: pixelWidth, height: pixelHeight, progress: stillProgress),
              let destination = CGImageDestinationCreateWithURL(photoURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw MakeError.render }
        let properties: [CFString: Any] = [
            kCGImagePropertyMakerAppleDictionary: ["17": identifier],
            kCGImageDestinationLossyCompressionQuality: 0.92,
        ]
        CGImageDestinationAddImage(destination, still, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw MakeError.render }

        // The video: at most 1080 wide, with even dimensions as encoders need.
        let videoWidth = min(1080, pixelWidth) / 2 * 2
        let videoHeight = Int((Double(videoWidth) * Double(pixelHeight) / Double(pixelWidth)).rounded()) / 2 * 2
        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: videoWidth,
            kCVPixelBufferHeightKey as String: videoHeight,
        ])
        writer.add(input)

        // What makes the pair a Live Photo: the identifier on the video, and
        // a metadata track marking the moment the still was taken.
        let idItem = AVMutableMetadataItem()
        idItem.keySpace = .quickTimeMetadata
        idItem.key = AVMetadataKey.quickTimeMetadataKeyContentIdentifier.rawValue as NSString
        idItem.value = identifier as NSString
        idItem.dataType = kCMMetadataBaseDataType_UTF8 as String
        writer.metadata = [idItem]

        let stillKey = "com.apple.quicktime.still-image-time"
        let specification: [String: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String: "mdta/" + stillKey,
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String: kCMMetadataBaseDataType_SInt8 as String,
        ]
        var description: CMFormatDescription?
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault, metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [specification] as CFArray, formatDescriptionOut: &description)
        let markerInput = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: description)
        let markerAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: markerInput)
        writer.add(markerInput)

        guard writer.startWriting() else { throw MakeError.video(writer.error?.localizedDescription ?? "couldn't start") }
        writer.startSession(atSourceTime: .zero)

        let frameCount = Int(seconds * Double(framesPerSecond))
        let stillFrame = Int(Double(frameCount) * stillProgress)
        let stillItem = AVMutableMetadataItem()
        stillItem.keySpace = .quickTimeMetadata
        stillItem.key = stillKey as NSString
        stillItem.value = 0 as NSNumber
        stillItem.dataType = kCMMetadataBaseDataType_SInt8 as String
        let stillTime = CMTime(value: CMTimeValue(stillFrame), timescale: framesPerSecond)
        markerAdaptor.append(AVTimedMetadataGroup(items: [stillItem], timeRange: CMTimeRange(start: stillTime, duration: CMTime(value: 1, timescale: framesPerSecond))))
        markerInput.markAsFinished()

        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { throw MakeError.render }
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                if writer.status != .writing { throw MakeError.video(writer.error?.localizedDescription ?? "stopped") }
                Thread.sleep(forTimeInterval: 0.004)
            }
            guard let pool = adaptor.pixelBufferPool else { throw MakeError.video("no pixel buffers") }
            var made: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &made)
            guard let buffer = made else { throw MakeError.video("no pixel buffer") }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let ctx = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer), width: videoWidth, height: videoHeight, bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
                scene.draw(in: ctx, width: videoWidth, height: videoHeight, progress: Double(frame) / Double(frameCount))
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            if !adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: framesPerSecond)) {
                throw MakeError.video(writer.error?.localizedDescription ?? "a frame was refused")
            }
            progress(Double(frame + 1) / Double(frameCount))
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frameCount), timescale: framesPerSecond))
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        guard writer.status == .completed else { throw MakeError.video(writer.error?.localizedDescription ?? "didn't finish") }
        return Files(photo: photoURL, video: videoURL, identifier: identifier)
    }

    /// Adds the pair to Photos as one Live Photo.
    static func save(_ files: Files) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw PhotoSaver.SaveError.denied }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = true
            request.addResource(with: .photo, fileURL: files.photo, options: options)
            request.addResource(with: .pairedVideo, fileURL: files.video, options: options)
        }
    }
}
