//
//  DriftlyTests.swift
//  DriftlyTests
//
//  Created by Don Noel on 12/11/25.
//

import Testing
@testable import Driftly

struct DriftlyTests {

    @Test func persistenceRoundTrip() async throws {
        let suiteName = "Persistence-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // First run: set values
        do {
            let engine = DriftlyEngine(defaults: defaults)
            engine.currentMode = .auroraVeil
            engine.animationSpeed = 1.3
            engine.preventAutoLock = true
            engine.isChromeVisible = false
            engine.brightness = 0.65
            engine.autoDriftEnabled = true
            engine.autoDriftShuffleEnabled = true
            engine.autoDriftIntervalMinutes = 10
        }

        // Second run: ensure values persisted
        do {
            let engine = DriftlyEngine(defaults: defaults)
            #expect(engine.currentMode == .auroraVeil)
            #expect(engine.animationSpeed == 1.3)
            #expect(engine.preventAutoLock == true)
            #expect(engine.isChromeVisible == false)
            #expect(engine.brightness == 0.65)
            #expect(engine.autoDriftEnabled == true)
            #expect(engine.autoDriftShuffleEnabled == true)
            #expect(engine.autoDriftIntervalMinutes == 10)
        }
    }

}
