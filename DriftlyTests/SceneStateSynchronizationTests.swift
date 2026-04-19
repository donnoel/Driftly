import Foundation
import Testing
@testable import Driftly

@MainActor
struct SceneStateSynchronizationTests {
    @Test func sceneActivationNormalizesOutOfRangePersistedAnimationSpeed() async throws {
        let suiteName = "SceneActivationNormalizeAnimationSpeed-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sceneID = UUID()
        let persistedScene = DriftScene(
            id: sceneID,
            name: "Persisted Out-of-Range Scene",
            modeIDs: [.auroraVeil, .cosmicTide],
            lastModeID: .auroraVeil,
            settings: DriftSceneSettings(
                brightness: 0.8,
                animationSpeed: 3.2,
                clockEnabled: false,
                preventAutoLock: false,
                autoDriftEnabled: false,
                autoDriftIntervalMinutes: 10,
                autoDriftShuffleEnabled: false
            ),
            updatedAt: Date(),
            deletedAt: nil
        )

        defaults.set(try JSONEncoder().encode([persistedScene]), forKey: "driftly.scenes")

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        engine.activateScene(id: sceneID)

        #expect(engine.animationSpeed == DriftlyEngine.clampAnimationSpeed(3.2))
        #expect(engine.availableScenes.first(where: { $0.id == sceneID })?.settings.animationSpeed == DriftlyEngine.clampAnimationSpeed(3.2))
    }

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

    @Test func activeSceneUpdateEditsApplyImmediatelyThroughSceneTransactionPath() async throws {
        let suiteName = "SceneUpdate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        engine.currentMode = .auroraVeil
        engine.brightness = 0.7
        engine.animationSpeed = 1.2

        let scene = engine.createScene(name: "Original", modeIDs: [.auroraVeil, .cosmicTide])
        engine.activateScene(id: scene.id)

        engine.currentMode = .lunarDrift
        engine.brightness = 0.42
        engine.animationSpeed = 0.8
        engine.updateScene(id: scene.id, name: "Edited", modeIDs: [.cosmicTide])

        #expect(engine.currentMode == .cosmicTide)
        #expect(engine.brightness == 0.42)
        #expect(engine.animationSpeed == 0.8)
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
