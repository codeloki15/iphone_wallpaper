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

    var id: String { key }
}

extension FrameFigure {
    // True 3D scenes, rendered by tools/ln.
    static let globe = FrameFigure(key: "Globe", title: "Globe", caption: "The Earth turning, once every thirty seconds.", prefix: "PWFigGlobe", fps: 8)
    static let ripples = FrameFigure(key: "Ripples", title: "Ripples", caption: "Rings spreading across still water.", prefix: "PWFigRipples", fps: 8)
    static let sculpture = FrameFigure(key: "Sculpture", title: "Sculpture", caption: "A drilled block turning on the spot.", prefix: "PWFigSculpture", fps: 8)
    // Hairline figures, drawn with the hairline-create skill (tools/hairline).
    static let swell = FrameFigure(key: "Swell", title: "Swell", caption: "A wave rolling across a tray of pillars.", prefix: "PWFigSwell", fps: 8)

    static let all: [FrameFigure] = [globe, ripples, sculpture, swell]

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

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > h * 1.3 {
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
        .background(FrameFigure.plate)
    }

    /// The figure's stage: 5 wide and 4 tall. The fonts' square is as wide
    /// as the stage and shares its top edge; the rest of the square is empty.
    private func stage(width: CGFloat) -> some View {
        FrameStack(prefix: figure.prefix, fps: figure.fps, date: date, size: width)
            .frame(width: width, height: width * 0.8, alignment: .top)
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
