import Foundation
import Testing
@testable import DriftlyTV

struct TVRemoteGuideProgressTests {
    @Test func completionPersistsLocallyWithoutChangingExistingPreferences() throws {
        let suite = "RemoteGuide-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(0.42, forKey: "driftly.brightness")
        defaults.set("glassTides", forKey: "driftly.currentMode")

        #expect(TVRemoteGuideProgress.shouldPresent(defaults: defaults))
        TVRemoteGuideProgress.complete(defaults: defaults)
        let reopened = try #require(UserDefaults(suiteName: suite))
        #expect(!TVRemoteGuideProgress.shouldPresent(defaults: reopened))
        #expect(reopened.double(forKey: "driftly.brightness") == 0.42)
        #expect(reopened.string(forKey: "driftly.currentMode") == "glassTides")
    }

    @Test func anotherInstallationStillGetsItsGuide() throws {
        let firstSuite = "RemoteGuide-\(UUID().uuidString)"
        let secondSuite = "RemoteGuide-\(UUID().uuidString)"
        let first = try #require(UserDefaults(suiteName: firstSuite))
        let second = try #require(UserDefaults(suiteName: secondSuite))
        defer {
            first.removePersistentDomain(forName: firstSuite)
            second.removePersistentDomain(forName: secondSuite)
        }
        TVRemoteGuideProgress.complete(defaults: first)
        #expect(!TVRemoteGuideProgress.shouldPresent(defaults: first))
        #expect(TVRemoteGuideProgress.shouldPresent(defaults: second))
    }
}
