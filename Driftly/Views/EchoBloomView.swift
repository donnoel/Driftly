import SwiftUI

struct EchoBloomView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PausableTimelineView(paused: animationsPaused || reduceMotion) { date in
            let time = date.timeIntervalSinceReferenceDate * max(0.25, speed)
            Canvas { context, size in
                let bounds = Path(CGRect(origin: .zero, size: size))
                context.fill(bounds, with: .linearGradient(
                    Gradient(colors: [config.palette.backgroundTop, Color(red: 0.065, green: 0.022, blue: 0.065),
                                      config.palette.backgroundBottom]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
                ))
                // Smaller, distant blossoms sit behind the fuller central bloom.
                for index in [0, 3, 1, 4, 2] {
                    drawBlossom(index: index, in: context, size: size, time: time)
                }
                context.fill(bounds, with: .radialGradient(
                    Gradient(colors: [.clear, .black.opacity(0.27)]),
                    center: CGPoint(x: size.width * 0.5, y: size.height * 0.48),
                    startRadius: min(size.width, size.height) * 0.28,
                    endRadius: max(size.width, size.height) * 0.82
                ))
            }
            .blur(radius: 0.45)
            .ignoresSafeArea()
        }
    }

    private func drawBlossom(index: Int, in context: GraphicsContext, size: CGSize, time: Double) {
        let base = min(size.width, size.height)
        let phase = Double(index) * 1.83
        let radius = base * Self.sizes[index]
        let margin = radius * 1.15
        let seed = Self.positions[index]
        let center = CGPoint(
            x: margin + (size.width - margin * 2) * (seed.x + 0.045 * sin(time * 0.027 + phase)),
            y: margin + (size.height - margin * 2) * (seed.y + 0.045 * sin(time * 0.023 + phase * 1.4))
        )
        let opening = 0.5 + 0.5 * sin(time * 0.065 + phase)
        var flower = context
        flower.translateBy(x: center.x, y: center.y)
        flower.rotate(by: .radians(phase * 0.58 + 0.16 * sin(time * 0.025 + phase)))
        flower.scaleBy(x: 1, y: 0.76 + 0.12 * sin(phase + 0.6))
        flower.opacity = index == 2 ? 1.0 : (index.isMultiple(of: 3) ? 0.60 : 0.82)
        flower.blendMode = .screen
        let colorPhase = Double(index) * 0.86 + time * 0.013

        for ring in 0..<3 {
            let petals = 9 - ring * 2
            let layerScale = 1 - Double(ring) * 0.25
            for petal in 0..<petals {
                let petalPhase = phase + Double(petal) * 0.71 + Double(ring)
                let spread = opening * 0.72 + 0.28 * (0.5 + 0.5 * sin(time * 0.071 + petalPhase))
                let length = radius * layerScale * (0.42 + 0.58 * spread)
                let width = radius * layerScale * (0.18 + 0.085 * spread)
                let curl = length * (0.10 + 0.10 * (1 - opening)) * sin(time * 0.11 + petalPhase)
                let angle = Double(petal) * .pi * 2 / Double(petals) + Double(ring) * 0.37
                    + 0.05 * sin(time * 0.09 + petalPhase)
                var blade = flower
                blade.rotate(by: .radians(angle))
                let color = blossomColor(colorPhase + Double(petal) * 0.065 + Double(ring) * 0.28)
                let highlight = blossomColor(colorPhase + 0.65 + Double(ring) * 0.3)
                var petalShape = Path()
                petalShape.move(to: CGPoint(x: radius * 0.025, y: 0))
                petalShape.addCurve(to: CGPoint(x: length * 0.94, y: curl - width * 0.30),
                                    control1: CGPoint(x: length * 0.16, y: -width * 0.85),
                                    control2: CGPoint(x: length * 0.62, y: curl - width * 1.10))
                petalShape.addCurve(to: CGPoint(x: length * 0.94, y: curl + width * 0.30),
                                    control1: CGPoint(x: length * 1.10, y: curl - width * 0.23),
                                    control2: CGPoint(x: length * 1.10, y: curl + width * 0.23))
                petalShape.addCurve(to: CGPoint(x: radius * 0.025, y: 0),
                                    control1: CGPoint(x: length * 0.65, y: curl + width),
                                    control2: CGPoint(x: length * 0.15, y: width * 0.70))
                petalShape.closeSubpath()
                blade.fill(petalShape, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: color.opacity(0.025), location: 0),
                        .init(color: color.opacity(0.20 + 0.035 * Double(ring)), location: 0.30),
                        .init(color: highlight.opacity(0.36), location: 0.62),
                        .init(color: Color(red: 1, green: 0.91, blue: 0.85).opacity(0.19), location: 0.82),
                        .init(color: color.opacity(0.09), location: 1)
                    ]), startPoint: CGPoint(x: 0, y: -width * 0.2),
                    endPoint: CGPoint(x: length * 1.06, y: curl + width * 0.15)
                ))
                // A curved fold gives each petal a cupped, dimensional surface.
                var fold = Path()
                fold.move(to: CGPoint(x: radius * 0.04, y: 0))
                fold.addCurve(to: CGPoint(x: length * 0.97, y: curl),
                              control1: CGPoint(x: length * 0.36, y: width * (0.18 + 0.10 * sin(petalPhase + time * 0.1))),
                              control2: CGPoint(x: length * 0.73, y: curl - width * 0.18))
                blade.stroke(fold, with: .linearGradient(
                    Gradient(colors: [.clear, highlight.opacity(0.13), Color.white.opacity(0.11), .clear]),
                    startPoint: .zero, endPoint: CGPoint(x: length, y: curl)
                ), style: StrokeStyle(lineWidth: max(0.6, radius * 0.004), lineCap: .round))
            }
        }

        // Tiny warm stamens remain nested in the petals, rather than forming another glowing orb.
        for seed in 0..<13 {
            let angle = Double(seed) * 2.399_963
            let distance = radius * 0.022 * sqrt(Double(seed))
            let point = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            let r = max(0.65, radius * 0.006)
            flower.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                        with: .color(Color(red: 1, green: 0.86, blue: 0.58).opacity(0.28 + 0.18 * opening)))
        }
        drawPollen(index: index, in: context, center: center, radius: radius, time: time, opening: opening)
    }

    private func drawPollen(index: Int, in context: GraphicsContext, center: CGPoint,
                            radius: CGFloat, time: Double, opening: Double) {
        for seed in 0..<7 {
            let cycle = time / (29 + Double(seed % 3) * 3) + Double(index) * 0.23 + Double(seed) * 0.137
            let progress = cycle - floor(cycle)
            let envelope = pow(sin(.pi * progress), 2)
            let angle = Double(seed) * 2.399_963 + Double(index) * 1.2
            let drift = progress * progress * (3 - 2 * progress)
            let reach = radius * (0.16 + 1.45 * drift)
            let point = CGPoint(x: center.x + cos(angle) * reach + radius * 0.09 * sin(drift * 5 + time * 0.10 + angle),
                                y: center.y + sin(angle) * reach * 0.6 - radius * 0.65 * drift * drift
                                    + radius * 0.035 * sin(time * 0.12 + angle))
            // Different, overlapping rhythms create a soft twinkle without blinking on or off.
            let twinkle = 0.5 + 0.5 * sin(time * (0.72 + Double(seed % 3) * 0.13) + angle
                                         + 0.38 * sin(time * 0.31 + Double(index)))
            let alpha = envelope * (0.13 + 0.24 * pow(twinkle, 2)) * (0.65 + 0.35 * opening)
            let r = max(0.8, radius * 0.009)
            context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2.6)),
                         with: .color(Color(red: 1, green: 0.91, blue: 0.80).opacity(alpha)))
            if (seed + index).isMultiple(of: 3) {
                let glimmer = envelope * pow(twinkle, 4)
                let flare = r * (2.0 + 1.4 * twinkle)
                var star = Path()
                star.move(to: CGPoint(x: point.x, y: point.y - flare))
                star.addLine(to: CGPoint(x: point.x + r * 0.22, y: point.y - r * 0.22))
                star.addLine(to: CGPoint(x: point.x + flare * 0.75, y: point.y))
                star.addLine(to: CGPoint(x: point.x + r * 0.22, y: point.y + r * 0.22))
                star.addLine(to: CGPoint(x: point.x, y: point.y + flare))
                star.addLine(to: CGPoint(x: point.x - r * 0.22, y: point.y + r * 0.22))
                star.addLine(to: CGPoint(x: point.x - flare * 0.75, y: point.y))
                star.addLine(to: CGPoint(x: point.x - r * 0.22, y: point.y - r * 0.22))
                star.closeSubpath()
                context.fill(star, with: .color(Color.white.opacity(0.22 * glimmer)))
            }
        }
    }

    private static let positions: [CGPoint] = [CGPoint(x: 0.10, y: 0.12), CGPoint(x: 0.90, y: 0.08),
                                                CGPoint(x: 0.50, y: 0.48), CGPoint(x: 0.12, y: 0.90),
                                                CGPoint(x: 0.91, y: 0.88)]
    private static let sizes: [CGFloat] = [0.17, 0.22, 0.25, 0.18, 0.20]
    private static let colors: [SIMD3<Double>] = [SIMD3(0.94, 0.40, 0.64), SIMD3(0.78, 0.48, 0.98),
                                                 SIMD3(0.42, 0.75, 0.98), SIMD3(0.99, 0.73, 0.43),
                                                 SIMD3(0.98, 0.65, 0.78)]

    private func blossomColor(_ phase: Double) -> Color {
        let progress = phase - floor(phase / 5) * 5
        let index = Int(floor(progress))
        let u = progress - floor(progress)
        let mix = u * u * (3 - 2 * u)
        let color = Self.colors[index] * (1 - mix) + Self.colors[(index + 1) % 5] * mix
        return Color(red: color.x, green: color.y, blue: color.z)
    }
}
