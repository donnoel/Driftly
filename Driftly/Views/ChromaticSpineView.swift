import SwiftUI

struct ChromaticSpineView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    // Background
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    // Spine curve
                    var spine = Path()
                    let midX = size.width * (0.52 + 0.04 * sin(t * 0.12))
                    spine.move(to: CGPoint(x: midX, y: -20))

                    for y in stride(from: 0.0, through: Double(size.height) + 40.0, by: 14.0) {
                        let yy = CGFloat(y)
                        let wobble = 22.0 * sin(y * 0.012 + t * 0.35) + 10.0 * cos(y * 0.02 + t * 0.22)
                        spine.addLine(to: CGPoint(x: midX + CGFloat(wobble), y: yy))
                    }

                    context.stroke(spine, with: .color(config.palette.secondary.opacity(0.18)), lineWidth: 18)
                    context.stroke(spine, with: .color(config.palette.primary.opacity(0.24)), lineWidth: 8)
                    context.stroke(spine, with: .color(Color.white.opacity(0.10)), lineWidth: 2)

                    // Ribs: short lines perpendicular-ish
                    for i in 0..<90 {
                        let yy = CGFloat(i) / 90 * size.height
                        let phase = Double(i) * 0.2
                        let rib = 20 + 24 * (0.5 + 0.5 * sin(t * 0.25 + phase))
                        let xShift = 18 * sin(Double(yy) * 0.01 + t * 0.35)

                        let left = CGPoint(x: midX - CGFloat(rib) + CGFloat(xShift), y: yy)
                        let right = CGPoint(x: midX + CGFloat(rib) + CGFloat(xShift), y: yy)

                        var p = Path()
                        p.move(to: left)
                        p.addLine(to: right)

                        let c: Color = (i % 3 == 0) ? config.palette.primary : (i % 3 == 1 ? config.palette.secondary : config.palette.tertiary)
                        context.stroke(p, with: .color(c.opacity(0.11)), lineWidth: 1.1)
                    }
                }
                .blur(radius: 0.7)
            }
            .ignoresSafeArea()
        }
    }
}
