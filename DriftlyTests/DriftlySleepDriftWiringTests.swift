import Foundation
import Testing
@testable import Driftly

@MainActor
struct DriftlySleepDriftWiringTests {
    @Test func sleepDriftMutationsUpdateEngineAndActiveSceneSnapshot() async throws {
        let suiteName = "SleepDriftSceneWiring-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        let scene = engine.createScene(name: "Scene", modeIDs: [.auroraVeil, .cosmicTide])

        engine.sleepDrift.autoDriftEnabled = true
        engine.sleepDrift.autoDriftIntervalMinutes = 5
        engine.sleepDrift.autoDriftShuffleEnabled = true

        #expect(engine.autoDriftEnabled == true)
        #expect(engine.autoDriftIntervalMinutes == 5)
        #expect(engine.autoDriftShuffleEnabled == true)

        let updatedScene = engine.availableScenes.first(where: { $0.id == scene.id })
        #expect(updatedScene?.settings.autoDriftEnabled == true)
        #expect(updatedScene?.settings.autoDriftIntervalMinutes == 5)
        #expect(updatedScene?.settings.autoDriftShuffleEnabled == true)
    }

    @Test func sleepDriftMutationsPersistToDefaultsThroughEngineWiring() async throws {
        let suiteName = "SleepDriftPersistWiring-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        engine.sleepDrift.autoDriftEnabled = true
        engine.sleepDrift.autoDriftIntervalMinutes = 10
        engine.sleepDrift.autoDriftShuffleEnabled = true
        engine.sleepDrift.autoDriftSource = .favorites

        #expect(defaults.bool(forKey: "driftly.autoDriftEnabled") == true)
        #expect(defaults.integer(forKey: "driftly.autoDriftIntervalMins") == 10)
        #expect(defaults.bool(forKey: "driftly.autoDriftShuffle") == true)

        let storedSourceData = defaults.data(forKey: "driftly.autoDriftSource")
        let storedSource = try JSONDecoder().decode(AutoDriftSource.self, from: #require(storedSourceData))
        #expect(storedSource == .favorites)
    }

    @Test func sleepDriftSourceValidationFallsBackWhenSceneIsUnavailable() async throws {
        let suiteName = "SleepDriftSourceValidation-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)

        engine.sleepDrift.autoDriftSource = .scene(UUID())

        #expect(engine.sleepDrift.autoDriftSource == .all)
    }
}
