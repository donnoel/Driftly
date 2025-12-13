import SwiftUI

struct SignalDriftView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        ZStack {
            DriftLiquidLampView(
                palette: config.palette,
                blobCount: 7,
                blur: 46,
                energy: 0.95,
                speed: speed
            )

            DriftHeartbeatLine(
                color: config.palette.primary.opacity(0.85),
                amplitude: 44,
                period: 11,
                speed: speed
            )
        }
    }
}
