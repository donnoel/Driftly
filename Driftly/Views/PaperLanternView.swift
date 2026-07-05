import SwiftUI

struct PaperLanternView: View {
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

        drawEveningHaze(in: context, rect: rect, size: size, time: time)

        var lanternLayer = context
        lanternLayer.blendMode = .plusLighter
        drawLanterns(in: &lanternLayer, size: size, time: time)
        drawSoftMotes(in: &lanternLayer, size: size, time: time)

        drawDuskVignette(in: context, size: size)
    }

    private func drawEveningHaze(in context: GraphicsContext, rect: CGRect, size: CGSize, time: Double) {
        let center = CGPoint(
            x: size.width * (0.48 + 0.04 * CGFloat(sin(time * 0.020))),
            y: size.height * (0.56 + 0.03 * CGFloat(cos(time * 0.017)))
        )

        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.tertiary.opacity(0.15),
                    config.palette.secondary.opacity(0.08),
                    Color.clear
                ]),
                center: center,
                startRadius: min(size.width, size.height) * 0.04,
                endRadius: max(size.width, size.height) * 0.92
            )
        )
    }

    private func drawLanterns(in context: inout GraphicsContext, size: CGSize, time: Double) {
        for index in 0..<15 {
            let lantern = lanternShape(index: index, size: size, time: time)
            drawGlow(for: lantern, in: &context)
            drawBody(for: lantern, in: &context)
        }
    }

    private func lanternShape(index: Int, size: CGSize, time: Double) -> LanternShape {
        let seed = 2100 + index * 23
        let depth = CGFloat(0.42 + 0.58 * DriftNoise.hash(index, 3, seed: seed))
        let phase = Double(index) * 0.41 + DriftNoise.hash(index, 5, seed: seed) * 2.0
        let driftSpeed = 0.010 + 0.010 * Double(depth)
        let progress = (time * driftSpeed + phase).truncatingRemainder(dividingBy: 1.24)
        let base = min(size.width, size.height)
        let lanternSize = base * CGFloat(0.034 + 0.048 * Double(depth))
        let lane = CGFloat(DriftNoise.hash(index, 7, seed: seed))
        let x = size.width * (0.08 + lane * 0.84)
            + base * CGFloat(0.045 * sin(time * (0.025 + 0.006 * Double(depth)) + phase))
        let y = size.height * CGFloat(1.08 - progress)
            + base * CGFloat(0.035 * cos(time * 0.022 + phase * 1.4))
        let pulse = 0.5 + 0.5 * sin(time * 0.20 + phase)
        let opacity = 0.22 + 0.34 * depth
        let bodyRect = CGRect(
            x: x - lanternSize * 0.46,
            y: y - lanternSize * 0.58,
            width: lanternSize * 0.92,
            height: lanternSize * 1.16
        )

        return LanternShape(
            center: CGPoint(x: x, y: y),
            bodyRect: bodyRect,
            glowRadius: lanternSize * CGFloat(2.1 + 1.1 * pulse),
            ribWidth: max(0.7, lanternSize * 0.035),
            opacity: opacity,
            pulse: CGFloat(pulse),
            depth: depth
        )
    }

    private func drawGlow(for lantern: LanternShape, in context: inout GraphicsContext) {
        context.fill(
            Path(ellipseIn: CGRect(
                x: lantern.center.x - lantern.glowRadius,
                y: lantern.center.y - lantern.glowRadius,
                width: lantern.glowRadius * 2,
                height: lantern.glowRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.primary.opacity(0.20 * lantern.opacity),
                    config.palette.secondary.opacity(0.10 * lantern.opacity),
                    Color.clear
                ]),
                center: lantern.center,
                startRadius: 0,
                endRadius: lantern.glowRadius
            )
        )
    }

    private func drawBody(for lantern: LanternShape, in context: inout GraphicsContext) {
        let body = Path(roundedRect: lantern.bodyRect, cornerRadius: lantern.bodyRect.width * 0.42)
        let capHeight = lantern.bodyRect.height * 0.10
        let topCap = CGRect(
            x: lantern.bodyRect.minX + lantern.bodyRect.width * 0.18,
            y: lantern.bodyRect.minY - capHeight * 0.22,
            width: lantern.bodyRect.width * 0.64,
            height: capHeight
        )
        let bottomCap = topCap.offsetBy(dx: 0, dy: lantern.bodyRect.height + capHeight * 0.44)

        context.fill(
            body,
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.18 * lantern.opacity),
                    config.palette.primary.opacity((0.42 + 0.12 * lantern.pulse) * lantern.opacity),
                    config.palette.secondary.opacity(0.20 * lantern.opacity)
                ]),
                center: CGPoint(x: lantern.bodyRect.midX, y: lantern.bodyRect.midY),
                startRadius: 0,
                endRadius: lantern.bodyRect.height * 0.70
            )
        )

        context.stroke(body, with: .color(Color.white.opacity(0.050 * lantern.opacity)), lineWidth: lantern.ribWidth)
        context.stroke(Path(roundedRect: topCap, cornerRadius: capHeight * 0.50), with: .color(config.palette.primary.opacity(0.16 * lantern.opacity)), lineWidth: lantern.ribWidth)
        context.stroke(Path(roundedRect: bottomCap, cornerRadius: capHeight * 0.50), with: .color(config.palette.primary.opacity(0.13 * lantern.opacity)), lineWidth: lantern.ribWidth)

        for rib in 1...3 {
            let x = lantern.bodyRect.minX + lantern.bodyRect.width * CGFloat(rib) / 4.0
            var path = Path()
            path.move(to: CGPoint(x: x, y: lantern.bodyRect.minY + lantern.bodyRect.height * 0.10))
            path.addCurve(
                to: CGPoint(x: x, y: lantern.bodyRect.maxY - lantern.bodyRect.height * 0.10),
                control1: CGPoint(x: x + lantern.bodyRect.width * 0.08, y: lantern.bodyRect.midY - lantern.bodyRect.height * 0.16),
                control2: CGPoint(x: x - lantern.bodyRect.width * 0.08, y: lantern.bodyRect.midY + lantern.bodyRect.height * 0.16)
            )
            context.stroke(path, with: .color(Color.white.opacity(0.030 * lantern.opacity)), lineWidth: lantern.ribWidth * 0.65)
        }
    }

    private func drawSoftMotes(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let count = min(44, max(18, Int(size.width / 18)))

        for index in 0..<count {
            let seed = 2500 + index * 13
            let phase = Double(index) * 0.73
            let x = size.width * CGFloat(DriftNoise.hash(index, 5, seed: seed))
                + CGFloat(14.0 * sin(time * 0.020 + phase))
            let rawY = (time * 0.010 + phase).truncatingRemainder(dividingBy: 1.18)
            let y = size.height * CGFloat(1.08 - rawY)
            let pulse = max(0.0, sin(time * 0.18 + phase))
            let radius = CGFloat(1.0 + 4.0 * pulse * DriftNoise.hash(index, 9, seed: seed))

            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [
                        config.palette.primary.opacity(0.08 * pulse),
                        Color.clear
                    ]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: max(1, radius)
                )
            )
        }
    }

    private func drawDuskVignette(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.36)
                ]),
                center: CGPoint(x: size.width * 0.50, y: size.height * 0.52),
                startRadius: min(size.width, size.height) * 0.18,
                endRadius: max(size.width, size.height) * 0.82
            )
        )
    }
}

private struct LanternShape {
    let center: CGPoint
    let bodyRect: CGRect
    let glowRadius: CGFloat
    let ribWidth: CGFloat
    let opacity: CGFloat
    let pulse: CGFloat
    let depth: CGFloat
}
