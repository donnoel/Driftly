import SwiftUI

private struct DriftAnimationPausedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var driftAnimationsPaused: Bool {
        get { self[DriftAnimationPausedKey.self] }
        set { self[DriftAnimationPausedKey.self] = newValue }
    }
}
