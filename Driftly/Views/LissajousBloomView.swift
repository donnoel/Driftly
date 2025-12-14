import SwiftUI

struct LissajousBloomView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

                Canvas { context, _ in
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    var path = Path()

                    // Bigger bloom + gentle breathing pulse
                    let base = min(size.width, size.height)
                    let pulse = 0.92 + 0.12 * (0.5 + 0.5 * sin(t * 0.55))
                    let A = base * 0.46 * pulse
                    let B = base * 0.35 * pulse

                    // Slow color drift (premium, not rainbow)
                    let mix = 0.5 + 0.5 * sin(t * 0.06)
                    let mix2 = 0.5 + 0.5 * cos(t * 0.05)
                    let c1 = config.palette.primary.interpolate(to: config.palette.secondary, t: mix)
                    let c2 = config.palette.secondary.interpolate(to: config.palette.tertiary, t: mix2)
                    let c3 = config.palette.tertiary.interpolate(to: config.palette.primary, t: 0.5 * (mix + mix2))

                    for i in 0..<520 {
                        let u = Double(i) / 519.0 * Double.pi * 2
                        let x = center.x + CGFloat(A * sin(3*u + t*0.06) + 0.12*A * sin(7*u + t*0.05))
                        let y = center.y + CGFloat(B * sin(2*u + t*0.07) + 0.12*B * cos(5*u + t*0.06))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }

                    let wPulse = 0.85 + 0.35 * (0.5 + 0.5 * cos(t * 0.62))
                    context.stroke(path, with: .color(c1.opacity(0.18)), lineWidth: 22 * wPulse)
                    context.stroke(path, with: .color(c2.opacity(0.16)), lineWidth: 12 * wPulse)
                    context.stroke(path, with: .color(c3.opacity(0.10)), lineWidth: 7 * wPulse)
                    context.stroke(path, with: .color(Color.white.opacity(0.07)), lineWidth: 2.2 * wPulse)
                }
                .blur(radius: 1.2)
            }
            .ignoresSafeArea()
        }
    }
}

private extension Color {
    func interpolate(to other: Color, t: Double) -> Color {
        let tt = max(0.0, min(1.0, t))
        #if canImport(UIKit)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: Double(r1 + (r2 - r1) * CGFloat(tt)),
            green: Double(g1 + (g2 - g1) * CGFloat(tt)),
            blue: Double(b1 + (b2 - b1) * CGFloat(tt)),
            opacity: Double(a1 + (a2 - a1) * CGFloat(tt))
        )
        #else
        return self
        #endif
    }
}
