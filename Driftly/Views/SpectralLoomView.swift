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
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
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

                        let col: Color = (i % 3 == 0) ? config.palette.primary : (i % 3 == 1 ? config.palette.secondary : config.palette.tertiary)
                        context.stroke(path, with: .color(col.opacity(0.07)), lineWidth: 1.0)
                    }
                }
                .blur(radius: 1.0)
            }
            .ignoresSafeArea()
        }
    }
}
