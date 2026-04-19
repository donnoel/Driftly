import Testing
@testable import Driftly

@MainActor
struct ModeViewBuilderTests {

    @Test func coversAllModes() async throws {
        let builders = ModeViewRegistry.builders
        #expect(builders.count == DriftMode.allCases.count)

        for mode in DriftMode.allCases {
            #expect(builders[mode] != nil, "Missing builder for \(mode.rawValue)")
        }
    }
}

struct ActiveModeHostTransitionDecisionTests {

    @Test func prewarmRendersOnlyInIdleNonReducedMotionState() async throws {
        #expect(
            ActiveModeHostTransitionDecisions.shouldRenderPrewarmLayer(
                reduceMotion: false,
                hasPreviousMode: false,
                modeCrossfade: 1.0
            ) == true
        )

        #expect(
            ActiveModeHostTransitionDecisions.shouldRenderPrewarmLayer(
                reduceMotion: false,
                hasPreviousMode: false,
                modeCrossfade: 1.01
            ) == true
        )
    }

    @Test func prewarmDoesNotRenderWhenReduceMotionEnabled() async throws {
        #expect(
            ActiveModeHostTransitionDecisions.shouldRenderPrewarmLayer(
                reduceMotion: true,
                hasPreviousMode: false,
                modeCrossfade: 1.0
            ) == false
        )
    }

    @Test func prewarmDoesNotRenderDuringCrossfadeOrWhenPreviousLayerExists() async throws {
        #expect(
            ActiveModeHostTransitionDecisions.shouldRenderPrewarmLayer(
                reduceMotion: false,
                hasPreviousMode: true,
                modeCrossfade: 1.0
            ) == false
        )

        #expect(
            ActiveModeHostTransitionDecisions.shouldRenderPrewarmLayer(
                reduceMotion: false,
                hasPreviousMode: false,
                modeCrossfade: 0.999
            ) == false
        )
    }

    @Test func cleanupDecisionIsDeterministicForExpectedPreviousMode() async throws {
        #expect(
            ActiveModeHostTransitionDecisions.shouldCleanupPreviousLayer(
                expectedPreviousMode: .auroraVeil,
                currentPreviousMode: .auroraVeil
            ) == true
        )

        #expect(
            ActiveModeHostTransitionDecisions.shouldCleanupPreviousLayer(
                expectedPreviousMode: .auroraVeil,
                currentPreviousMode: .cosmicTide
            ) == false
        )

        #expect(
            ActiveModeHostTransitionDecisions.shouldCleanupPreviousLayer(
                expectedPreviousMode: .auroraVeil,
                currentPreviousMode: nil
            ) == false
        )
    }
}
