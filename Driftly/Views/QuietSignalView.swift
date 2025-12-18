import SwiftUI

struct QuietSignalView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        if animationsPaused {
            scene(t: 0)
        } else {
            TimelineView(.animation) { timeline in
                scene(t: timeline.date.timeIntervalSinceReferenceDate * speed)
            }
        }
    }

    private func scene(t: Double) -> some View {
        Canvas { context, size in
            let midY = size.height * 0.5
            var path = Path()
            path.move(to: CGPoint(x: 0, y: midY))

            for x in stride(from: 0, through: size.width, by: 6) {
                let y = midY + 18 * sin(Double(x) * 0.02 + t * 0.6)
                path.addLine(to: CGPoint(x: x, y: y))
            }

            context.stroke(
                path,
                with: .color(config.palette.secondary.opacity(0.35)),
                lineWidth: 1.1
            )
        }
        .background(config.palette.backgroundTop)
        .ignoresSafeArea()
    }
}
