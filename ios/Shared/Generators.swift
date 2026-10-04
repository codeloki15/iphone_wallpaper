import CoreGraphics
import Foundation

/// Core Graphics ports of the website's wallpaper generators. Sizes are
/// relative to the canvas, so any resolution gives the same composition.
enum Generators {
    static func draw(_ generator: Generator, _ p: Painter, _ c: [RGB]) {
        switch generator {
        case .aurora: aurora(p, c)
        case .linear: linear(p, c)
        case .waves: waves(p, c)
        case .mountains: mountains(p, c)
        case .night: night(p, c)
        case .rings: rings(p, c)
        case .synthwave: synthwave(p, c)
        case .torn: tear(p, c, diagonal: false)
        case .tornDiagonal: tear(p, c, diagonal: true)
        }
    }

    // palette: [background, ...glow colors]
    static func aurora(_ p: Painter, _ c: [RGB]) {
        p.fill(c[0])
        for i in 0..<7 {
            let x = p.r() * p.w
            let y = p.r() * p.h
            let rad = (0.45 + p.r() * 0.5) * p.h * 0.7
            let col = c[1 + i % (c.count - 1)]
            p.radial(center: p.pt(x, y), r0: 0, r1: rad, stops: [(col, 0.85, 0), (col, 0.35, 0.5), (col, 0, 1)])
        }
        p.grain(14)
    }

    static func linear(_ p: Painter, _ c: [RGB]) {
        let a = (p.r() - 0.5) * 0.6
        let len = p.h / 2
        p.linear(
            p.gradient(c),
            from: p.pt(p.w / 2 - sin(a) * len, p.h / 2 - cos(a) * len),
            to: p.pt(p.w / 2 + sin(a) * len, p.h / 2 + cos(a) * len)
        )
        let gx = p.w * (0.2 + p.r() * 0.6)
        let gy = p.h * (0.2 + p.r() * 0.3)
        p.radial(center: p.pt(gx, gy), r0: 0, r1: p.w * 0.9, stops: [(.white, 0.18, 0), (.white, 0, 1)])
        p.grain(10)
    }

    // palette: [skyTop, skyBottom, waveFar, waveNear]
    static func waves(_ p: Painter, _ c: [RGB]) {
        p.vertical([c[0], c[1]], y0: 0, y1: p.h)
        let layers = 7
        for i in 0..<layers {
            let t = Double(i) / Double(layers - 1)
            let base = p.h * (0.38 + t * 0.55)
            let amp = p.h * (0.015 + p.r() * 0.025)
            let f1 = (1 + p.r() * 2) * .pi * 2 / p.w
            let f2 = (2 + p.r() * 3) * .pi * 2 / p.w
            let ph1 = p.r() * .pi * 2
            let ph2 = p.r() * .pi * 2
            let path = CGMutablePath()
            path.move(to: p.pt(0, p.h))
            for s in 0...120 {
                let x = Double(s) / 120 * p.w
                path.addLine(to: p.pt(x, base + sin(x * f1 + ph1) * amp + sin(x * f2 + ph2) * amp * 0.4))
            }
            path.addLine(to: p.pt(p.w, p.h))
            path.closeSubpath()
            p.fill(path, c[2].mix(c[3], t))
        }
        p.grain(8)
    }

    // palette: [skyTop, skyBottom, sun, ridgeFar, ridgeNear]
    static func mountains(_ p: Painter, _ c: [RGB]) {
        p.vertical([c[0], c[1]], y0: 0, y1: p.h * 0.7)
        let sx = p.w * (0.25 + p.r() * 0.5)
        let sy = p.h * (0.3 + p.r() * 0.1)
        let sr = p.w * (0.12 + p.r() * 0.06)
        p.radial(center: p.pt(sx, sy), r0: sr * 0.5, r1: sr * 4, stops: [(c[2], 0.45, 0), (c[2], 0, 1)], extend: true)
        p.fill(p.circle(sx, sy, sr), c[2])
        let ridges = 5
        for i in 0..<ridges {
            let t = Double(i) / Double(ridges - 1)
            p.drawRidge(p.ridge(129, 0.55), base: p.h * (0.42 + t * 0.13), amp: p.h * (0.12 - t * 0.05), color: c[3].mix(c[4], t))
        }
        p.grain(8)
    }

    // palette: [skyTop, skyBottom, moon, hills]
    static func night(_ p: Painter, _ c: [RGB]) {
        let u = p.u
        p.vertical([c[0], c[1]], y0: 0, y1: p.h)
        for _ in 0..<600 {
            let x = p.r() * p.w
            let y = p.r() * p.h * 0.85
            let s = (pow(p.r(), 3) * 2.2 + 0.4) * u * 1.6
            let alpha = 0.3 + p.r() * 0.7
            p.fill(p.circle(x, y, s), .white, alpha: alpha)
        }
        let mx = p.w * (0.2 + p.r() * 0.6)
        let my = p.h * (0.12 + p.r() * 0.18)
        let mr = p.w * (0.07 + p.r() * 0.04)
        p.radial(center: p.pt(mx, my), r0: mr, r1: mr * 5, stops: [(c[2], 0.35, 0), (c[2], 0, 1)], extend: true)
        p.fill(p.circle(mx, my, mr), c[2])
        for _ in 0..<5 {
            let a = p.r() * .pi * 2
            let d = p.r() * mr * 0.6
            let rad = mr * (0.1 + p.r() * 0.15)
            p.fill(p.circle(mx + cos(a) * d, my + sin(a) * d, rad), .black, alpha: 0.07)
        }
        p.drawRidge(p.ridge(65, 0.5), base: p.h * 0.82, amp: p.h * 0.08, color: c[3].mix(c[1], 0.35))
        p.drawRidge(p.ridge(65, 0.5), base: p.h * 0.9, amp: p.h * 0.06, color: c[3])
        p.grain(6)
    }

    // palette: [background, ...ring colors]
    static func rings(_ p: Painter, _ c: [RGB]) {
        p.fill(c[0])
        let cx = p.w * (0.3 + p.r() * 0.4)
        let cy = p.h * (0.55 + p.r() * 0.25)
        let n = c.count - 1
        let count = 8
        for i in stride(from: count, through: 1, by: -1) {
            p.fill(p.circle(cx, cy, p.h * 0.75 * Double(i) / Double(count)), c[1 + i % n])
        }
        p.grain(10)
    }

    // palette: [skyTop, skyBottom, sunTop, sunBottom, grid]
    static func synthwave(_ p: Painter, _ c: [RGB]) {
        let u = p.u
        let w = p.w
        let h = p.h
        let hz = h * 0.6
        let sky = CGRect(x: 0, y: 0, width: w, height: hz)
        p.vertical([c[0], c[1]], y0: 0, y1: hz, in: sky)
        for _ in 0..<150 {
            let s = (0.5 + p.r() * 1.5) * u * 2
            let alpha = 0.2 + p.r() * 0.6
            let x = p.r() * w
            let y = p.r() * hz * 0.7
            p.fill(CGRect(x: x, y: y, width: s, height: s), .white, alpha: alpha)
        }
        let sr = w * 0.32
        let sx = w / 2
        let sy = hz - sr * 0.35
        p.clipped(sky) {
            p.radial(center: p.pt(sx, sy), r0: sr * 0.8, r1: sr * 2.2, stops: [(c[3], 0.5, 0), (c[3], 0, 1)], extend: true)
            p.vertical([c[2], c[3]], y0: sy - sr, y1: sy + sr * 0.35, path: p.circle(sx, sy, sr))
            // Cut stripes into the sun by repainting the sky over them.
            for i in 0..<7 {
                let t = Double(i) / 7
                let stripe = CGRect(x: sx - sr, y: sy - sr * 0.55 + t * sr * 0.9, width: sr * 2, height: sr * (0.015 + t * 0.05))
                p.vertical([c[0], c[1]], y0: 0, y1: hz, in: stripe)
            }
        }
        let ground = CGRect(x: 0, y: hz, width: w, height: h - hz)
        p.vertical([c[0].mix(.black, 0.6), c[0].mix(.black, 0.2)], y0: hz, y1: h, in: ground)
        p.clipped(ground) {
            let path = CGMutablePath()
            for i in -14...14 {
                path.move(to: p.pt(w / 2 + Double(i) * w * 0.04, hz))
                path.addLine(to: p.pt(w / 2 + Double(i) * w * 0.32, h))
            }
            for k in 1...14 {
                let y = hz + (h - hz) * pow(Double(k) / 14, 2.2)
                path.move(to: p.pt(0, y))
                path.addLine(to: p.pt(w, y))
            }
            p.ctx.setShadow(offset: .zero, blur: CGFloat(14 * u), color: c[4].cg())
            p.ctx.addPath(path)
            p.ctx.setStrokeColor(c[4].cg())
            p.ctx.setLineWidth(CGFloat(2.5 * u))
            p.ctx.strokePath()
        }
        p.fill(CGRect(x: 0, y: hz - 1.5 * u, width: w, height: 3 * u), c[3])
        p.grain(8)
    }

    /// One sheet torn away to reveal another. Points run along the tear and
    /// are pushed sideways by noise; `nl` points toward the revealed sheet.
    /// palette: [torn sheet, revealed sheet, paper core]
    static func tear(_ p: Painter, _ c: [RGB], diagonal: Bool) {
        let w = p.w
        let h = p.h
        let u = p.u
        let n = 257
        let coarse = p.ridge(n, 0.62)
        let fine = p.ridge(n, 0.85)
        let fiber = p.ridge(n, 0.9)
        let a: (Double, Double)
        let b: (Double, Double)
        let amp: Double
        if diagonal {
            a = (-w * 0.06, h * (0.7 + p.r() * 0.06))
            b = (w * 1.06, h * (0.3 + p.r() * 0.06))
            amp = h * 0.06
        } else {
            let edgeX = w * (0.5 + (p.r() - 0.5) * 0.08)
            a = (edgeX, -h * 0.02)
            b = (edgeX, h * 1.02)
            amp = w * 0.3
        }
        let len = hypot(b.0 - a.0, b.1 - a.1)
        let dx = (b.0 - a.0) / len
        let dy = (b.1 - a.1) / len
        let nl: (Double, Double) = diagonal ? (-dy, dx) : (dy, -dx)
        var pts: [(Double, Double)] = []
        for i in 0..<n {
            let t = Double(i) / Double(n - 1)
            let off = (coarse[i] - 0.5) * amp + (fine[i] - 0.5) * w * 0.035
            pts.append((a.0 + (b.0 - a.0) * t + nl.0 * off, a.1 + (b.1 - a.1) * t + nl.1 * off))
        }
        // The exposed core is widest where the tear wanders furthest.
        var core: [(Double, Double)] = []
        for i in 0..<n {
            let k = w * (0.016 + abs(fiber[i] - 0.5) * 0.07)
            core.append((pts[i].0 + nl.0 * k, pts[i].1 + nl.1 * k))
        }

        p.vertical([c[1].mix(.white, 0.1), c[1].mix(.black, 0.06)], y0: 0, y1: h)

        let strip = CGMutablePath()
        strip.move(to: p.pt(pts[0].0, pts[0].1))
        for q in pts.dropFirst() { strip.addLine(to: p.pt(q.0, q.1)) }
        for q in core.reversed() { strip.addLine(to: p.pt(q.0, q.1)) }
        strip.closeSubpath()
        p.shadowed(dx: nl.0 * 12 * u, dy: nl.1 * 12 * u, blur: 36 * u, alpha: 0.32) {
            p.vertical([c[2], c[2].mix(c[1], 0.25)], y0: 0, y1: h, path: strip)
        }

        // Torn fibres: short strands across the core.
        p.clipped(strip) {
            p.ctx.setLineCap(.round)
            for _ in 0..<520 {
                let k = Int(p.r() * Double(n - 1))
                let t = p.r()
                let x = pts[k].0 + (core[k].0 - pts[k].0) * t
                let y = pts[k].1 + (core[k].1 - pts[k].1) * t
                if p.r() < 0.5 {
                    p.ctx.setStrokeColor(RGB.white.cg(0.5))
                } else {
                    p.ctx.setStrokeColor(RGB.black.cg(0.05 + p.r() * 0.06))
                }
                p.ctx.setLineWidth(CGFloat((0.6 + p.r() * 1.4) * u))
                let sx = (p.r() - 0.3) * 18 * u
                let sy = (p.r() - 0.5) * 10 * u
                p.ctx.move(to: p.pt(x, y))
                p.ctx.addLine(to: p.pt(x + nl.0 * sx - nl.1 * sy, y + nl.1 * sx + nl.0 * sy))
                p.ctx.strokePath()
            }
        }

        // The torn sheet on top, with a slight lip of shadow along its edge.
        let sheet = CGMutablePath()
        sheet.move(to: p.pt(pts[0].0, pts[0].1))
        for q in pts.dropFirst() { sheet.addLine(to: p.pt(q.0, q.1)) }
        let corners: [(Double, Double)] = diagonal
            ? [(w * 1.1, -h * 0.1), (-w * 0.1, -h * 0.1)]
            : [(-w * 0.1, h * 1.05), (-w * 0.1, -h * 0.05)]
        for q in corners { sheet.addLine(to: p.pt(q.0, q.1)) }
        sheet.closeSubpath()
        p.shadowed(dx: nl.0 * 3 * u, dy: nl.1 * 3 * u, blur: 10 * u, alpha: 0.28) {
            p.vertical([c[0].mix(.white, 0.06), c[0].mix(.black, 0.12)], y0: 0, y1: h, path: sheet)
        }
        let mx = (a.0 + b.0) / 2
        let my = (a.1 + b.1) / 2
        p.clipped(sheet) {
            p.linear(
                p.gradient([(.black, 0, 0), (.black, 0.12, 1)]),
                from: p.pt(mx - nl.0 * w * 0.25, my - nl.1 * w * 0.25),
                to: p.pt(mx + nl.0 * w * 0.05, my + nl.1 * w * 0.05)
            )
        }
        p.grain(12)
    }
}
