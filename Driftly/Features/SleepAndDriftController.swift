import Foundation

/// Encapsulates sleep timer and auto-drift decision logic so it is testable outside SwiftUI.
struct SleepAndDriftController {
    struct State: Equatable {
        var sleepTimerHasExpired = false
        var sleepTimerAllowsLock = false
        var lastAutoDriftChange = Date()
    }

    enum Action: Equatable {
        case expire
        case wake
        case autoDrift
    }

    static func shouldTick(engine: DriftlyEngine) -> Bool {
        engine.autoDriftEnabled || engine.sleepTimerEndDate != nil
    }

    static func resetAutoDriftClock(state: inout State) {
        state.lastAutoDriftChange = Date()
    }

    /// Returns actions describing what needs to happen for the given time and engine state.
    static func handleTick(now: Date, engine: DriftlyEngine, state: inout State) -> [Action] {
        var actions: [Action] = []

        if let end = engine.sleepTimerEndDate {
            if now >= end && !state.sleepTimerHasExpired {
                state.sleepTimerHasExpired = true
                state.sleepTimerAllowsLock = true
                actions.append(.expire)
            }
        } else if state.sleepTimerHasExpired {
            state.sleepTimerHasExpired = false
            state.sleepTimerAllowsLock = false
            actions.append(.wake)
        }

        if engine.shouldAutoDrift(
            now: now,
            lastChange: state.lastAutoDriftChange,
            sleepTimerHasExpired: state.sleepTimerHasExpired
        ) {
            actions.append(.autoDrift)
            state.lastAutoDriftChange = now
        }

        return actions
    }
}
