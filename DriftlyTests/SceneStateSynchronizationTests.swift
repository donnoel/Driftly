import Foundation
import Testing
@testable import Driftly

@MainActor
struct SceneStateSynchronizationTests {
    @Test func sceneActivationAppliesCapturedSettingsThroughSinglePath() async throws {
        let suiteName = "SceneActivation-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)

        engine.currentMode = .auroraVeil
        engine.brightness = 0.72
        engine.animationSpeed = 1.25
        engine.clockEnabled = true
        engine.preventAutoLock = true
        engine.autoDriftEnabled = true
        engine.autoDriftIntervalMinutes = 5
        engine.autoDriftShuffleEnabled = true
        let sceneA = engine.createScene(name: "Scene A", modeIDs: [.auroraVeil, .cosmicTide])
        engine.activeSceneID = nil

        engine.currentMode = .nebulaLake
        engine.brightness = 0.44
        engine.animationSpeed = 0.7
        engine.clockEnabled = false
        engine.preventAutoLock = false
        engine.autoDriftEnabled = false
        engine.autoDriftIntervalMinutes = 15
        engine.autoDriftShuffleEnabled = false
        _ = engine.createScene(name: "Scene B", modeIDs: [.nebulaLake, .lunarDrift])

        engine.activateScene(id: sceneA.id)

        #expect(engine.activeSceneID == sceneA.id)
        #expect(engine.autoDriftSource == .scene(sceneA.id))
        #expect(engine.currentMode == .auroraVeil)
        #expect(engine.brightness == 0.72)
        #expect(engine.animationSpeed == 1.25)
        #expect(engine.clockEnabled == true)
        #expect(engine.preventAutoLock == true)
        #expect(engine.autoDriftEnabled == true)
        #expect(engine.autoDriftIntervalMinutes == 5)
        #expect(engine.autoDriftShuffleEnabled == true)
    }

    @Test func sceneUpdateEditsAffectSubsequentActivationDeterministically() async throws {
        let suiteName = "SceneUpdate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        engine.currentMode = .auroraVeil

        let scene = engine.createScene(name: "Original", modeIDs: [.auroraVeil, .cosmicTide])
        engine.updateScene(id: scene.id, name: "Edited", modeIDs: [.cosmicTide])

        engine.activateScene(id: scene.id)

        #expect(engine.currentMode == .cosmicTide)
        #expect(engine.availableScenes.contains(where: { $0.id == scene.id && $0.name == "Edited" }))
    }

    @Test func deletingSceneFallsBackForActiveAndInvalidSceneSource() async throws {
        let suiteName = "SceneDeleteFallback-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)

        engine.currentMode = .auroraVeil
        let sceneA = engine.createScene(name: "A", modeIDs: [.auroraVeil, .cosmicTide])

        engine.currentMode = .lunarDrift
        let sceneB = engine.createScene(name: "B", modeIDs: [.lunarDrift, .nebulaLake])

        engine.activateScene(id: sceneA.id)
        engine.autoDriftSource = .scene(sceneB.id)

        engine.deleteScene(id: sceneB.id)

        #expect(engine.activeSceneID == sceneA.id)
        #expect(engine.autoDriftSource == .all)

        engine.deleteScene(id: sceneA.id)

        #expect(engine.activeSceneID == nil)
        #expect(engine.autoDriftSource == .all)
    }
}
