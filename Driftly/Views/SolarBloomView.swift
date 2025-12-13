import SwiftUI

struct SolarBloomView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        DriftLiquidLampView(
            palette: config.palette,
            blobCount: 5,
            blur: 46,
            energy: 0.85,
            speed: speed
        )
    }
}
