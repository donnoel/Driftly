import SwiftUI

struct PrismShardsView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: size.height)
                        )
                    )

                    let shardCount = 14
                    for i in 0..<shardCount {
                        let p = Double(i) * 0.7
                        let cx = size.width * (0.15 + 0.7 * CGFloat(DriftNoise.hash(i, 11, seed: 9)))
                        let cy = size.height * (0.10 + 0.75 * CGFloat(DriftNoise.hash(i, 27, seed: 9)))

                        let driftX = 40 * sin(t * 0.05 + p)
                        let driftY = 30 * cos(t * 0.06 + p * 0.9)

                        let w = 120 + 140 * CGFloat(DriftNoise.hash(i, 99, seed: 9))
                        let h = 90 + 130 * CGFloat(DriftNoise.hash(i, 77, seed: 9))
                        let angle = (t * 0.03 + p) * 0.7

                        var poly = Path()
                        let center = CGPoint(x: cx + CGFloat(driftX), y: cy + CGFloat(driftY))
                        let pts = [
                            CGPoint(x: -w*0.5, y: -h*0.3),
                            CGPoint(x:  w*0.5, y: -h*0.45),
                            CGPoint(x:  w*0.35, y:  h*0.5),
                            CGPoint(x: -w*0.45, y:  h*0.35),
                        ].map { pt in
                            let ca = CGFloat(cos(Double(angle)))
                            let sa = CGFloat(sin(Double(angle)))
                            let x = pt.x * ca - pt.y * sa
                            let y = pt.x * sa + pt.y * ca
                            return CGPoint(x: center.x + x, y: center.y + y)
                        }

                        poly.move(to: pts[0])
                        poly.addLines(pts)
                        poly.closeSubpath()

                        let col: Color = (i % 3 == 0) ? config.palette.primary : (i % 3 == 1 ? config.palette.secondary : config.palette.tertiary)
                        context.fill(poly, with: .color(col.opacity(0.10)))
                        context.stroke(poly, with: .color(Color.white.opacity(0.06)), lineWidth: 0.8)
                    }
                }
                .blur(radius: 0.9)
            }
            .ignoresSafeArea()
        }
    }
}
