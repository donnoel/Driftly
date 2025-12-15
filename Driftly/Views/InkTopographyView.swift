import SwiftUI

struct InkTopographyView: View {
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
                    let bands = 18
                    for b in 0..<bands {
                        let yBase = Double(b) / Double(bands - 1)
                        var path = Path()

                        for x in stride(from: 0.0, through: Double(size.width), by: 8.0) {
                            let nx = x / Double(size.width)
                            let n = DriftNoise.fbm(x: nx * 2.2 + t * 0.03, y: yBase * 2.0 + t * 0.02, seed: 42, octaves: 5)

                            // Some bands ripple (switching pattern via band index)
                            let rippleOn = (b % 5 == 0) || (b % 7 == 0)
                            let rippleAmp = rippleOn ? 10.0 : 0.0
                            let ripple = rippleAmp * sin(nx * Double.pi * 2.0 * 3.0 + t * 0.55 + Double(b) * 0.7)

                            let yy = yBase * Double(size.height) + (n - 0.5) * 92.0 + ripple
                            let pt = CGPoint(x: x, y: yy)
                            if x == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
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
                }
                .blur(radius: 0.35)
            }
            .ignoresSafeArea()
        }
    }
}
