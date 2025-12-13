import SwiftUI

struct EmberDriftView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        DriftLiquidLampView(
            palette: config.palette,
            blobCount: 5,
            blur: 54,
            energy: 0.90,
            speed: speed
        )
    }
}
