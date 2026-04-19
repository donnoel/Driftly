import Foundation
import SwiftUI
import Testing
@testable import Driftly

@MainActor
struct DriftlyRootCoordinatorSleepStateTests {
    @Test func applySleepTimerSelectionResetsCoordinatorSleepState() async throws {
        let suiteName = "CoordinatorSleepApply-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        let coordinator = DriftlyRootCoordinator()
        coordinator.sleepState.sleepTimerHasExpired = true
        coordinator.sleepState.sleepTimerAllowsLock = true

        coordinator.applySleepTimerSelection(minutes: 15, engine: engine, scenePhase: .active)

        #expect(engine.sleepTimerEndDate != nil)
        #expect(coordinator.sleepState.sleepTimerHasExpired == false)
        #expect(coordinator.sleepState.sleepTimerAllowsLock == false)
    }

    @Test func wakeFromSleepResetsFlagsAndAutoDriftClock() async throws {
        let suiteName = "CoordinatorSleepWake-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        let coordinator = DriftlyRootCoordinator()
        coordinator.sleepState.sleepTimerHasExpired = true
        coordinator.sleepState.sleepTimerAllowsLock = true
        coordinator.sleepState.lastAutoDriftChange = .distantPast

        coordinator.wakeFromSleep(engine: engine, scenePhase: .active)

        #expect(coordinator.sleepState.sleepTimerHasExpired == false)
        #expect(coordinator.sleepState.sleepTimerAllowsLock == false)
        #expect(coordinator.sleepState.lastAutoDriftChange > Date.distantPast)
    }

    @Test func processSleepTimerTickExpiresThroughCoordinatorOwnedPath() async throws {
        let suiteName = "CoordinatorSleepTick-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        let coordinator = DriftlyRootCoordinator()
        engine.setSleepTimer(minutes: 1)

        let transition = coordinator.processSleepTimerTick(
            now: Date().addingTimeInterval(60),
            engine: engine,
            scenePhase: .active
        )

        #expect(transition == .expired)
        #expect(engine.sleepTimerEndDate == nil)
        #expect(coordinator.sleepState.sleepTimerHasExpired == true)
        #expect(coordinator.sleepState.sleepTimerAllowsLock == true)
    }
}
