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
                    let A = min(size.width, size.height) * 0.34
                    let B = min(size.width, size.height) * 0.26

                    for i in 0..<520 {
                        let u = Double(i) / 519.0 * Double.pi * 2
                        let x = center.x + CGFloat(A * sin(3*u + t*0.06) + 0.12*A * sin(7*u + t*0.05))
                        let y = center.y + CGFloat(B * sin(2*u + t*0.07) + 0.12*B * cos(5*u + t*0.06))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }

                    context.stroke(path, with: .color(config.palette.primary.opacity(0.16)), lineWidth: 18)
                    context.stroke(path, with: .color(config.palette.secondary.opacity(0.14)), lineWidth: 10)
                    context.stroke(path, with: .color(Color.white.opacity(0.07)), lineWidth: 2.2)
                }
                .blur(radius: 1.2)
            }
            .ignoresSafeArea()
        }
    }
}
