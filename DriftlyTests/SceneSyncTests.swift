import Foundation
import Testing
@testable import Driftly

@MainActor
struct SceneSyncTests {
    private let scenesKey = "driftly.scenes"
    private let payloadVersion = 1

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
        let storedObject = try #require(storedData).jsonObject()
        let storedVersion = storedObject["version"] as? Int
        let storedScenes = storedObject["scenes"] as? [[String: Any]]
        #expect(storedVersion == payloadVersion)
        #expect((storedScenes?.isEmpty == false))
    }

    @Test func persistsScenesUsingVersionedEnvelopeRoundTrip() async throws {
        let suiteName = "SceneVersionedRoundTrip-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        let scene = engine.createScene(name: "Local Scene", modeIDs: [.auroraVeil, .cosmicTide])
        engine.flushPendingScenePersistence()

        let storedData = try await waitForScenesPersistence(defaults: defaults)
        let storedObject = try storedData.jsonObject()
        #expect(storedObject["version"] as? Int == payloadVersion)
        #expect((storedObject["scenes"] as? [[String: Any]])?.isEmpty == false)

        let reloaded = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        #expect(reloaded.scenes.contains(where: { $0.id == scene.id }))
    }

    @Test func keepsLocalScenesAndPreservesInvalidCloudPayloadOnInit() async throws {
        let suiteName = "SceneInvalidCloudPayload-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let localScene = DriftScene(
            id: UUID(),
            name: "Local Fallback",
            modeIDs: [.nebulaLake, .lunarDrift],
            lastModeID: .nebulaLake,
            settings: DriftSceneSettings(
                brightness: 0.72,
                animationSpeed: 1.0,
                clockEnabled: false,
                preventAutoLock: false,
                autoDriftEnabled: false,
                autoDriftIntervalMinutes: 15,
                autoDriftShuffleEnabled: false
            ),
            updatedAt: Date(timeIntervalSince1970: 111),
            deletedAt: nil
        )
        defaults.set(try JSONEncoder().encode([localScene]), forKey: scenesKey)

        let mockStore = MockUbiquitousKeyValueStore()
        let invalidCloudData = Data("not-a-valid-scene-payload".utf8)
        mockStore.storage[scenesKey] = invalidCloudData

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: mockStore)

        #expect(engine.scenes.contains(where: { $0.id == localScene.id }))
        #expect((mockStore.storage[scenesKey] as? Data) == invalidCloudData)
    }

    @Test func keepsLocalScenesAndPreservesUnsupportedVersionCloudPayloadOnInit() async throws {
        let suiteName = "SceneUnsupportedVersionCloudPayload-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sceneID = UUID()
        let localScene = makeScene(
            id: sceneID,
            name: "Local Scene",
            updatedAt: Date(timeIntervalSince1970: 250)
        )
        let localData = try JSONEncoder().encode([localScene])
        defaults.set(localData, forKey: scenesKey)

        let unsupportedEnvelope = TestSceneEnvelope(version: 999, scenes: [
            makeScene(
                id: sceneID,
                name: "Remote Unsupported",
                updatedAt: Date(timeIntervalSince1970: 999)
            )
        ])
        let unsupportedCloudData = try JSONEncoder().encode(unsupportedEnvelope)

        let mockStore = MockUbiquitousKeyValueStore()
        mockStore.storage[scenesKey] = unsupportedCloudData

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: mockStore)

        #expect(engine.scenes.contains(where: { $0.id == localScene.id && $0.name == "Local Scene" }))
        #expect((mockStore.storage[scenesKey] as? Data) == unsupportedCloudData)
        #expect(defaults.data(forKey: scenesKey) == localData)
    }

    @Test func mergePrefersNewerNonDeletedSceneBetweenCloudAndLocal() async throws {
        let suiteName = "SceneMergePrefersNewerNonDeleted-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sceneID = UUID()
        let localOlder = makeScene(
            id: sceneID,
            name: "Local Older",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        defaults.set(try JSONEncoder().encode([localOlder]), forKey: scenesKey)

        let remoteNewer = makeScene(
            id: sceneID,
            name: "Cloud Newer",
            updatedAt: Date(timeIntervalSince1970: 500)
        )
        let mockStore = MockUbiquitousKeyValueStore()
        mockStore.storage[scenesKey] = try JSONEncoder().encode(TestSceneEnvelope(version: payloadVersion, scenes: [remoteNewer]))

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: mockStore)

        #expect(engine.scenes.count == 1)
        #expect(engine.scenes.first?.id == sceneID)
        #expect(engine.scenes.first?.name == "Cloud Newer")
    }

    @Test func mergeHonorsDeletionPrecedenceWhenDeletionIsNewestEvent() async throws {
        let suiteName = "SceneMergeDeletionPrecedence-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sceneID = UUID()
        let localActive = makeScene(
            id: sceneID,
            name: "Local Active",
            updatedAt: Date(timeIntervalSince1970: 200),
            deletedAt: nil
        )
        defaults.set(try JSONEncoder().encode([localActive]), forKey: scenesKey)

        let remoteDeleted = makeScene(
            id: sceneID,
            name: "Cloud Tombstone",
            updatedAt: Date(timeIntervalSince1970: 150),
            deletedAt: Date(timeIntervalSince1970: 400)
        )
        let mockStore = MockUbiquitousKeyValueStore()
        mockStore.storage[scenesKey] = try JSONEncoder().encode(TestSceneEnvelope(version: payloadVersion, scenes: [remoteDeleted]))

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: mockStore)

        #expect(engine.scenes.count == 1)
        #expect(engine.scenes.first?.id == sceneID)
        #expect(engine.scenes.first?.deletedAt == remoteDeleted.deletedAt)
    }

    private func waitForScenesPersistence(defaults: UserDefaults) async throws -> Data {
        for _ in 0..<20 {
            if let data = defaults.data(forKey: scenesKey) {
                return data
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        return try #require(defaults.data(forKey: scenesKey))
    }
}

private struct TestSceneEnvelope: Codable {
    let version: Int
    let scenes: [DriftScene]
}

private func makeScene(
    id: UUID = UUID(),
    name: String,
    updatedAt: Date,
    deletedAt: Date? = nil
) -> DriftScene {
    DriftScene(
        id: id,
        name: name,
        modeIDs: [.auroraVeil, .cosmicTide],
        lastModeID: .auroraVeil,
        settings: DriftSceneSettings(
            brightness: 0.7,
            animationSpeed: 1.0,
            clockEnabled: false,
            preventAutoLock: false,
            autoDriftEnabled: false,
            autoDriftIntervalMinutes: 10,
            autoDriftShuffleEnabled: false
        ),
        updatedAt: updatedAt,
        deletedAt: deletedAt
    )
}

private extension Data {
    func jsonObject() throws -> [String: Any] {
        let raw = try JSONSerialization.jsonObject(with: self)
        guard let object = raw as? [String: Any] else {
            struct JSONDecodeError: Error {}
            throw JSONDecodeError()
        }
        return object
    }
}
