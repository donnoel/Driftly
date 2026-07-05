import SwiftUI

struct GlassTidesView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let time = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    render(in: context, size: size, time: time)
                }
                .ignoresSafeArea()
            }
        }
    }

    private func render(in context: GraphicsContext, size: CGSize, time: Double) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ]),
                startPoint: CGPoint(x: size.width * 0.5, y: 0),
                endPoint: CGPoint(x: size.width * 0.5, y: size.height)
            )
        )

        drawBaseGlow(in: context, rect: rect, size: size, time: time)

        var glassLayer = context
        glassLayer.blendMode = .plusLighter
        drawTidalSheets(in: &glassLayer, size: size, time: time)
        drawInnerCaustics(in: &glassLayer, size: size, time: time)
        drawSpecularRidges(in: &glassLayer, size: size, time: time)

        drawVignette(in: context, size: size)
    }

    private func drawBaseGlow(in context: GraphicsContext, rect: CGRect, size: CGSize, time: Double) {
        let center = CGPoint(
            x: size.width * (0.50 + 0.05 * CGFloat(sin(time * 0.030))),
            y: size.height * (0.48 + 0.04 * CGFloat(cos(time * 0.026)))
        )

        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.primary.opacity(0.20),
                    config.palette.secondary.opacity(0.12),
                    Color.clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.90
            )
        )
    }

    private func drawTidalSheets(in context: inout GraphicsContext, size: CGSize, time: Double) {
        for index in 0..<6 {
            let path = tidalSheetPath(index: index, size: size, time: time)
            let color = tideColor(index: index)
            let opacity = 0.12 + 0.04 * CGFloat(0.5 + 0.5 * sin(time * 0.10 + Double(index)))

            context.fill(path, with: .color(color.opacity(opacity)))
            context.stroke(path, with: .color(Color.white.opacity(0.035)), lineWidth: sheetEdgeWidth(for: size, index: index))
            context.stroke(path, with: .color(color.opacity(0.10)), lineWidth: sheetEdgeWidth(for: size, index: index) * 3.0)
        }
    }

    private func tidalSheetPath(index: Int, size: CGSize, time: Double) -> Path {
        let base = min(size.width, size.height)
        let width = size.width * CGFloat(0.58 + 0.08 * Double(index % 3))
        let height = base * CGFloat(0.30 + 0.04 * Double(index % 2))
        let phase = Double(index) * 1.37
        let center = CGPoint(
            x: size.width * CGFloat(0.26 + 0.10 * Double(index))
                + base * CGFloat(0.07 * sin(time * 0.045 + phase)),
            y: size.height * CGFloat(0.24 + 0.105 * Double(index))
                + base * CGFloat(0.05 * cos(time * 0.038 + phase * 1.3))
        )
        let rotation = CGFloat(-0.22 + 0.085 * Double(index)) + CGFloat(0.035 * sin(time * 0.030 + phase))

        var path = Path()
        path.move(to: CGPoint(x: -width * 0.50, y: -height * 0.12))
        path.addCurve(
            to: CGPoint(x: width * 0.38, y: -height * 0.44),
            control1: CGPoint(x: -width * 0.22, y: -height * 0.50),
            control2: CGPoint(x: width * 0.15, y: -height * 0.47)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.53, y: height * 0.08),
            control1: CGPoint(x: width * 0.56, y: -height * 0.32),
            control2: CGPoint(x: width * 0.62, y: -height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: -width * 0.34, y: height * 0.43),
            control1: CGPoint(x: width * 0.35, y: height * 0.38),
            control2: CGPoint(x: -width * 0.10, y: height * 0.48)
        )
        path.addCurve(
            to: CGPoint(x: -width * 0.50, y: -height * 0.12),
            control1: CGPoint(x: -width * 0.62, y: height * 0.28),
            control2: CGPoint(x: -width * 0.68, y: height * 0.02)
        )

        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: rotation)
        return path.applying(transform)
    }

    private func drawInnerCaustics(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let count = min(34, max(18, Int(size.width / 30)))

        for index in 0..<count {
            let phase = Double(index) * 0.53
            let p = Double(index) / Double(max(1, count - 1))
            let y = size.height * CGFloat(0.16 + 0.70 * p)
            let drift = size.width * CGFloat(0.06 * sin(time * 0.045 + phase))
            var path = Path()

            for step in 0...64 {
                let u = Double(step) / 64.0
                let x = size.width * CGFloat(u) + drift
                let wave = CGFloat(
                    14.0 * sin(u * Double.pi * 2.0 + time * 0.15 + phase) +
                    8.0 * cos(u * Double.pi * 4.0 - time * 0.09 + phase)
                )
                let point = CGPoint(x: x, y: y + wave)

                if step == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            let color = index % 2 == 0 ? config.palette.tertiary : config.palette.primary
            context.stroke(path, with: .color(color.opacity(0.040)), lineWidth: 6.0)
            context.stroke(path, with: .color(Color.white.opacity(0.055)), lineWidth: 1.0)
        }
    }

    private func drawSpecularRidges(in context: inout GraphicsContext, size: CGSize, time: Double) {
        for index in 0..<5 {
            let phase = Double(index) * 1.11
            let y = size.height * CGFloat(0.20 + 0.14 * Double(index))
                + CGFloat(18.0 * sin(time * 0.040 + phase))
            let start = CGPoint(x: -size.width * 0.10, y: y)
            let end = CGPoint(x: size.width * 1.10, y: y + CGFloat(26.0 * cos(time * 0.035 + phase)))
            var ridge = Path()
            ridge.move(to: start)
            ridge.addCurve(
                to: end,
                control1: CGPoint(x: size.width * 0.25, y: y - 38),
                control2: CGPoint(x: size.width * 0.70, y: y + 42)
            )

            let pulse = 0.5 + 0.5 * sin(time * 0.18 + phase)
            context.stroke(ridge, with: .color(Color.white.opacity(0.035 + 0.035 * pulse)), lineWidth: 2.0)
            context.stroke(ridge, with: .color(config.palette.tertiary.opacity(0.035)), lineWidth: 7.0)
        }
    }

    private func drawVignette(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.30)
                ]),
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.55),
                startRadius: min(size.width, size.height) * 0.22,
                endRadius: max(size.width, size.height) * 0.78
            )
        )
    }

    private func tideColor(index: Int) -> Color {
        switch index % 3 {
        case 0: return config.palette.primary
        case 1: return config.palette.secondary
        default: return config.palette.tertiary
        }
    }

    private func sheetEdgeWidth(for size: CGSize, index: Int) -> CGFloat {
        min(size.width, size.height) * CGFloat(0.0025 + 0.0005 * Double(index % 2))
    }
}
