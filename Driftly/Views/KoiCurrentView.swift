import SwiftUI

struct KoiCurrentView: View {
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
                startPoint: CGPoint(x: size.width * 0.50, y: 0),
                endPoint: CGPoint(x: size.width * 0.50, y: size.height)
            )
        )

        drawWaterWash(in: context, rect: rect, size: size, time: time)

        var currentLayer = context
        currentLayer.blendMode = .plusLighter
        drawCurrentBands(in: &currentLayer, size: size, time: time)
        drawKoiStrokes(in: &currentLayer, size: size, time: time)
        drawSurfaceGlints(in: &currentLayer, size: size, time: time)

        drawDepthVignette(in: context, size: size)
    }

    private func drawWaterWash(in context: GraphicsContext, rect: CGRect, size: CGSize, time: Double) {
        let glowCenter = CGPoint(
            x: size.width * (0.48 + 0.07 * CGFloat(sin(time * 0.026))),
            y: size.height * (0.46 + 0.05 * CGFloat(cos(time * 0.022)))
        )

        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.secondary.opacity(0.16),
                    config.palette.primary.opacity(0.07),
                    Color.clear
                ]),
                center: glowCenter,
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.88
            )
        )
    }

    private func drawCurrentBands(in context: inout GraphicsContext, size: CGSize, time: Double) {
        for index in 0..<9 {
            let phase = Double(index) * 0.72
            let y = size.height * CGFloat(0.12 + 0.095 * Double(index))
            let drift = size.width * CGFloat(0.08 * sin(time * 0.035 + phase))
            var path = Path()

            for step in 0...72 {
                let u = Double(step) / 72.0
                let x = size.width * CGFloat(u) + drift
                let wave = CGFloat(
                    20.0 * sin(u * Double.pi * 2.0 + time * 0.11 + phase) +
                    9.0 * cos(u * Double.pi * 4.0 - time * 0.075 + phase)
                )
                let point = CGPoint(x: x, y: y + wave)

                if step == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            let color = index % 2 == 0 ? config.palette.secondary : config.palette.tertiary
            context.stroke(path, with: .color(color.opacity(0.035)), lineWidth: 10)
            context.stroke(path, with: .color(Color.white.opacity(0.025)), lineWidth: 1.2)
        }
    }

    private func drawKoiStrokes(in context: inout GraphicsContext, size: CGSize, time: Double) {
        for index in 0..<7 {
            let stroke = koiStroke(index: index, size: size, time: time)
            let color = index % 3 == 0 ? config.palette.primary : (index % 3 == 1 ? config.palette.tertiary : config.palette.secondary)
            let pulse = 0.5 + 0.5 * sin(time * 0.16 + Double(index) * 0.8)

            context.stroke(stroke.body, with: .color(color.opacity(0.09 + 0.03 * pulse)), lineWidth: stroke.width * 2.8)
            context.stroke(stroke.body, with: .color(color.opacity(0.20 + 0.06 * pulse)), lineWidth: stroke.width)
            context.stroke(stroke.body, with: .color(Color.white.opacity(0.08)), lineWidth: max(0.8, stroke.width * 0.28))
            context.fill(stroke.head, with: .color(color.opacity(0.20 + 0.06 * pulse)))
            context.fill(stroke.glow, with: .radialGradient(
                Gradient(colors: [
                    color.opacity(0.13 + 0.05 * pulse),
                    Color.clear
                ]),
                center: stroke.center,
                startRadius: 0,
                endRadius: stroke.glowRadius
            ))
        }
    }

    private func koiStroke(index: Int, size: CGSize, time: Double) -> KoiStroke {
        let base = min(size.width, size.height)
        let phase = Double(index) * 1.19
        let lap = time * (0.030 + 0.003 * Double(index % 3)) + phase
        let center = CGPoint(
            x: size.width * CGFloat(0.18 + 0.11 * Double(index))
                + base * CGFloat(0.12 * sin(lap)),
            y: size.height * CGFloat(0.20 + 0.095 * Double(index))
                + base * CGFloat(0.10 * cos(lap * 0.86))
        )
        let length = base * CGFloat(0.24 + 0.025 * Double(index % 2))
        let width = max(2.4, base * CGFloat(0.010 + 0.002 * Double(index % 3)))
        let angle = CGFloat(-0.55 + 0.16 * Double(index)) + CGFloat(0.18 * sin(lap * 0.72))

        var body = Path()
        body.move(to: CGPoint(x: -length * 0.50, y: 0))
        body.addCurve(
            to: CGPoint(x: length * 0.45, y: 0),
            control1: CGPoint(x: -length * 0.22, y: -length * 0.18),
            control2: CGPoint(x: length * 0.18, y: length * 0.16)
        )

        let headRect = CGRect(
            x: length * 0.34,
            y: -width * 1.8,
            width: width * 4.8,
            height: width * 3.6
        )
        let glowRect = CGRect(
            x: -length * 0.55,
            y: -length * 0.26,
            width: length * 1.16,
            height: length * 0.52
        )

        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: angle)
        let transformedBody = body.applying(transform)
        let transformedHead = Path(ellipseIn: headRect).applying(transform)
        let transformedGlow = Path(ellipseIn: glowRect).applying(transform)

        return KoiStroke(
            body: transformedBody,
            head: transformedHead,
            glow: transformedGlow,
            center: center,
            width: width,
            glowRadius: length * 0.58
        )
    }

    private func drawSurfaceGlints(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let count = min(42, max(20, Int(size.width / 18)))

        for index in 0..<count {
            let phase = Double(index) * 0.61
            let x = size.width * CGFloat(DriftNoise.hash(index, 3, seed: 430))
                + CGFloat(18.0 * sin(time * 0.05 + phase))
            let y = size.height * CGFloat(DriftNoise.hash(index, 7, seed: 430))
                + CGFloat(14.0 * cos(time * 0.04 + phase))
            let pulse = max(0.0, sin(time * 0.45 + phase))
            let radius = CGFloat(1.6 + 5.0 * pulse * DriftNoise.hash(index, 11, seed: 430))

            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.13 * pulse),
                        config.palette.tertiary.opacity(0.08 * pulse),
                        Color.clear
                    ]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: max(radius, 1)
                )
            )
        }
    }

    private func drawDepthVignette(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.32)
                ]),
                center: CGPoint(x: size.width * 0.50, y: size.height * 0.55),
                startRadius: min(size.width, size.height) * 0.20,
                endRadius: max(size.width, size.height) * 0.78
            )
        )
    }
}

private struct KoiStroke {
    let body: Path
    let head: Path
    let glow: Path
    let center: CGPoint
    let width: CGFloat
    let glowRadius: CGFloat
}
