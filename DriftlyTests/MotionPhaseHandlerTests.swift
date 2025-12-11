import SwiftUI
import Testing
@testable import Driftly

struct MotionPhaseHandlerTests {

    final class MotionSpy: MotionControlling {
        private(set) var startCalls = 0
        private(set) var stopCalls = 0

        func startIfNeeded() {
            startCalls += 1
        }

        func stopUpdates() {
            stopCalls += 1
        }
    }

    @Test func startsOnlyWhenActive() async throws {
        let spy = MotionSpy()

        MotionPhaseHandler.updateMotion(for: .inactive, motionController: spy)
        MotionPhaseHandler.updateMotion(for: .background, motionController: spy)
        MotionPhaseHandler.updateMotion(for: .active, motionController: spy)

        #expect(spy.startCalls == 1)
        #expect(spy.stopCalls == 2)
    }
}
