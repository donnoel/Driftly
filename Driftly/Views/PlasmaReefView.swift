import SwiftUI

struct PlasmaReefView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        DriftLiquidLampView(
            palette: config.palette,
            blobCount: 6,
            blur: 52,
            energy: 0.75,
            speed: speed
        )
    }
}
