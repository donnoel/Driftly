import SwiftUI

struct RibbonOrbitView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size
                let c = CGPoint(x: size.width * 0.5, y: size.height * 0.52)

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
                    let a = min(size.width, size.height) * 0.34
                    let b = min(size.width, size.height) * 0.22

                    for i in 0..<240 {
                        let u = Double(i) / 239.0 * Double.pi * 2
                        let x = c.x + CGFloat(a * cos(u + t * 0.08) + 0.25 * a * sin(2*u + t * 0.12))
                        let y = c.y + CGFloat(b * sin(u + t * 0.10) + 0.18 * b * cos(3*u + t * 0.09))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }

                    context.stroke(path, with: .color(config.palette.tertiary.opacity(0.16)), lineWidth: 26)
                    context.stroke(path, with: .color(config.palette.primary.opacity(0.18)), lineWidth: 14)
                    context.stroke(path, with: .color(Color.white.opacity(0.08)), lineWidth: 2.2)
                }
                .blur(radius: 1.4)
            }
            .ignoresSafeArea()
        }
    }
}
