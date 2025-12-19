import Foundation
import Testing
@testable import Driftly

@MainActor
struct SceneSyncTests {
    private let scenesKey = "driftly.scenes"

    @Test func loadsScenesFromCloudOnInit() async throws {
        let suiteName = "SceneCloud-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let mockStore = MockUbiquitousKeyValueStore()

        let scene = DriftScene(
            id: UUID(),
            name: "Cloud Scene",
            modeIDs: [.auroraVeil, .cosmicTide],
            lastModeID: .cosmicTide,
            settings: DriftSceneSettings(
                brightness: 0.75,
                animationSpeed: 1.1,
                clockEnabled: true,
                preventAutoLock: false,
                autoDriftEnabled: true,
                autoDriftIntervalMinutes: 5,
                autoDriftShuffleEnabled: true
            ),
            updatedAt: Date(timeIntervalSince1970: 12345),
            deletedAt: nil
        )

        if let data = try? JSONEncoder().encode([scene]) {
            mockStore.storage[scenesKey] = data
        }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: mockStore)

        #expect(engine.scenes.contains(scene))

        let storedData = defaults.data(forKey: scenesKey)
        let decoded = storedData.flatMap { try? JSONDecoder().decode([DriftScene].self, from: $0) }
        #expect(decoded?.contains(scene) == true)
    }
}
