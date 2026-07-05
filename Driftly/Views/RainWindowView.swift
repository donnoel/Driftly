import SwiftUI

struct RainWindowView: View {
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

        drawDistantWindowGlow(in: context, rect: rect, size: size, time: time)

        var rainLayer = context
        rainLayer.blendMode = .plusLighter
        drawRefractedTrails(in: &rainLayer, size: size, time: time)
        drawDroplets(in: &rainLayer, size: size, time: time)
        drawMergingDroplets(in: &rainLayer, size: size, time: time)

        drawSoftGlassVignette(in: context, size: size)
    }

    private func drawDistantWindowGlow(in context: GraphicsContext, rect: CGRect, size: CGSize, time: Double) {
        let glowCenter = CGPoint(
            x: size.width * (0.60 + 0.04 * CGFloat(sin(time * 0.020))),
            y: size.height * (0.34 + 0.03 * CGFloat(cos(time * 0.018)))
        )

        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.tertiary.opacity(0.18),
                    config.palette.primary.opacity(0.09),
                    Color.clear
                ]),
                center: glowCenter,
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.82
            )
        )
    }

    private func drawRefractedTrails(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let count = min(30, max(14, Int(size.width / 20)))

        for index in 0..<count {
            let seed = 900 + index * 17
            let xBase = size.width * CGFloat(DriftNoise.hash(index, 3, seed: seed))
            let laneDrift = CGFloat(8.0 * sin(time * 0.045 + Double(index) * 0.71))
            let yStart = -size.height * 0.08
            let height = size.height * CGFloat(0.36 + 0.42 * DriftNoise.hash(index, 7, seed: seed))
            let scroll = CGFloat((time * (0.012 + 0.004 * Double(index % 3)) + Double(index) * 0.13).truncatingRemainder(dividingBy: 1.28))
            let y = size.height * (scroll - 0.16)
            let width = CGFloat(0.8 + 2.4 * DriftNoise.hash(index, 11, seed: seed))
            let opacity = 0.035 + 0.045 * CGFloat(DriftNoise.hash(index, 13, seed: seed))

            var trail = Path()
            trail.move(to: CGPoint(x: xBase + laneDrift, y: yStart + y))
            trail.addCurve(
                to: CGPoint(x: xBase - laneDrift * 0.4, y: yStart + y + height),
                control1: CGPoint(x: xBase + 12 + laneDrift, y: yStart + y + height * 0.28),
                control2: CGPoint(x: xBase - 10 - laneDrift, y: yStart + y + height * 0.68)
            )

            let color = index % 5 == 0 ? config.palette.tertiary : config.palette.primary
            context.stroke(trail, with: .color(color.opacity(opacity)), lineWidth: width * 2.4)
            context.stroke(trail, with: .color(Color.white.opacity(opacity * 0.75)), lineWidth: max(0.5, width * 0.55))
        }
    }

    private func drawDroplets(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let count = min(74, max(36, Int(size.width / 7)))

        for index in 0..<count {
            let seed = 1400 + index * 19
            let phase = Double(index) * 0.37
            let x = size.width * CGFloat(DriftNoise.hash(index, 5, seed: seed))
                + CGFloat(5.0 * sin(time * 0.035 + phase))
            let rawY = (time * (0.018 + 0.006 * DriftNoise.hash(index, 9, seed: seed)) + phase).truncatingRemainder(dividingBy: 1.22)
            let y = size.height * CGFloat(rawY - 0.11)
            let baseRadius = min(size.width, size.height) * CGFloat(0.004 + 0.010 * DriftNoise.hash(index, 15, seed: seed))
            let stretch = CGFloat(1.0 + 1.6 * max(0.0, sin(time * 0.20 + phase)))
            let dropletRect = CGRect(
                x: x - baseRadius,
                y: y - baseRadius * 0.8,
                width: baseRadius * 2,
                height: baseRadius * (2.0 + stretch)
            )
            let pulse = 0.5 + 0.5 * sin(time * 0.12 + phase)

            context.fill(
                Path(ellipseIn: dropletRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.11 + 0.05 * pulse),
                        config.palette.primary.opacity(0.08),
                        Color.clear
                    ]),
                    center: CGPoint(x: x - baseRadius * 0.25, y: y - baseRadius * 0.25),
                    startRadius: 0,
                    endRadius: baseRadius * 2.8
                )
            )
            context.stroke(
                Path(ellipseIn: dropletRect),
                with: .color(Color.white.opacity(0.035 + 0.025 * pulse)),
                lineWidth: max(0.4, baseRadius * 0.18)
            )
        }
    }

    private func drawMergingDroplets(in context: inout GraphicsContext, size: CGSize, time: Double) {
        for index in 0..<6 {
            let phase = Double(index) * 1.23
            let progress = 0.5 + 0.5 * sin(time * 0.080 + phase)
            let x = size.width * CGFloat(0.18 + 0.13 * Double(index))
                + CGFloat(10.0 * sin(time * 0.030 + phase))
            let y = size.height * CGFloat(0.16 + 0.12 * Double(index))
                + size.height * CGFloat(0.08 * progress)
            let radius = min(size.width, size.height) * CGFloat(0.014 + 0.004 * Double(index % 2))
            let gap = radius * CGFloat(0.85 - 0.60 * progress)
            let top = CGRect(x: x - radius, y: y - radius - gap, width: radius * 2, height: radius * 2.6)
            let lower = CGRect(x: x - radius * 0.84, y: y + gap * 0.2, width: radius * 1.68, height: radius * 2.35)
            let bridge = CGRect(x: x - radius * 0.42, y: top.midY, width: radius * 0.84, height: max(1, lower.midY - top.midY))

            let opacity = 0.10 + 0.06 * progress
            context.fill(Path(ellipseIn: top), with: .color(config.palette.primary.opacity(opacity)))
            context.fill(Path(ellipseIn: lower), with: .color(config.palette.primary.opacity(opacity * 0.85)))
            context.fill(Path(roundedRect: bridge, cornerRadius: radius * 0.42), with: .color(config.palette.primary.opacity(opacity * 0.55)))
            context.stroke(Path(ellipseIn: top), with: .color(Color.white.opacity(0.045 + 0.025 * progress)), lineWidth: 0.8)
            context.stroke(Path(ellipseIn: lower), with: .color(Color.white.opacity(0.040 + 0.020 * progress)), lineWidth: 0.8)
        }
    }

    private func drawSoftGlassVignette(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.34)
                ]),
                center: CGPoint(x: size.width * 0.52, y: size.height * 0.50),
                startRadius: min(size.width, size.height) * 0.24,
                endRadius: max(size.width, size.height) * 0.80
            )
        )
    }
}
