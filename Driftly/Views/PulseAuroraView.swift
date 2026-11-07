import SwiftUI

struct PulseAuroraView: View {
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
                    Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
                ))
                context.fill(bounds, with: .radialGradient(
                    Gradient(colors: [config.palette.secondary.opacity(0.07), .clear]),
                    center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                    startRadius: 0, endRadius: max(size.width, size.height) * 0.8
                ))
                var silk = context
                silk.blendMode = .plusLighter
                drawSheet(index: 1, in: silk, size: size, time: time)
                drawSheet(index: 0, in: silk, size: size, time: time)
                context.fill(bounds, with: .radialGradient(
                    Gradient(colors: [.clear, .black.opacity(0.22)]),
                    center: CGPoint(x: size.width * 0.5, y: size.height * 0.48),
                    startRadius: min(size.width, size.height) * 0.26,
                    endRadius: max(size.width, size.height) * 0.80
                ))
            }
            .blur(radius: 1.1)
            .ignoresSafeArea()
        }
    }

    private func drawSheet(index: Int, in context: GraphicsContext, size: CGSize, time: Double) {
        let base = min(size.width, size.height)
        let phase = Double(index) * 2.3
        let center = CGPoint(x: size.width * (0.5 + 0.10 * sin(time * 0.019 + phase)),
                             y: size.height * (0.5 + 0.25 * sin(time * 0.017 + phase)))
        let angle = -0.28 + 0.35 * sin(time * 0.013 + phase)
        let length = hypot(size.width, size.height) * 1.35
        let columns = 64
        let strips = 48
        // Sample the current once along the sheet; all the translucent folds share this surface.
        let current = (0...columns).map { step -> (x: Double, y: Double, width: Double, wave: Double) in
            let u = Double(step) / Double(columns)
            let taper = 0.25 + 0.75 * pow(max(0, sin(.pi * u)), 0.6)
            return (x: (u - 0.5) * length,
                    y: base * (0.20 * sin(u * .pi * 2 + time * 0.034 + phase)
                               + 0.07 * sin(u * .pi * 4 - time * 0.025 + phase)),
                    width: base * (0.21 + 0.07 * sin(u * 5 + time * 0.03 + phase)) * taper,
                    wave: u * 5 - time * 0.08 + phase)
        }
        let ca = cos(angle), sa = sin(angle)
        let rows = (0...strips).map { row in
            let v = -1 + 2 * Double(row) / Double(strips)
            return current.enumerated().map { step, sample -> CGPoint in
                let u = Double(step) / Double(columns)
                let x = sample.x + base * 0.09 * sin(v * .pi * 0.8 + u * 3 + time * 0.027 + phase) * (1 - v * v)
                let y = sample.y + v * sample.width + base * 0.06 * sin(v * .pi + sample.wave) * sin(.pi * u)
                return CGPoint(x: center.x + x * ca - y * sa, y: center.y + x * sa + y * ca)
            }
        }
        let crease = 0.30 * sin(time * 0.035 + phase)
        let depth = index == 0 ? 1.0 : 0.58
        let lightPhase = time * 0.025 + phase
        let gradientStart = rows[strips / 2][0]
        let gradientEnd = rows[strips / 2][columns]
        for strip in 0..<strips {
            let v = -1 + 2 * (Double(strip) + 0.5) / Double(strips)
            let edge = pow(max(0, 1 - v * v), 1.7)
            let fold = exp(-pow((v - crease) / 0.22, 2))
            let alpha = (0.14 * edge + 0.15 * fold) * depth
            var membrane = Path()
            for (step, point) in rows[strip].enumerated() {
                if step == 0 { membrane.move(to: point) } else { membrane.addLine(to: point) }
            }
            for point in rows[strip + 1].reversed() { membrane.addLine(to: point) }
            membrane.closeSubpath()
            context.fill(membrane, with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: auroraColor(lightPhase + v * 0.4).opacity(alpha * 0.75), location: 0.18),
                    .init(color: auroraColor(lightPhase + 1.0 + v * 0.4).opacity(alpha), location: 0.35),
                    .init(color: auroraColor(lightPhase + 2.0 + v * 0.4).opacity(alpha), location: 0.50),
                    .init(color: auroraColor(lightPhase + 3.0 + v * 0.4).opacity(alpha), location: 0.65),
                    .init(color: auroraColor(lightPhase + 4.0 + v * 0.4).opacity(alpha * 0.70), location: 0.84),
                    .init(color: .clear, location: 1)
                ]), startPoint: gradientStart, endPoint: gradientEnd
            ))
        }
        // A broad, faint pulse follows the actual crease, rather than brightening the entire scene.
        let ridge = (crease + 1) * 0.5 * Double(strips)
        let row = min(strips - 1, max(0, Int(floor(ridge))))
        let rowMix = ridge - Double(row)
        let travel = 0.5 + 0.32 * sin(time * 0.045 + phase)
        func creasePoint(_ u: Double) -> CGPoint {
            let column = min(Double(columns), max(0, u * Double(columns)))
            let first = min(columns - 1, Int(floor(column)))
            let mix = column - Double(first)
            func sample(_ r: Int) -> CGPoint {
                CGPoint(x: rows[r][first].x * (1 - mix) + rows[r][first + 1].x * mix,
                        y: rows[r][first].y * (1 - mix) + rows[r][first + 1].y * mix)
            }
            let a = sample(row), b = sample(row + 1)
            return CGPoint(x: a.x * (1 - rowMix) + b.x * rowMix,
                           y: a.y * (1 - rowMix) + b.y * rowMix)
        }
        var pulse = Path()
        for step in 0...32 {
            let point = creasePoint(travel - 0.17 + 0.34 * Double(step) / 32)
            if step == 0 { pulse.move(to: point) } else { pulse.addLine(to: point) }
        }
        let sheen = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [.clear, auroraColor(lightPhase + 1.2).opacity(0.12 * depth),
                              Color.white.opacity(0.12 * depth), .clear]),
            startPoint: creasePoint(travel - 0.17), endPoint: creasePoint(travel + 0.17)
        )
        context.stroke(pulse, with: sheen, style: StrokeStyle(lineWidth: base * 0.065, lineCap: .round))
        context.stroke(pulse, with: sheen, style: StrokeStyle(lineWidth: base * 0.018, lineCap: .round))
    }

    private static let colors: [SIMD3<Double>] = [SIMD3(0.25, 0.88, 0.80), SIMD3(0.61, 0.48, 0.96),
                                                  SIMD3(0.98, 0.52, 0.77), SIMD3(0.98, 0.78, 0.52)]

    private func auroraColor(_ phase: Double) -> Color {
        let progress = phase - floor(phase / 4) * 4
        let index = Int(floor(progress))
        let u = progress - floor(progress)
        let mix = u * u * (3 - 2 * u)
        let color = Self.colors[index] * (1 - mix) + Self.colors[(index + 1) % 4] * mix
        return Color(red: color.x, green: color.y, blue: color.z)
    }
}
