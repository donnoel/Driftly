import SwiftUI

struct DriftHeartbeatLine: View {
    let color: Color
    let amplitude: CGFloat
    let period: Double
    let speed: Double
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        if animationsPaused {
            scene(t: 0)
        } else {
            TimelineView(.animation) { timeline in
                scene(t: timeline.date.timeIntervalSinceReferenceDate * max(0.25, speed))
            }
        }
    }

    private func scene(t: Double) -> some View {
        Canvas { context, size in
            let midY = size.height * 0.5
            let width = size.width

            var path = Path()
            path.move(to: CGPoint(x: 0, y: midY))

            let step: CGFloat = 6

            for x in stride(from: 0, through: width, by: step) {
                let phase = (Double(x) / Double(width)) * .pi * 2
                let pulse =
                    sin((t / period + phase) * .pi * 2) *
                    exp(-abs(phase - .pi))

                let y = midY - CGFloat(pulse) * amplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }

            context.stroke(
                path,
                with: .color(color),
                lineWidth: 1.2
            )
        }
        .blendMode(.screen)
        .opacity(0.35)
        .blur(radius: 1.5)
        .ignoresSafeArea()
    }
}
