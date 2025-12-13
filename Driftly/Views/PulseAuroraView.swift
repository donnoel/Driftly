import SwiftUI

struct PulseAuroraView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        ZStack {
            DriftLiquidLampView(
                palette: config.palette,
                blobCount: 5,
                blur: 48,
                energy: 0.75,
                speed: speed
            )

            DriftHeartbeatLine(
                color: config.palette.primary,
                amplitude: 32,
                period: 12,
                speed: speed
            )
        }
    }
}
