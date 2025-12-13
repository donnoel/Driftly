import SwiftUI

struct HorizonPulseView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * speed * 0.04

            LinearGradient(
                colors: [
                    config.palette.backgroundTop,
                    config.palette.primary.opacity(0.6),
                    config.palette.secondary.opacity(0.4),
                    config.palette.backgroundBottom
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.3 + 0.15 * sin(t)),
                endPoint: UnitPoint(x: 0.5, y: 1.0)
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 12), value: t)
        }
    }
}
