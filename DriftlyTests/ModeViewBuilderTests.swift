import Testing
@testable import Driftly

@MainActor
struct ModeViewBuilderTests {

    @Test func coversAllModes() async throws {
        let builders = DriftlyRootView.modeViewBuilders
        #expect(builders.count == DriftMode.allCases.count)

        for mode in DriftMode.allCases {
            #expect(builders[mode] != nil, "Missing builder for \(mode.rawValue)")
        }
    }
}
