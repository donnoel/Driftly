import SwiftUI

struct InkTopographyView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PausableTimelineView(paused: animationsPaused || reduceMotion) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size
                let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                let octaves = (isLowPower || max(size.width, size.height) > 1200) ? 4 : 5
                let step = InkTopographySurface.step(in: size)

                Canvas { context, _ in
                    // Lifted background for daytime visibility
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [
                                config.palette.backgroundTop.opacity(1.0),
                                config.palette.backgroundBottom.opacity(0.96)
                            ]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    // Soft bloom overlay (adds depth + premium glow)
                    let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .radialGradient(
                            Gradient(colors: [
                                config.palette.primary.opacity(0.22),
                                config.palette.secondary.opacity(0.18),
                                config.palette.tertiary.opacity(0.14),
                                Color.clear
                            ]),
                            center: center,
                            startRadius: 0,
                            endRadius: max(size.width, size.height) * 1.10
                        )
                    )

                    // Contours
                    let climber = InkTopographyClimber.pose(size: size, time: t, octaves: octaves)
                    let bands = InkTopographySurface.bands
                    for b in 0..<bands {
                        var path = Path()
                        let gap = InkTopographyClimber.gap(band: b, pose: climber, size: size, time: t, octaves: octaves)
                        let width = Double(size.width)
                        let ranges: [ClosedRange<Double>] = gap.map {
                            [0.0...max(0, $0.lowerBound), min(width, $0.upperBound)...width]
                        } ?? [0.0...width]
                        for range in ranges {
                            let xs = Array(stride(from: range.lowerBound, to: range.upperBound, by: step)) + [range.upperBound]
                            for (index, x) in xs.enumerated() {
                                let y = InkTopographySurface.y(x: x, band: b, size: size, time: t, octaves: octaves)
                                let point = CGPoint(x: x, y: y)
                                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                            }
                        }

                        let col: Color = {
                            // Accent contours to break monotony
                            if b % 9 == 0 { return Color(red: 1.00, green: 0.40, blue: 0.82) } // pink
                            if b % 11 == 0 { return Color(red: 1.00, green: 0.82, blue: 0.34) } // warm yellow
                            if b % 13 == 0 { return Color(red: 0.40, green: 0.84, blue: 1.00) } // cyan
                            return (b % 2 == 0) ? config.palette.secondary : config.palette.primary
                        }()

                        // Layered strokes so contours read clearly
                        context.stroke(path, with: .color(col.opacity(0.14)), lineWidth: 7.5)
                        context.stroke(path, with: .color(col.opacity(0.22)), lineWidth: 3.2)
                        context.stroke(path, with: .color(col.opacity(0.34)), lineWidth: 1.6)
                        context.stroke(path, with: .color(Color.white.opacity(0.12)), lineWidth: 0.9)
                    }

                    // Animated light sweep (subtle premium motion)
                    let sweepX = center.x + CGFloat(sin(t * 0.10)) * size.width * 0.42
                    let sweepRect = CGRect(x: sweepX - 160, y: 0, width: 320, height: size.height)
                    context.fill(
                        Path(sweepRect),
                        with: .linearGradient(
                            Gradient(colors: [
                                Color.white.opacity(0.00),
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.00)
                            ]),
                            startPoint: CGPoint(x: sweepRect.minX, y: 0),
                            endPoint: CGPoint(x: sweepRect.maxX, y: 0)
                        )
                    )
                    InkTopographySprite.draw(in: context, pose: climber, size: size, time: t)
                }
                .blur(radius: 0.35)
            }
            .ignoresSafeArea()
        }
    }
}
