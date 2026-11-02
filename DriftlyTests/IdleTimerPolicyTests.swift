import SwiftUI
import Testing
@testable import Driftly

struct IdleTimerPolicyTests {

    @Test func preventsLockOnlyWhenActiveAndAllowed() async throws {
        let activePrevent = await shouldPreventLock(
            preventAutoLock: true,
            sleepTimerAllowsLock: false,
            scenePhase: .active
        )
        #expect(activePrevent == true)

        let inactivePrevent = await shouldPreventLock(
            preventAutoLock: true,
            sleepTimerAllowsLock: false,
            scenePhase: .inactive
        )
        #expect(inactivePrevent == false)

        let sleepAllowsLock = await shouldPreventLock(
            preventAutoLock: true,
            sleepTimerAllowsLock: true,
            scenePhase: .active
        )
        #expect(sleepAllowsLock == false)

        let backgroundAllowsLock = await shouldPreventLock(
            preventAutoLock: true,
            sleepTimerAllowsLock: false,
            scenePhase: .background
        )
        #expect(backgroundAllowsLock == false)
    }

    @Test func tvOSPreventAutoLockRespectsToggleAndState() async throws {
        let prevent = await shouldPreventLockTvOS(
            preventAutoLock: true,
            sleepTimerAllowsLock: false,
            scenePhase: .active
        )
        #expect(prevent == true)

        let allowWhenToggleOff = await shouldPreventLockTvOS(
            preventAutoLock: false,
            sleepTimerAllowsLock: false,
            scenePhase: .active
        )
        #expect(allowWhenToggleOff == false)

        let allowWhenSleepTimerAllows = await shouldPreventLockTvOS(
            preventAutoLock: true,
            sleepTimerAllowsLock: true,
            scenePhase: .active
        )
        #expect(allowWhenSleepTimerAllows == false)

        let allowWhenInactive = await shouldPreventLockTvOS(
            preventAutoLock: true,
            sleepTimerAllowsLock: false,
            scenePhase: .inactive
        )
        #expect(allowWhenInactive == false)
    }
}
