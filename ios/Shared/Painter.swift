import CoreGraphics
import UIKit

/// Drawing helpers over a bitmap context whose origin is top-left (like the
/// web canvas), plus the seeded random source for one wallpaper.
final class Painter {
    let ctx: CGContext
    let w: Double
    let h: Double
    let r: Rand
    private let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    /// 1/1000 of the width: sizes scale with the canvas.
    var u: Double { w / 1000 }

    init(ctx: CGContext, width: Double, height: Double, rand: Rand) {
        self.ctx = ctx
        self.w = width
        self.h = height
        self.r = rand
    }

    func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    var bounds: CGRect { CGRect(x: 0, y: 0, width: w, height: h) }

    // MARK: Fills

    func fill(_ color: RGB, alpha: Double = 1) {
        ctx.setFillColor(color.cg(alpha))
        ctx.fill(bounds)
    }

    func fill(_ rect: CGRect, _ color: RGB, alpha: Double = 1) {
        ctx.setFillColor(color.cg(alpha))
        ctx.fill(rect)
    }

    func fill(_ path: CGPath, _ color: RGB, alpha: Double = 1) {
        ctx.addPath(path)
        ctx.setFillColor(color.cg(alpha))
        ctx.fillPath()
    }

    func gradient(_ stops: [(RGB, Double, Double)]) -> CGGradient? {
        CGGradient(
            colorsSpace: space,
            colors: stops.map { $0.0.cg($0.1) } as CFArray,
            locations: stops.map { CGFloat($0.2) }
        )
    }

    /// Evenly spaced opaque stops.
    func gradient(_ colors: [RGB]) -> CGGradient? {
        let n = Double(max(colors.count - 1, 1))
        var stops: [(RGB, Double, Double)] = []
        for (i, color) in colors.enumerated() {
            stops.append((color, 1.0, Double(i) / n))
        }
        return gradient(stops)
    }

    /// Draws a linear gradient over the current clip, extended past both ends.
    func linear(_ g: CGGradient?, from: CGPoint, to: CGPoint) {
        guard let g else { return }
        ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    func vertical(_ colors: [RGB], y0: Double, y1: Double, in rect: CGRect? = nil) {
        clipped(rect ?? bounds) { linear(gradient(colors), from: pt(0, y0), to: pt(0, y1)) }
    }

    func vertical(_ colors: [RGB], y0: Double, y1: Double, path: CGPath) {
        clipped(path) { linear(gradient(colors), from: pt(0, y0), to: pt(0, y1)) }
    }

    /// Radial gradient; `extend` paints inside the start circle with the
    /// first stop, as the web canvas does.
    func radial(center: CGPoint, r0: Double, r1: Double, stops: [(RGB, Double, Double)], extend: Bool = false) {
        guard let g = gradient(stops) else { return }
        ctx.drawRadialGradient(
            g, startCenter: center, startRadius: CGFloat(r0),
            endCenter: center, endRadius: CGFloat(r1),
            options: extend ? [.drawsBeforeStartLocation] : []
        )
    }

    func circle(_ x: Double, _ y: Double, _ radius: Double) -> CGPath {
        CGPath(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2), transform: nil)
    }

    // MARK: State

    func clipped(_ rect: CGRect, _ body: () -> Void) {
        ctx.saveGState()
        ctx.clip(to: rect)
        body()
        ctx.restoreGState()
    }

    func clipped(_ path: CGPath, _ body: () -> Void) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        body()
        ctx.restoreGState()
    }

    /// Draws `body` into a layer that casts one shadow, so clipped gradients
    /// still throw their shadow outside the clip. `dx`/`dy` use top-left
    /// coordinates (positive dy is down).
    func shadowed(dx: Double, dy: Double, blur: Double, color: RGB = .black, alpha: Double, _ body: () -> Void) {
        ctx.saveGState()
        // Shadow offsets are in the context's base space, where y points up.
        ctx.setShadow(offset: CGSize(width: dx, height: -dy), blur: CGFloat(blur), color: color.cg(alpha))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        body()
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    // MARK: Texture

    /// Film grain over every pixel. Called last so it doesn't shift the
    /// random sequence used for shapes.
    func grain(_ amount: Double) {
        guard let data = ctx.data else { return }
        let bpr = ctx.bytesPerRow
        let rows = ctx.height
        let cols = ctx.width
        let px = data.bindMemory(to: UInt8.self, capacity: bpr * rows)
        for y in 0..<rows {
            var i = y * bpr
            for _ in 0..<cols {
                let n = Int((r() - 0.5) * amount)
                let a = Int(px[i + 3])
                px[i] = UInt8(clamping: min(a, max(0, Int(px[i]) + n)))
                px[i + 1] = UInt8(clamping: min(a, max(0, Int(px[i + 1]) + n)))
                px[i + 2] = UInt8(clamping: min(a, max(0, Int(px[i + 2]) + n)))
                i += 4
            }
        }
    }

    /// 1D midpoint displacement, for ridges and tears.
    func ridge(_ n: Int, _ rough: Double) -> [Double] {
        var a = [Double](repeating: 0, count: n)
        a[0] = r()
        a[n - 1] = r()
        var step = n - 1
        var disp = 1.0
        while step > 1 {
            let half = step / 2
            var i = half
            while i < n - 1 {
                a[i] = (a[i - half] + a[i + half]) / 2 + (r() - 0.5) * disp
                i += step
            }
            step = half
            disp *= rough
        }
        return a
    }

    func drawRidge(_ pts: [Double], base: Double, amp: Double, color: RGB) {
        let path = CGMutablePath()
        path.move(to: pt(0, h))
        for (j, v) in pts.enumerated() {
            path.addLine(to: pt(Double(j) / Double(pts.count - 1) * w, base - v * amp))
        }
        path.addLine(to: pt(w, h))
        path.closeSubpath()
        fill(path, color)
    }
}

enum WallpaperRenderer {
    /// Renders a wallpaper at an exact pixel size. `variant` > 0 gives a remix.
    static func cgImage(_ wall: Wallpaper, width: Int, height: Int, variant: Int = 0) -> CGImage? {
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        // Top-left origin, like the web canvas.
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        let seed = UInt32(truncatingIfNeeded: Int64(wall.seed) + Int64(variant) * 7919)
        let painter = Painter(ctx: ctx, width: Double(width), height: Double(height), rand: Rand(seed: seed))
        Generators.draw(wall.generator, painter, wall.colors)
        return ctx.makeImage()
    }

    static func image(_ wall: Wallpaper, width: Int, height: Int, variant: Int = 0) -> UIImage? {
        cgImage(wall, width: width, height: height, variant: variant).map { UIImage(cgImage: $0) }
    }
}
