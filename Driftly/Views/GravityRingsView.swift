import SwiftUI

struct GravityRingsView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * speed * 0.2

            ZStack {
                config.palette.backgroundTop.ignoresSafeArea()

                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .stroke(
                            config.palette.secondary.opacity(0.15),
                            lineWidth: 1.4
                        )
                        .scaleEffect(0.3 + CGFloat(i) * 0.18 + 0.05 * sin(t + Double(i)))
                }
            }
        }
    }
}
