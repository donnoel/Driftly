import Foundation
import os

enum DriftProfiling {
    static let launchArgument = "DriftlyProfileSignposts"
    static let environmentKey = "DRIFTLY_PROFILE_SIGNPOSTS"
    static let profilingSessionLaunchArgument = "DriftlyProfilingSession"
    static let profilingSessionEnvironmentKey = "DRIFTLY_PROFILING_SESSION"
    static let profilingImmediateAutoDriftLaunchArgument = "DriftlyProfilingAutoDriftNow"

    private static let signposter = OSSignposter(subsystem: "com.driftly", category: "hitch")
    private static let processInfo = ProcessInfo.processInfo

    static let profilingSessionEnabled: Bool = {
        if processInfo.arguments.contains(profilingSessionLaunchArgument) {
            return true
        }
        return processInfo.environment[profilingSessionEnvironmentKey] == "1"
    }()

    static let profilingQuickEntryEnabled = profilingSessionEnabled
    static let profilingOverlayEnabled = profilingSessionEnabled

    static let profilingImmediateAutoDriftEnabled: Bool = {
        profilingSessionEnabled && processInfo.arguments.contains(profilingImmediateAutoDriftLaunchArgument)
    }()

    static let isEnabled: Bool = {
        if processInfo.arguments.contains(launchArgument) {
            return true
        }
        if processInfo.environment[environmentKey] == "1" {
            return true
        }
        return profilingSessionEnabled
    }()

    enum Signpost {
        static let scenePhaseChange: StaticString = "scene.phase.change"
        static let sceneApply: StaticString = "scene.apply"
        static let modeTransition: StaticString = "mode.transition"
        static let rendererSetup: StaticString = "renderer.setup"
        static let rendererTeardown: StaticString = "renderer.teardown"
        static let rendererReconfigure: StaticString = "renderer.reconfigure"
        static let autoDriftSchedule: StaticString = "autodrift.schedule"
        static let autoDriftSelect: StaticString = "autodrift.select"
        static let autoDriftApply: StaticString = "autodrift.apply"
        static let prewarmPrepare: StaticString = "autodrift.prewarm.prepare"
        static let timerLifecycle: StaticString = "timer.lifecycle"
        static let taskLifecycle: StaticString = "task.lifecycle"
    }

    @discardableResult
    static func begin(_ name: StaticString, message: @autoclosure () -> String = "") -> OSSignpostIntervalState? {
        guard isEnabled else { return nil }
        let details = message()
        if details.isEmpty {
            return signposter.beginInterval(name)
        }
        return signposter.beginInterval(name, "\(details, privacy: .public)")
    }

    static func end(
        _ name: StaticString,
        _ state: OSSignpostIntervalState?,
        message: @autoclosure () -> String = ""
    ) {
        guard isEnabled, let state else { return }
        let details = message()
        if details.isEmpty {
            signposter.endInterval(name, state)
            return
        }
        signposter.endInterval(name, state, "\(details, privacy: .public)")
    }

    static func event(_ name: StaticString, message: @autoclosure () -> String = "") {
        guard isEnabled else { return }
        let details = message()
        if details.isEmpty {
            signposter.emitEvent(name)
            return
        }
        signposter.emitEvent(name, "\(details, privacy: .public)")
    }
}
