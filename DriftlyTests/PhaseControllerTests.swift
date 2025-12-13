import Foundation
import Testing
@testable import Driftly

@MainActor
struct PhaseControllerTests {

    @Test func resumesSmoothlyAfterPause() async throws {
        var controller = PhaseController()
        let start = Date()
        let cycle: TimeInterval = 20

        // Advance some time while running
        let t1 = controller.phase(for: start.addingTimeInterval(5), speed: 1.0, cycleDuration: cycle, paused: false)

        // Pause and sample
        let pausedPhase = controller.phase(for: start.addingTimeInterval(8), speed: 1.0, cycleDuration: cycle, paused: true)
        #expect(abs(pausedPhase - (t1 + (3 / cycle))) < 0.001)

        // Resume later; the phase should continue from pausedPhase (frozen during pause)
        let resumed = controller.phase(for: start.addingTimeInterval(12), speed: 1.0, cycleDuration: cycle, paused: false)
        #expect(abs(resumed - pausedPhase) < 0.001)
    }
}
