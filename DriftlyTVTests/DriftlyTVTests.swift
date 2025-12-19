//
//  DriftlyTVTests.swift
//  DriftlyTVTests
//
//  Created by Don Noel on 12/12/25.
//

import Foundation
import SwiftUI
import Testing
@testable import DriftlyTV

@MainActor
struct DriftlyTVTests {

    @Test func idleTimerPolicyRespectsTvOSBehavior() async throws {
        let preventWhenActive = shouldPreventLockTvOS(
            preventAutoLock: true,
            sleepTimerAllowsLock: false,
            scenePhase: .active
        )
        #expect(preventWhenActive == true)

        let allowWhenInactive = shouldPreventLockTvOS(
            preventAutoLock: true,
            sleepTimerAllowsLock: false,
            scenePhase: .inactive
        )
        #expect(allowWhenInactive == false)

        let allowWhenSleepTimerAllows = shouldPreventLockTvOS(
            preventAutoLock: true,
            sleepTimerAllowsLock: true,
            scenePhase: .active
        )
        #expect(allowWhenSleepTimerAllows == false)
    }

    @Test func motionParallaxUsesTiltOnTvOS() async throws {
        let manager = DriftMotionManager()

        // Default tilt yields no offset
        let zeroOffset = manager.parallaxOffset
        #expect(zeroOffset == .zero)

        manager.xTilt = 0.35
        manager.yTilt = -0.35

        // Max tilt should map to the configured 12pt offset in each axis
        let offset = manager.parallaxOffset
        #expect(abs(offset.width - 12) < 0.001)
        #expect(abs(offset.height - 12) < 0.001)
    }

    @Test func autoDriftRespectsFavoritesOnTvOS() async throws {
        let suiteName = "AutoDriftTV-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        engine.favoriteModes = [.auroraVeil, .cosmicTide]
        engine.autoDriftSource = .favorites
        engine.autoDriftShuffleEnabled = false

        engine.currentMode = .auroraVeil
        #expect(engine.nextAutoDriftMode(after: .auroraVeil) == .cosmicTide)

        // Non-favorite current mode should lead into the favorite cycle
        engine.currentMode = .nebulaLake
        #expect(engine.nextAutoDriftMode(after: .nebulaLake) == .auroraVeil)
    }
}
