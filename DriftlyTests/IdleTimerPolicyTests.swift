import SwiftUI
import Testing
@testable import Driftly

struct IdleTimerPolicyTests {

    @Test func preventsLockOnlyWhenActiveAndAllowed() async throws {
        let activePrevent = shouldPreventLock(
            preventAutoLock: true,
            sleepTimerAllowsLock: false,
            scenePhase: .active
        )
        #expect(activePrevent == true)

        let inactivePrevent = shouldPreventLock(
            preventAutoLock: true,
            sleepTimerAllowsLock: false,
            scenePhase: .inactive
        )
        #expect(inactivePrevent == true)

        let sleepAllowsLock = shouldPreventLock(
            preventAutoLock: true,
            sleepTimerAllowsLock: true,
            scenePhase: .active
        )
        #expect(sleepAllowsLock == false)

        let backgroundAllowsLock = shouldPreventLock(
            preventAutoLock: true,
            sleepTimerAllowsLock: false,
            scenePhase: .background
        )
        #expect(backgroundAllowsLock == false)
    }
}
