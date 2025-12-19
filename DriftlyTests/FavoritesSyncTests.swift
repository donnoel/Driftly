import Foundation
import Testing
@testable import Driftly

@MainActor
struct FavoritesSyncTests {
    private let favoriteKey = "driftly.favoriteModes"

    @Test func usesCloudFavoritesWhenPresent() async throws {
        let suiteName = "CloudFavorites-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let mockStore = MockUbiquitousKeyValueStore()
        mockStore.storage[favoriteKey] = [DriftMode.cosmicTide.rawValue]

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: mockStore)

        #expect(engine.favoriteModes == [.cosmicTide])
        #expect(defaults.array(forKey: favoriteKey) as? [String] == [DriftMode.cosmicTide.rawValue])
    }

    @Test func pushesLocalFavoritesToCloudOnChange() async throws {
        let suiteName = "PushFavorites-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let mockStore = MockUbiquitousKeyValueStore()
        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: mockStore)

        engine.favoriteModes = [.auroraVeil, .nebulaLake]

        let stored = mockStore.storage[favoriteKey] as? [String] ?? []
        #expect(Set(stored) == Set([DriftMode.auroraVeil.rawValue, DriftMode.nebulaLake.rawValue]))
    }

    @Test func appliesServerChangesFromCloud() async throws {
        let suiteName = "ServerChange-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let mockStore = MockUbiquitousKeyValueStore()
        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: mockStore)

        mockStore.storage[favoriteKey] = [DriftMode.emberDrift.rawValue]
        mockStore.sendServerChange(for: [favoriteKey])

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(engine.favoriteModes == [.emberDrift])
        #expect(defaults.array(forKey: favoriteKey) as? [String] == [DriftMode.emberDrift.rawValue])
    }

    @Test func clearsFavoritesWhenCloudKeyRemoved() async throws {
        let suiteName = "ClearFavorites-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let mockStore = MockUbiquitousKeyValueStore()
        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: mockStore)

        engine.favoriteModes = [.lunarDrift]

        mockStore.set(nil, forKey: favoriteKey)
        mockStore.sendServerChange(for: [favoriteKey])

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(engine.favoriteModes.isEmpty)
        #expect((defaults.array(forKey: favoriteKey) as? [String])?.isEmpty == true)
    }

    @Test func secondEngineReadsCloudFavorites() async throws {
        let suiteName = "SecondEngineCloud-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let mockStore = MockUbiquitousKeyValueStore()

        let engineA = DriftlyEngine(defaults: defaults, ubiquitousStore: mockStore)
        engineA.favoriteModes = [.prismShards, .signalDrift]

        let engineB = DriftlyEngine(defaults: defaults, ubiquitousStore: mockStore)

        #expect(engineB.favoriteModes == [.prismShards, .signalDrift])
    }
}

final class MockUbiquitousKeyValueStore: UbiquitousKeyValueStoring {
    var storage: [String: Any] = [:]

    func array(forKey key: String) -> [Any]? {
        storage[key] as? [Any]
    }

    func data(forKey key: String) -> Data? {
        storage[key] as? Data
    }

    func set(_ value: Any?, forKey key: String) {
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }

    func synchronize() -> Bool { true }

    func sendServerChange(for keys: [String]) {
        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: self,
            userInfo: [
                NSUbiquitousKeyValueStoreChangedKeysKey: keys,
                NSUbiquitousKeyValueStoreChangeReasonKey: NSUbiquitousKeyValueStoreServerChange
            ]
        )
    }
}
