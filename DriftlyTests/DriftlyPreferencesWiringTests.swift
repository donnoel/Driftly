import Foundation
import Testing
@testable import Driftly

@MainActor
struct DriftlyPreferencesWiringTests {
    @Test func preferencesMutationsUpdateEngineAndActiveSceneSnapshot() async throws {
        let suiteName = "PreferencesSceneWiring-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        let scene = engine.createScene(name: "Scene", modeIDs: [.auroraVeil, .cosmicTide])

        engine.preferences.animationSpeed = 1.35
        engine.preferences.preventAutoLock = true
        engine.preferences.clockEnabled = true
        engine.preferences.brightness = 0.62

        #expect(engine.animationSpeed == 1.35)
        #expect(engine.preventAutoLock == true)
        #expect(engine.clockEnabled == true)
        #expect(engine.brightness == 0.62)

        let updatedScene = engine.availableScenes.first(where: { $0.id == scene.id })
        #expect(updatedScene?.settings.animationSpeed == 1.35)
        #expect(updatedScene?.settings.preventAutoLock == true)
        #expect(updatedScene?.settings.clockEnabled == true)
        #expect(updatedScene?.settings.brightness == 0.62)
    }

    @Test func preferencesMutationsPersistToDefaultsThroughEngineWiring() async throws {
        let suiteName = "PreferencesPersistWiring-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        engine.preferences.isChromeVisible = false
        engine.preferences.animationSpeed = 1.4
        engine.preferences.respectSystemReduceMotion = false
        engine.preferences.preventAutoLock = true
        engine.preferences.clockEnabled = true
        engine.preferences.brightness = 0.58

        #expect(defaults.bool(forKey: "driftly.isChromeVisible") == false)
        #expect(defaults.double(forKey: "driftly.animationSpeed") == 1.4)
        #expect(defaults.bool(forKey: "driftly.respectReduceMotion") == false)
        #expect(defaults.bool(forKey: "driftly.preventAutoLock") == true)
        #expect(defaults.bool(forKey: "driftly.clockEnabled") == true)

        try await waitForBrightnessPersistence(defaults: defaults, expected: 0.58)
    }

    private func waitForBrightnessPersistence(defaults: UserDefaults, expected: Double) async throws {
        for _ in 0..<20 {
            if abs(defaults.double(forKey: "driftly.brightness") - expected) < 0.0001 {
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(abs(defaults.double(forKey: "driftly.brightness") - expected) < 0.0001)
    }
}
