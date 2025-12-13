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
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    let rings = 14
                    for i in 0..<rings {
                        let p = Double(i) / Double(rings - 1)
                        let r = (min(size.width, size.height) * (0.08 + 0.52 * CGFloat(p)))
                                * (0.96 + 0.06 * CGFloat(sin(t * 0.06 + p * 6)))

                        let a = 0.015 + 0.055 * (1 - CGFloat(p))
                        let col: Color = (i % 2 == 0) ? config.palette.secondary : config.palette.primary

                        context.stroke(Path(ellipseIn: CGRect(x: c1.x - r, y: c1.y - r, width: r*2, height: r*2)),
                                      with: .color(col.opacity(a)),
                                      lineWidth: 1.2)

                        context.stroke(Path(ellipseIn: CGRect(x: c2.x - r, y: c2.y - r, width: r*2, height: r*2)),
                                      with: .color(config.palette.tertiary.opacity(a)),
                                      lineWidth: 1.2)
                    }
                }
                .blur(radius: 0.9)
            }
            .ignoresSafeArea()
        }
    }
}
