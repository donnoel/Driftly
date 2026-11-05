import SwiftUI

struct RainWindowView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PausableTimelineView(paused: animationsPaused || reduceMotion) { date in
            let elapsed = date.timeIntervalSinceReferenceDate
            let time = elapsed * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    render(in: context, size: size, time: time, flourishTime: elapsed)
                }
                .ignoresSafeArea()
            }
        }
    }

    private func render(in context: GraphicsContext, size: CGSize, time: Double, flourishTime: Double) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.018, green: 0.035, blue: 0.105),
                    Color(red: 0.012, green: 0.016, blue: 0.055)
                ]),
                startPoint: CGPoint(x: size.width * 0.5, y: 0),
                endPoint: CGPoint(x: size.width * 0.5, y: size.height)
            )
        )

        drawDistantWindowGlow(in: context, rect: rect, size: size, time: time)

        var rainLayer = context
        drawCondensation(in: &rainLayer, size: size, time: time)
        drawRunningDrops(in: &rainLayer, size: size, time: time)
        if !reduceMotion {
            // Keep the occasional surprise about 15 seconds apart even at a slow rain setting.
            drawWanderingDrop(in: rainLayer, size: size, time: flourishTime)
        }

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
                    Color(red: 0.28, green: 0.35, blue: 0.68).opacity(0.20),
                    config.palette.primary.opacity(0.045),
                    Color.clear
                ]),
                center: glowCenter,
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.82
            )
        )
        for index in 0..<6 {
            let phase = Double(index) * 1.71
            let center = CGPoint(x: size.width * CGFloat(0.06 + 0.18 * Double(index)),
                                 y: size.height * CGFloat(0.62 + 0.16 * sin(phase)))
            let radius = min(size.width, size.height) * CGFloat(0.10 + 0.05 * cos(phase))
            let color: Color
            switch index % 3 {
            case 0: color = Color(red: 1, green: 0.62, blue: 0.28)
            case 1: color = Color(red: 0.95, green: 0.34, blue: 0.52)
            default: color = Color(red: 0.22, green: 0.72, blue: 0.87)
            }
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .radialGradient(Gradient(colors: [color.opacity(0.30), color.opacity(0.10), .clear]),
                                               center: center, startRadius: 0, endRadius: radius))
        }

    }

    /// Small beads cling to the glass. They collect slowly instead of all drifting together.
    private func drawCondensation(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let count = min(140, max(70, Int(size.width / 5)))
        for index in 0..<count {
            let seed = 1400 + index * 19
            let phase = DriftNoise.hash(index, 1, seed: seed)
            let progress = DriftNoise.fract(time / (24 + phase * 22) + phase)
            let envelope = min(1, min(progress / 0.12, (1 - progress) / 0.12))
            let center = CGPoint(x: size.width * CGFloat(DriftNoise.hash(index, 5, seed: seed)),
                                 y: size.height * CGFloat(DriftNoise.hash(index, 9, seed: seed)))
            let radius = min(size.width, size.height) * CGFloat(0.002 + 0.004 * phase)
                * CGFloat(0.6 + 0.4 * progress)
            drawGlassDrop(in: context, center: center, radius: max(0.7, radius),
                          stretch: 1.05, opacity: 0.40 * envelope)
        }
    }

    /// Independent stick/release cycles: surface tension holds the bead, then gravity wins.
    private func drawRunningDrops(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let count = min(24, max(10, Int(size.width / 60)))
        let base = min(size.width, size.height)
        for index in 0..<count {
            let seed = 900 + index * 17
            let phase = DriftNoise.hash(index, 2, seed: seed)
            let cycle = 13 + 13 * DriftNoise.hash(index, 3, seed: seed)
            let progress = DriftNoise.fract(time / cycle + phase)
            let hold = 0.24 + 0.18 * DriftNoise.hash(index, 4, seed: seed)
            let slide = max(0, (progress - hold) / (1 - hold))
            let x = size.width * CGFloat(0.025 + 0.95 * DriftNoise.hash(index, 5, seed: seed))
            let startY = size.height * CGFloat(-0.03 + 0.52 * DriftNoise.hash(index, 6, seed: seed))
            let travel = size.height * 1.15 - startY
            let radius = min(13, base * CGFloat(0.010 + 0.015 * DriftNoise.hash(index, 7, seed: seed)))
            let bend = CGFloat(1.5 + 3.5 * DriftNoise.hash(index, 8, seed: seed))
            let opacity = min(1, progress / 0.06) * min(1, (1 - progress) / 0.07)
            let center = runnerPosition(slide: slide, x: x, startY: startY,
                                        travel: travel, bend: bend, phase: phase)
            if slide > 0 {
                var trail = Path()
                let history = min(slide, 0.12)
                for point in 0...10 {
                    let u = slide - history + history * Double(point) / 10
                    let position = runnerPosition(slide: u, x: x, startY: startY,
                                                  travel: travel, bend: bend, phase: phase)
                    if point == 0 { trail.move(to: position) } else { trail.addLine(to: position) }
                }
                let tail = runnerPosition(slide: slide - history, x: x, startY: startY,
                                          travel: travel, bend: bend, phase: phase)
                context.stroke(trail, with: .linearGradient(
                    Gradient(colors: [.clear, config.palette.primary.opacity(0.045 * opacity),
                                      Color.white.opacity(0.10 * opacity)]),
                    startPoint: tail, endPoint: center
                ), style: StrokeStyle(lineWidth: max(1, radius * 0.50), lineCap: .round))
                // A thin edge catches the distant light along the newly cleared rivulet.
                context.stroke(trail, with: .color(Color.white.opacity(0.035 * opacity)), lineWidth: 0.65)
            }
            let growth = slide > 0 ? 1 : 0.45 + 0.55 * progress / hold
            drawGlassDrop(in: context, center: center, radius: radius * CGFloat(growth),
                          stretch: 1.12 + 0.55 * min(1, slide * 5), opacity: opacity)
        }
    }

    /// One quiet exception to gravity, with long ordinary-rain gaps between appearances.
    private func drawWanderingDrop(in context: GraphicsContext, size: CGSize, time: Double) {
        let cycle = Int(floor(time / 15))
        let age = time - Double(cycle) * 15
        guard age < 7 else { return }
        let seed = 4300 + cycle % 97
        let base = min(size.width, size.height)
        let origin = CGPoint(
            x: size.width * CGFloat(0.18 + 0.64 * DriftNoise.hash(cycle, 3, seed: seed)),
            y: size.height * CGFloat(0.52 + 0.30 * DriftNoise.hash(cycle, 5, seed: seed))
        )
        let firstRise = gentleStep((age - 0.6) / 1.9)
        // Rest from 2.5–3.5 seconds, then curl upward and settle before fading away.
        let curl = gentleStep((age - 3.5) / 2.0)
        let angle = curl * .pi * 2
        let lift = base * CGFloat(0.075 * firstRise + 0.12 * curl)
        let loop = base * 0.018
        let center = CGPoint(x: origin.x + loop * CGFloat(sin(angle)),
                             y: origin.y - lift + loop * CGFloat(cos(angle) - 1))
        let opacity = 0.85 * gentleStep(age / 0.8) * (1 - gentleStep((age - 6) / 1.0))
        var drop = context
        drop.translateBy(x: center.x, y: center.y)
        drop.rotate(by: .radians(angle))
        drawGlassDrop(in: drop, center: .zero, radius: min(8, base * 0.014),
                      stretch: 1.2, opacity: opacity)
    }

    private func gentleStep(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    private func runnerPosition(slide: Double, x: CGFloat, startY: CGFloat,
                                travel: CGFloat, bend: CGFloat, phase: Double) -> CGPoint {
        // Smooth acceleration into a terminal slide; the path never reverses uphill.
        let drag = 0.14
        let distance = (slide - drag * (1 - exp(-slide / drag))) / (1 - drag * (1 - exp(-1 / drag)))
        let sway = sin(distance * 9 + phase * 6) - sin(phase * 6)
        return CGPoint(x: x + bend * CGFloat(sway), y: startY + travel * CGFloat(distance))
    }

    private func drawGlassDrop(in context: GraphicsContext, center: CGPoint,
                               radius r: CGFloat, stretch: Double, opacity: Double) {
        let top = center.y - r * CGFloat(stretch)
        var drop = Path()
        drop.move(to: CGPoint(x: center.x, y: center.y + r))
        drop.addCurve(to: CGPoint(x: center.x, y: top),
                      control1: CGPoint(x: center.x - r * 1.55, y: center.y + r),
                      control2: CGPoint(x: center.x - r * 0.80, y: top))
        drop.addCurve(to: CGPoint(x: center.x, y: center.y + r),
                      control1: CGPoint(x: center.x + r * 0.80, y: top),
                      control2: CGPoint(x: center.x + r * 1.55, y: center.y + r))
        drop.closeSubpath()
        context.fill(drop, with: .color(Color.black.opacity(0.24 * opacity)))
        context.fill(drop, with: .linearGradient(
            Gradient(colors: [Color.white.opacity(0.07 * opacity), .clear,
                              config.palette.primary.opacity(0.12 * opacity)]),
            startPoint: CGPoint(x: center.x - r, y: top),
            endPoint: CGPoint(x: center.x + r, y: center.y + r)
        ))
        context.stroke(drop, with: .color(Color.white.opacity(0.11 * opacity)), lineWidth: 0.65)
        var glint = Path()
        glint.move(to: CGPoint(x: center.x - r * 0.52, y: center.y - r * 0.35))
        glint.addQuadCurve(to: CGPoint(x: center.x - r * 0.15, y: top + r * 0.24),
                           control: CGPoint(x: center.x - r * 0.56, y: top + r * 0.32))
        context.stroke(glint, with: .color(Color.white.opacity(0.30 * opacity)),
                       style: StrokeStyle(lineWidth: max(0.6, r * 0.14), lineCap: .round))
        var lowerRim = Path()
        lowerRim.addArc(center: center, radius: r * 0.74,
                        startAngle: .degrees(35), endAngle: .degrees(135), clockwise: false)
        context.stroke(lowerRim, with: .color(config.palette.tertiary.opacity(0.27 * opacity)),
                       style: StrokeStyle(lineWidth: max(0.65, r * 0.12), lineCap: .round))
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
