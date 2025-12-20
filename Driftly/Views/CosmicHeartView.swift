import SwiftUI

struct CosmicHeartView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        ZStack {
            DriftLiquidLampView(
                palette: config.palette,
                blobCount: 5,
                blur: 50,
                energy: 0.90,
                speed: speed
            )
            .environment(\.driftAnimationsPaused, animationsPaused)

            DriftHeartbeatLine(
                color: Color.white.opacity(0.7),
                amplitude: 34,
                period: 9,
                speed: speed
            )
            .environment(\.driftAnimationsPaused, animationsPaused)
        }
    }
}
