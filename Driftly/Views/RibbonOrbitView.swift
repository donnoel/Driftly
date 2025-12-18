import SwiftUI

struct RibbonOrbitView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size
                let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

                Canvas { context, _ in
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: size.height)
                        )
                    )

                    // Ribbon as thick stroked path with gradient-like layering
                    var path = Path()
                    // Bigger orbit + gentle breathing pulse
                    let base = min(size.width, size.height)
                    let pulse = 0.92 + 0.12 * (0.5 + 0.5 * sin(t * 0.55))
                    let a = base * 0.46 * pulse
                    let b = base * 0.33 * pulse

                    for i in 0..<240 {
                        let u = Double(i) / 239.0 * Double.pi * 2
                        let x = c.x + CGFloat(a * cos(u + t * 0.08) + 0.25 * a * sin(2*u + t * 0.12))
                        let y = c.y + CGFloat(b * sin(u + t * 0.10) + 0.18 * b * cos(3*u + t * 0.09))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }

                    let wPulse = 0.85 + 0.35 * (0.5 + 0.5 * cos(t * 0.62))
                    context.stroke(path, with: .color(config.palette.tertiary.opacity(0.16)), lineWidth: 30 * wPulse)
                    context.stroke(path, with: .color(config.palette.primary.opacity(0.18)), lineWidth: 16 * wPulse)
                    context.stroke(path, with: .color(Color.white.opacity(0.08)), lineWidth: 2.4 * wPulse)
                }
                .blur(radius: 1.4)
            }
            .ignoresSafeArea()
        }
    }
}
