import Foundation
import Testing
@testable import Driftly

struct PhaseControllerTests {

    @Test func resumesSmoothlyAfterPause() async throws {
        var controller = PhaseController()
        let start = Date()
        let cycle: TimeInterval = 20

        // Advance some time while running
        let t1 = controller.phase(for: start.addingTimeInterval(5), speed: 1.0, cycleDuration: cycle, paused: false)

        // Pause and sample
        let pausedPhase = controller.phase(for: start.addingTimeInterval(8), speed: 1.0, cycleDuration: cycle, paused: true)
        #expect(pausedPhase == t1 + (3 / cycle))

        // Resume later; the phase should continue without jumping
        let resumed = controller.phase(for: start.addingTimeInterval(12), speed: 1.0, cycleDuration: cycle, paused: false)
        #expect(resumed == pausedPhase + (4 / cycle))
    }
}
