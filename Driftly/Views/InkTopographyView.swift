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
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    // Contours
                    let bands = 10
                    for b in 0..<bands {
                        let yBase = Double(b) / Double(bands - 1)
                        var path = Path()

                        for x in stride(from: 0.0, through: Double(size.width), by: 8.0) {
                            let nx = x / Double(size.width)
                            let n = DriftNoise.fbm(x: nx * 2.2 + t * 0.03, y: yBase * 2.0 + t * 0.02, seed: 42, octaves: 5)
                            let yy = yBase * Double(size.height) + (n - 0.5) * 90.0
                            let pt = CGPoint(x: x, y: yy)
                            if x == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                        }

                        let col: Color = (b % 2 == 0) ? config.palette.secondary : config.palette.primary
                        context.stroke(path, with: .color(col.opacity(0.14)), lineWidth: 1.1)
                    }
                }
                .blur(radius: 0.6)
            }
            .ignoresSafeArea()
        }
    }
}
