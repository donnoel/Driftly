import SwiftUI

struct MeridianArcsView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.55)

                Canvas { context, _ in
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: size.width, y: size.height)
                        )
                    )

                    for i in 0..<14 {
                        let p = Double(i) / 13.0
                        let radiusX = min(size.width, size.height) * (0.22 + 0.38 * p)
                        let radiusY = radiusX * (0.55 + 0.10 * sin(t*0.05 + p*3))

                        var arc = Path()
                        let start = Double.pi * (0.15 + 0.08 * sin(t*0.03 + p*4))
                        let end = Double.pi * (1.85 + 0.08 * cos(t*0.03 + p*3))

                        let steps = 180
                        for s in 0...steps {
                            let u = DriftNoise.lerp(start, end, Double(s) / Double(steps))
                            let x = center.x + CGFloat(radiusX * cos(u))
                            let y = center.y + CGFloat(radiusY * sin(u))
                            if s == 0 { arc.move(to: CGPoint(x: x, y: y)) }
                            else { arc.addLine(to: CGPoint(x: x, y: y)) }
                        }

                        let col: Color = (i % 3 == 0) ? config.palette.tertiary : (i % 3 == 1 ? config.palette.secondary : config.palette.primary)
                        context.stroke(arc, with: .color(col.opacity(0.10)), lineWidth: 1.2)
                    }
                }
                .blur(radius: 0.7)
            }
            .ignoresSafeArea()
        }
    }
}
