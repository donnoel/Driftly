import SwiftUI

/// Centralizes the decision for whether to disable idle timer so it can be tested.
func shouldPreventLock(
    preventAutoLock: Bool,
    sleepTimerAllowsLock: Bool,
    scenePhase: ScenePhase
) -> Bool {
    preventAutoLock && !sleepTimerAllowsLock && scenePhase != .background
}
