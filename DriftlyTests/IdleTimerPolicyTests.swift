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
        #expect(inactivePrevent == false)

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

    @Test func tvOSPreventAutoLockRespectsToggleAndState() async throws {
        let prevent = shouldPreventLockTvOS(
            preventAutoLock: true,
            sleepTimerAllowsLock: false,
            scenePhase: .active
        )
        #expect(prevent == true)

        let allowWhenToggleOff = shouldPreventLockTvOS(
            preventAutoLock: false,
            sleepTimerAllowsLock: false,
            scenePhase: .active
        )
        #expect(allowWhenToggleOff == false)

        let allowWhenSleepTimerAllows = shouldPreventLockTvOS(
            preventAutoLock: true,
            sleepTimerAllowsLock: true,
            scenePhase: .active
        )
        #expect(allowWhenSleepTimerAllows == false)

        let allowWhenInactive = shouldPreventLockTvOS(
            preventAutoLock: true,
            sleepTimerAllowsLock: false,
            scenePhase: .inactive
        )
        #expect(allowWhenInactive == false)
    }
}
