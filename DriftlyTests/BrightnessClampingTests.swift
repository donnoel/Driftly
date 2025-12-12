import Testing
@testable import Driftly

struct BrightnessClampingTests {

    @Test func clampsHighAndLowValues() async throws {
        let suite = "Brightness-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let engine = DriftlyEngine(defaults: defaults)

        engine.brightness = 5.0
        #expect(engine.brightness == 1.0)

        engine.brightness = 0.01
        #expect(engine.brightness == 0.2)
    }
}
