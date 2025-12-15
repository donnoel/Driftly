import SwiftUI

struct HaloInterferenceView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size
                let c1 = CGPoint(x: size.width * 0.40, y: size.height * 0.52)
                let c2 = CGPoint(x: size.width * 0.62, y: size.height * 0.48)

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

                    // Soft bloom overlay (premium glow)
                    let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .radialGradient(
                            Gradient(colors: [
                                config.palette.primary.opacity(0.18),
                                config.palette.secondary.opacity(0.16),
                                config.palette.tertiary.opacity(0.12),
                                Color.clear
                            ]),
                            center: center,
                            startRadius: 0,
                            endRadius: max(size.width, size.height) * 1.05
                        )
                    )

                    let rings = 14
                    let yellowIndex = max(1, min(rings - 2, rings / 3))
                    let yellow = Color(red: 1.00, green: 0.92, blue: 0.30)

                    for i in 0..<rings {
                        let p = Double(i) / Double(rings - 1)
                        let r = (min(size.width, size.height) * (0.08 + 0.52 * CGFloat(p)))
                                * (0.96 + 0.06 * CGFloat(sin(t * 0.06 + p * 6)))

                        let a = 0.015 + 0.055 * (1 - CGFloat(p))
                        let col: Color = (i % 2 == 0) ? config.palette.secondary : config.palette.primary

                        let ring1 = Path(ellipseIn: CGRect(x: c1.x - r, y: c1.y - r, width: r * 2, height: r * 2))
                        let ring2 = Path(ellipseIn: CGRect(x: c2.x - r, y: c2.y - r, width: r * 2, height: r * 2))

                        if i == yellowIndex {
                            // One featured ring: bright yellow + pulse
                            let pulse = 0.5 + 0.5 * sin(t * 0.95)
                            let w = 1.6 + 3.2 * CGFloat(pulse)

                            // Glow layers so it's unmistakable
                            context.stroke(ring1, with: .color(yellow.opacity(0.16 + 0.18 * pulse)), lineWidth: w * 5.0)
                            context.stroke(ring1, with: .color(yellow.opacity(0.28 + 0.22 * pulse)), lineWidth: w * 2.3)
                            context.stroke(ring1, with: .color(yellow.opacity(0.62 + 0.18 * pulse)), lineWidth: w)
                            context.stroke(ring1, with: .color(Color.white.opacity(0.10 + 0.10 * pulse)), lineWidth: max(1.0, w * 0.55))
                        } else {
                            // Normal rings (slightly brighter than before)
                            context.stroke(ring1, with: .color(col.opacity(a * 1.35)), lineWidth: 1.25)
                        }

                        context.stroke(ring2, with: .color(config.palette.tertiary.opacity(a * 1.25)), lineWidth: 1.25)
                    }
                }
                .blur(radius: 0.55)
            }
            .ignoresSafeArea()
        }
    }
}
