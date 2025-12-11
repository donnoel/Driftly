import SwiftUI

private struct DriftAnimationSpeedKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

extension EnvironmentValues {
    /// Global animation speed multiplier for Driftly lamp views.
    var driftAnimationSpeed: Double {
        get { self[DriftAnimationSpeedKey.self] }
        set { self[DriftAnimationSpeedKey.self] = newValue }
    }
}
