import Foundation
import Testing
@testable import Driftly

struct AutoDriftTests {

    @Test func respectsIntervalAndSleepState() async throws {
        let suiteName = "AutoDriftTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults)
        engine.autoDriftEnabled = true
        engine.autoDriftIntervalMinutes = 5

        let start = Date()
        let almost = start.addingTimeInterval(4 * 60)
        let elapsed = start.addingTimeInterval(5 * 60 + 1)

        #expect(engine.shouldAutoDrift(now: almost, lastChange: start, sleepTimerHasExpired: false) == false)
        #expect(engine.shouldAutoDrift(now: elapsed, lastChange: start, sleepTimerHasExpired: false) == true)
        #expect(engine.shouldAutoDrift(now: elapsed, lastChange: start, sleepTimerHasExpired: true) == false)
    }
}
