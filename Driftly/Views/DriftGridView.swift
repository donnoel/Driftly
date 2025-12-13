import SwiftUI

struct DriftGridView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * speed * 0.15

            Canvas { context, size in
                let step: CGFloat = 48

                for x in stride(from: 0, through: size.width, by: step) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + 8 * sin(t + Double(x)), y: size.height))

                    context.stroke(
                        path,
                        with: .color(config.palette.primary.opacity(0.15)),
                        lineWidth: 0.6
                    )
                }
            }
            .background(config.palette.backgroundBottom)
            .ignoresSafeArea()
        }
    }
}
