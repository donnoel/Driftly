import SwiftUI

struct RibbonOrbitView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PausableTimelineView(paused: animationsPaused || reduceMotion) { date in
            let time = date.timeIntervalSinceReferenceDate * max(0.25, speed)
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
                ))
                let backgroundPhase = time * 0.018
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [ribbonColor(backgroundPhase).opacity(0.075),
                                      ribbonColor(backgroundPhase + 1.8).opacity(0.04),
                                      ribbonColor(backgroundPhase + 3.6).opacity(0.065)]),
                    startPoint: CGPoint(x: size.width * 0.1, y: 0),
                    endPoint: CGPoint(x: size.width * 0.9, y: size.height)
                ))
                for piece in 0..<RibbonOrbitMotion.pieceCount {
                    drawRibbon(piece: piece, in: context, size: size, time: time)
                }
            }
            .blur(radius: 0.65)
            .ignoresSafeArea()
        }
    }

    private func drawRibbon(piece: Int, in context: GraphicsContext, size: CGSize, time: Double) {
        let separation = RibbonOrbitMotion.separation(piece: piece, time: time)
        let unit = min(size.width, size.height)
        var upper: [CGPoint] = [], lower: [CGPoint] = []
        upper.reserveCapacity(33)
        lower.reserveCapacity(33)
        var spine = Path()
        for sample in 0...32 {
            let progress = Double(sample) / 32
            let point = RibbonOrbitMotion.point(piece: piece, progress: progress, size: size, time: time)
            let before = RibbonOrbitMotion.point(piece: piece, progress: progress - 0.001, size: size, time: time)
            let after = RibbonOrbitMotion.point(piece: piece, progress: progress + 0.001, size: size, time: time)
            let dx = after.x - before.x, dy = after.y - before.y
            let length = max(0.001, hypot(dx, dy))
            let angle = (Double(piece) + progress) * .pi * 2 / Double(RibbonOrbitMotion.pieceCount)
            let fold = 0.55 + 0.45 * pow(sin(angle * 2 - time * 0.07), 2)
            let taper = 1 - separation * 0.65 * pow(abs(2 * progress - 1), 4)
            let width = unit * 0.009 * fold * taper
            upper.append(CGPoint(x: point.x - dy / length * width, y: point.y + dx / length * width))
            lower.append(CGPoint(x: point.x + dy / length * width, y: point.y - dx / length * width))
            if sample == 0 { spine.move(to: point) } else { spine.addLine(to: point) }
        }
        var silk = Path()
        if let first = upper.first {
            silk.move(to: first)
            for point in upper.dropFirst() { silk.addLine(to: point) }
            for point in lower.reversed() { silk.addLine(to: point) }
        }
        silk.closeSubpath()
        let colorPhase = time * 0.048
        let a = ribbonColor(colorPhase + sin(Double(piece) * .pi / 4) * 0.85)
        let start = CGPoint(x: (upper[0].x + lower[0].x) * 0.5, y: (upper[0].y + lower[0].y) * 0.5)
        let end = CGPoint(x: (upper[32].x + lower[32].x) * 0.5, y: (upper[32].y + lower[32].y) * 0.5)
        var colorStops: [Gradient.Stop] = [], pulseStops: [Gradient.Stop] = []
        for sample in 0...8 {
            let progress = Double(sample) / 8
            let angle = (Double(piece) + progress) * .pi * 2 / Double(RibbonOrbitMotion.pieceCount)
            let color = ribbonColor(colorPhase + 0.85 * sin(angle - time * 0.025))
            colorStops.append(.init(color: color.opacity(0.67), location: progress))
            // One broad, continuous crest travels through every piece, including across the loop seam.
            let pulse = pow(0.5 + 0.5 * cos(angle - time * 0.16), 5)
            let warmth = 0.5 + 0.5 * sin(time * 0.035)
            let light = Color(red: 1, green: 0.38 + 0.30 * warmth, blue: 0.19 + 0.10 * warmth)
            pulseStops.append(.init(color: light.opacity(0.36 * pulse), location: progress))
        }
        context.stroke(spine, with: .color(a.opacity(0.075)),
                       style: StrokeStyle(lineWidth: unit * 0.034, lineCap: .round))
        context.fill(silk, with: .linearGradient(Gradient(stops: colorStops), startPoint: start, endPoint: end))
        context.fill(silk, with: .linearGradient(Gradient(stops: pulseStops), startPoint: start, endPoint: end))
        context.stroke(spine, with: .linearGradient(Gradient(stops: pulseStops), startPoint: start, endPoint: end),
                       style: StrokeStyle(lineWidth: unit * 0.025, lineCap: .round))
        context.stroke(spine, with: .linearGradient(
            Gradient(colors: [a.opacity(0.15), .white.opacity(0.24), a.opacity(0.15)]),
            startPoint: start, endPoint: end
        ), style: StrokeStyle(lineWidth: max(0.7, unit * 0.0015), lineCap: .round))
    }

    private func ribbonColor(_ phase: Double) -> Color {
        let rgb = RibbonOrbitColor.rgb(phase: phase)
        return Color(red: rgb.x, green: rgb.y, blue: rgb.z)
    }
}

enum RibbonOrbitColor {
    private static let colors: [SIMD3<Double>] = [SIMD3(1.00, 0.16, 0.24), SIMD3(1.00, 0.38, 0.22),
                                                 SIMD3(1.00, 0.67, 0.23), SIMD3(0.96, 0.28, 0.57),
                                                 SIMD3(0.67, 0.38, 0.96), SIMD3(0.30, 0.76, 0.81)]

    static func rgb(phase: Double) -> SIMD3<Double> {
        // Wrap the integer index itself: large absolute timeline values can round a
        // floating remainder onto either side of a palette boundary.
        let whole = floor(phase)
        let index = ((Int(whole) % colors.count) + colors.count) % colors.count
        let fraction = phase - whole
        let mix = fraction * fraction * (3 - 2 * fraction)
        return colors[index] * (1 - mix) + colors[(index + 1) % colors.count] * mix
    }
}

/// Each piece is a continuous section of the same loop. At rest their endpoints coincide exactly.
enum RibbonOrbitMotion {
    static let pieceCount = 8

    static func separation(piece: Int, time: Double) -> Double {
        let cycle = time * .pi * 2 / 64 + Double(piece) * 0.09
        let value = min(1, max(0, ((0.5 - 0.5 * cos(cycle)) - 0.20) / 0.65))
        return value * value * (3 - 2 * value)
    }

    static func point(piece: Int, progress: Double, size: CGSize, time: Double) -> CGPoint {
        let split = separation(piece: piece, time: time)
        let span = .pi * 2 / Double(pieceCount)
        let middle = (Double(piece) + 0.5) * span
        let angle = (Double(piece) + progress) * span + (0.5 - progress) * 0.14 * split
        let phase = time * 0.035
        func loop(_ u: Double) -> CGPoint {
            CGPoint(x: 0.28 * cos(u + phase) + 0.045 * sin(2 * u - phase * 0.7),
                    y: 0.24 * sin(u + phase) + 0.025 * cos(3 * u + phase * 0.8))
        }
        let pivot = loop(middle)
        let base = loop(angle)
        let turn = split * 0.55 * sin(time * (0.036 + Double(piece % 3) * 0.003) + middle * 1.7)
        let dx = base.x - pivot.x, dy = base.y - pivot.y
        let driftAngle = middle + phase
        let x = pivot.x + dx * cos(turn) - dy * sin(turn) + split * 0.115 * cos(driftAngle)
        let y = pivot.y + dx * sin(turn) + dy * cos(turn) + split * 0.145 * sin(driftAngle)
        return CGPoint(x: size.width * (0.5 + x), y: size.height * (0.5 + y))
    }
}
