import SwiftUI

struct CosmicHeartView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        ZStack {
            DriftLiquidLampView(
                palette: config.palette,
                blobCount: 5,
                blur: 50,
                energy: 0.90,
                speed: speed
            )

            DriftHeartbeatLine(
                color: Color.white.opacity(0.7),
                amplitude: 34,
                period: 9,
                speed: speed
            )
        }
    }
}
