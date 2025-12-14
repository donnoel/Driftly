import SwiftUI

struct SpectralLoomView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

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

                    // Soft bloom overlay to brighten the scene while staying ambient
                    let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .radialGradient(
                            Gradient(colors: [
                                config.palette.primary.opacity(0.26),
                                config.palette.secondary.opacity(0.20),
                                config.palette.tertiary.opacity(0.16),
                                Color.clear
                            ]),
                            center: center,
                            startRadius: 0,
                            endRadius: max(size.width, size.height) * 1.10
                        )
                    )

                    let strands = 70
                    for i in 0..<strands {
                        let p = Double(i) / Double(strands - 1)
                        let x0 = CGFloat(p) * size.width
                        var path = Path()
                        path.move(to: CGPoint(x: x0, y: -30))

                        for y in stride(from: 0.0, through: Double(size.height) + 40.0, by: 12.0) {
                            let yy = CGFloat(y)
                            let bend = 18 * sin(Double(yy) * 0.01 + t * 0.25 + p * 6)
                                     + 8 * cos(Double(yy) * 0.02 + t * 0.12 + p * 8)
                            path.addLine(to: CGPoint(x: x0 + CGFloat(bend), y: yy))
                        }

                        let col: Color = {
                            // Accent strands (fun, still premium)
                            if i % 11 == 0 { return Color(red: 1.00, green: 0.36, blue: 0.90) } // hot pink
                            if i % 17 == 0 { return Color(red: 1.00, green: 0.80, blue: 0.34) } // warm yellow
                            if i % 23 == 0 { return Color(red: 0.40, green: 0.84, blue: 1.00) } // cyan
                            switch i % 3 {
                            case 0: return config.palette.primary
                            case 1: return config.palette.secondary
                            default: return config.palette.tertiary
                            }
                        }()

                        // Luminous strand (layered glow -> crisp core)
                        context.stroke(path, with: .color(col.opacity(0.18)), lineWidth: 9.0)
                        context.stroke(path, with: .color(col.opacity(0.30)), lineWidth: 4.6)
                        context.stroke(path, with: .color(col.opacity(0.48)), lineWidth: 2.1)
                        context.stroke(path, with: .color(Color.white.opacity(0.14)), lineWidth: 1.0)
                    }

                    // Animated glow sweep (subtle, adds depth)
                    let sweepX = (size.width * 0.5) + CGFloat(sin(t * 0.12)) * size.width * 0.42
                    let sweepRect = CGRect(x: sweepX - 150, y: 0, width: 300, height: size.height)
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
                }
                .blur(radius: 0.35)
            }
            .ignoresSafeArea()
        }
    }
}
