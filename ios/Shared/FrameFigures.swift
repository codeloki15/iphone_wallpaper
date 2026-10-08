import SwiftUI

// Line-art figures that play at eight frames a second: isometric drawings
// made with the hairline-create skill (tools/hairline) and true 3D scenes
// made with the ln library (tools/ln). Each is a loop of recorded frames in
// fonts of its own, played by FrameStack (MotionFonts.swift).

struct FrameFigure: Identifiable {
    /// The widget's kind is "Figure" plus this.
    let key: String
    let title: String
    /// One sentence for the widget picker and beside the figure.
    let caption: String
    /// The fonts' shared name, which tools/make_motion_fonts.py prints.
    let prefix: String
    let fps: Int
    /// The part of the 400 x 320 stage the loop actually uses, in the
    /// stage's units. A Lock Screen widget shows just this, as large as fits.
    let bounds: CGRect

    var id: String { key }
}

extension FrameFigure {
    // True 3D scenes, rendered by tools/ln.
    // The globe's bounds are the sphere's: the ends of its axis may be cut off.
    static let globe = FrameFigure(key: "Globe", title: "Globe", caption: "The Earth turning, once every thirty seconds.", prefix: "PWFigGlobe", fps: 8, bounds: box(68, 34, 332, 298))
    static let ripples = FrameFigure(key: "Ripples", title: "Ripples", caption: "Rings spreading across still water.", prefix: "PWFigRipples", fps: 8, bounds: box(37, 104, 363, 246))
    static let sculpture = FrameFigure(key: "Sculpture", title: "Sculpture", caption: "A drilled block turning on the spot.", prefix: "PWFigSculpture", fps: 8, bounds: box(82, 51, 318, 278))
    // Hairline figures, drawn with the hairline-create skill (tools/hairline).
    static let deck = FrameFigure(key: "Deck", title: "Record Deck", caption: "A record turning under its tone arm.", prefix: "PWFigDeck", fps: 8, bounds: box(45, 75, 355, 250))
    static let cradle = FrameFigure(key: "Cradle", title: "Cradle", caption: "A Newton\u{2019}s cradle, clicking once a second.", prefix: "PWFigCradle", fps: 8, bounds: box(73, 50, 327, 278))
    static let lighthouse = FrameFigure(key: "Lighthouse", title: "Lighthouse", caption: "A lighthouse sweeping its beam round every four seconds.", prefix: "PWFigLighthouse", fps: 8, bounds: box(59, 39, 341, 288))
    static let swell = FrameFigure(key: "Swell", title: "Swell", caption: "A wave rolling across a tray of pillars.", prefix: "PWFigSwell", fps: 8, bounds: box(69, 71, 331, 264))

    /// A rectangle from its left, top, right and bottom edges, as
    /// tools/hairline/capture.mjs prints a loop's extent.
    private static func box(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
        CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    static let all: [FrameFigure] = [globe, deck, cradle, lighthouse, ripples, sculpture, swell]

    /// What every frame is painted on: PALETTE.plate in tools/hairline/capture.mjs.
    /// A frame covers only the figure's 5:4 stage, so the view paints the
    /// rest of the widget the same color itself. The widget's container
    /// background won't do for that: iOS gives it a sheen, lighter at the
    /// top, and the stage would show against it as a darker box.
    static let plate = Color(red: 12 / 255, green: 13 / 255, blue: 17 / 255)
    static let muted = Color(red: 0.56, green: 0.58, blue: 0.64)
}

struct FrameFigureView: View {
    let figure: FrameFigure
    let date: Date
    /// A Lock Screen widget: the figure alone, as large as fits.
    var compact = false

    /// True while an always-on display is dimmed. iOS stops running timer
    /// text by the second then (it reads "7:--"), so the figure holds still.
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if compact {
                // The Lock Screen draws a widget by its brightness alone:
                // black is clear and white is its bright material. The
                // frames' plate is not quite black and would show as a
                // faint box. Raising everything by 0.1 and then stretching
                // contrast by 1.52 about the middle sends the plate (0.067
                // at its brightest) to just under zero and makes every
                // stroke brighter than it was: the dimmest goes from 0.26
                // to 0.29 and the silhouettes to nearly white.
                fitted(width: w, height: h)
                    .background(FrameFigure.plate)
                    .brightness(0.1)
                    .contrast(1.52)
            } else if w > h * 1.3 {
                // Medium: the figure as tall as the widget, its name beside it.
                HStack(spacing: 0) {
                    stage(width: h / 0.8)
                    words(titleSize: 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 14)
                }
            } else {
                // Large: the figure across the widget, its name under it.
                VStack(spacing: 0) {
                    stage(width: w)
                    words(titleSize: 19)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 20)
                }
            }
        }
        .background(compact ? Color.clear : FrameFigure.plate)
    }

    /// The figure's stage: 5 wide and 4 tall. The fonts' square is as wide
    /// as the stage and shares its top edge; the rest of the square is empty.
    private func stage(width: CGFloat) -> some View {
        FrameStack(prefix: figure.prefix, fps: figure.fps, date: date, size: width)
            .frame(width: width, height: width * 0.8, alignment: .top)
            .clipped()
    }

    /// For the Lock Screen: the stage enlarged until the part the figure
    /// uses fills the space, with that part in the middle.
    private func fitted(width w: CGFloat, height h: CGFloat) -> some View {
        let used = figure.bounds
        let scale = min((w - 6) / used.width, (h - 6) / used.height)
        let stage = 400 * scale
        return Group {
            if dimmed {
                TimerGlyph(font: MotionFont(name: figure.prefix + "00"), date: date, size: stage, still: "0:01")
            } else {
                FrameStack(prefix: figure.prefix, fps: figure.fps, date: date, size: stage)
            }
        }
        .frame(width: stage, height: stage * 0.8, alignment: .top)
        .offset(x: (200 - used.midX) * scale, y: (160 - used.midY) * scale)
        .frame(width: w, height: h)
        .clipped()
    }

    private func words(titleSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(figure.title)
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(figure.caption)
                .font(.system(size: 11))
                .foregroundStyle(FrameFigure.muted)
                .lineLimit(4)
        }
    }
}
