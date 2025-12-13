import Foundation
import SwiftUI
import Testing
@testable import Driftly

struct SleepAndDriftControllerTests {

    @Test func expiresAndAllowsLockWhenTimerFires() async throws {
        let suiteName = "SleepTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults)
        engine.setSleepTimer(minutes: 1)

        var state = SleepAndDriftController.State(
            sleepTimerHasExpired: false,
            sleepTimerAllowsLock: false,
            lastAutoDriftChange: .distantPast
        )

        let now = Date().addingTimeInterval(60)
        let actions = SleepAndDriftController.handleTick(now: now, engine: engine, state: &state)

        #expect(actions.contains(.expire))
        #expect(state.sleepTimerHasExpired == true)
        #expect(state.sleepTimerAllowsLock == true)
        #expect(engine.sleepTimerEndDate == nil)
    }

    @Test func clearsExpirationWhenTimerRemoved() async throws {
        let suiteName = "SleepTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults)
        engine.setSleepTimer(minutes: nil)

        var state = SleepAndDriftController.State(
            sleepTimerHasExpired: true,
            sleepTimerAllowsLock: true,
            lastAutoDriftChange: .distantPast
        )

        let actions = SleepAndDriftController.handleTick(now: Date(), engine: engine, state: &state)

        #expect(actions.contains(.wake))
        #expect(state.sleepTimerHasExpired == false)
        #expect(state.sleepTimerAllowsLock == false)
    }

    @Test func triggersAutoDriftAfterInterval() async throws {
        let suiteName = "AutoDrift-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults)
        engine.autoDriftEnabled = true
        engine.autoDriftIntervalMinutes = 3

        var state = SleepAndDriftController.State(
            sleepTimerHasExpired: false,
            sleepTimerAllowsLock: false,
            lastAutoDriftChange: Date()
        )

        let now = state.lastAutoDriftChange.addingTimeInterval(3 * 60 + 1)

        let actions = SleepAndDriftController.handleTick(
            now: now,
            engine: engine,
            state: &state
        )
        #expect(actions.contains(.autoDrift))
        #expect(state.lastAutoDriftChange == now)
    }

    @Test func tickStopsAfterSleepExpiration() async throws {
        let suiteName = "TickStop-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults)
        engine.setSleepTimer(minutes: 1)

        var state = SleepAndDriftController.State(
            sleepTimerHasExpired: false,
            sleepTimerAllowsLock: false,
            lastAutoDriftChange: .distantPast
        )

        // First tick: expire
        _ = SleepAndDriftController.handleTick(
            now: Date().addingTimeInterval(60),
            engine: engine,
            state: &state
        )

        #expect(state.sleepTimerHasExpired == true)
        #expect(SleepAndDriftController.shouldTick(engine: engine, state: state) == false)
    }
}
