import SwiftUI

struct EchoBloomView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        ZStack {
            DriftLiquidLampView(
                palette: config.palette,
                blobCount: 4,
                blur: 60,
                energy: 0.60,
                speed: speed
            )

            DriftHeartbeatLine(
                color: config.palette.tertiary,
                amplitude: 26,
                period: 14,
                speed: speed
            )
        }
    }
}
