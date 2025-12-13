import SwiftUI

struct NeonKelpView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        DriftLiquidLampView(
            palette: config.palette,
            blobCount: 7,
            blur: 44,
            energy: 0.95,
            speed: speed
        )
    }
}
