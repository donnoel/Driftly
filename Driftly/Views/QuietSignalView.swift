import SwiftUI

struct QuietSignalView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        ZStack {
            backgroundLayer
            if animationsPaused {
                scene(t: 0)
            } else {
                TimelineView(.periodic(from: .now, by: 1.0 / 60.0)) { timeline in
                    scene(t: timeline.date.timeIntervalSinceReferenceDate * speed)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                config.palette.backgroundTop,
                config.palette.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            RadialGradient(
                colors: [
                    config.palette.primary.opacity(0.10),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.54),
                startRadius: 0,
                endRadius: 380
            )
        )
        .overlay(
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.22)
                ],
                center: .center,
                startRadius: 120,
                endRadius: 760
            )
        )
    }

    private func scene(t: Double) -> some View {
        Canvas { context, size in
            let midY = size.height * 0.5
            let phase = t * 0.34
            let amplitude = min(size.height * 0.028, 16)
            let secondaryAmplitude = amplitude * 0.58
            var primaryPath = Path()
            var secondaryPath = Path()
            primaryPath.move(to: CGPoint(x: 0, y: midY))
            secondaryPath.move(to: CGPoint(x: 0, y: midY + size.height * 0.022))

            for x in stride(from: 0, through: size.width, by: 5) {
                let xPhase = Double(x) * 0.0108
                let yPrimary = midY
                    + amplitude * sin(xPhase + phase)
                    + amplitude * 0.28 * sin(xPhase * 0.48 + phase * 0.67)
                let ySecondary = midY + size.height * 0.022
                    + secondaryAmplitude * sin(xPhase * 0.82 + phase * 0.76 + 1.4)

                primaryPath.addLine(to: CGPoint(x: x, y: yPrimary))
                secondaryPath.addLine(to: CGPoint(x: x, y: ySecondary))
            }

            context.stroke(
                secondaryPath,
                with: .color(config.palette.primary.opacity(0.12)),
                lineWidth: 0.9
            )
            context.stroke(
                primaryPath,
                with: .color(config.palette.secondary.opacity(0.26)),
                lineWidth: 1.0
            )
        }
    }
}
