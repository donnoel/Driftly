import SwiftUI

struct VelvetEclipseView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        DriftLiquidLampView(
            palette: config.palette,
            blobCount: 4,
            blur: 62,
            energy: 0.60,
            speed: speed
        )
    }
}
