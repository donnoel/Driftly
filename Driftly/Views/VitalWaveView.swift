import SwiftUI

struct VitalWaveView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        ZStack {
            DriftLiquidLampView(
                palette: config.palette,
                blobCount: 6,
                blur: 52,
                energy: 0.85,
                speed: speed
            )

            DriftHeartbeatLine(
                color: config.palette.secondary,
                amplitude: 40,
                period: 10,
                speed: speed
            )
        }
    }
}
