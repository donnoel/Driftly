import Foundation
import SwiftUI
import Testing
@testable import Driftly

@MainActor
struct DriftlyRootCoordinatorSleepStateTests {
    private final class TestClock {
        var now: Date
        init(now: Date) { self.now = now }
        func advance(by seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

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

    @Test func scenePhaseResumeAccountsForPausedDuration() async throws {
        let suiteName = "CoordinatorPauseResumeAccounting-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let base = Date(timeIntervalSinceReferenceDate: 10_000)
        let clock = TestClock(now: base)
        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        let coordinator = DriftlyRootCoordinator(nowProvider: { clock.now })
        engine.autoDriftEnabled = true
        engine.autoDriftIntervalMinutes = 5

        coordinator.sleepState.lastAutoDriftChange = base.addingTimeInterval(-120)
        coordinator.handleScenePhaseChange(to: .inactive)

        clock.advance(by: 30)
        coordinator.handleScenePhaseChange(to: .active)

        let expectedLastChange = base.addingTimeInterval(-90)
        #expect(abs(coordinator.sleepState.lastAutoDriftChange.timeIntervalSince(expectedLastChange)) < 0.001)
    }

    @Test func scenePhaseResumeDoesNotSpuriouslyAutoDriftWhenStillWithinInterval() async throws {
        let suiteName = "CoordinatorPauseResumeNoSpuriousFire-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let base = Date(timeIntervalSinceReferenceDate: 20_000)
        let clock = TestClock(now: base)
        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        let coordinator = DriftlyRootCoordinator(nowProvider: { clock.now })
        engine.autoDriftEnabled = true
        engine.autoDriftIntervalMinutes = 5
        engine.currentMode = .auroraVeil
        coordinator.sleepState.lastAutoDriftChange = base.addingTimeInterval(-120)

        coordinator.handleScenePhaseChange(to: .background)
        clock.advance(by: 45)
        coordinator.handleScenePhaseChange(to: .active)
        coordinator.updateAutoDriftScheduling(engine: engine, scenePhase: .active)

        #expect(engine.currentMode == .auroraVeil)
    }

    @Test func scenePhaseResumeAllowsImmediateAutoDriftWhenAlreadyDue() async throws {
        let suiteName = "CoordinatorPauseResumeImmediateWhenDue-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let base = Date(timeIntervalSinceReferenceDate: 30_000)
        let clock = TestClock(now: base)
        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        let coordinator = DriftlyRootCoordinator(nowProvider: { clock.now })
        engine.autoDriftEnabled = true
        engine.autoDriftShuffleEnabled = false
        engine.autoDriftIntervalMinutes = 5
        engine.currentMode = .auroraVeil
        coordinator.sleepState.lastAutoDriftChange = base.addingTimeInterval(-400)

        coordinator.handleScenePhaseChange(to: .inactive)
        clock.advance(by: 30)
        coordinator.handleScenePhaseChange(to: .active)
        coordinator.updateAutoDriftScheduling(engine: engine, scenePhase: .active)

        #expect(engine.currentMode != .auroraVeil)
    }
}
