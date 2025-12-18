#if os(iOS)
import SwiftUI

@main
struct DriftlyApp: App {
    @StateObject private var engine = DriftlyApp.makeEngine()

    var body: some Scene {
        WindowGroup {
            DriftlyRootView()
                .environmentObject(engine)
        }
    }

    private static func makeEngine() -> DriftlyEngine {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UITestingReset") {
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
        }
        #endif

        let engine = DriftlyEngine()

        #if DEBUG
        applyUITestEngineOverrides(to: engine)
        #endif

        return engine
    }

#if DEBUG
    private static func applyUITestEngineOverrides(to engine: DriftlyEngine) {
        let args = ProcessInfo.processInfo.arguments

        // Force chrome visible for any UI test that needs it.
        if args.contains("UITestingForceChromeVisible")
            || args.contains("UITestingOpenModePicker")
            || args.contains("UITestingOpenSleepTimer") {
            engine.isChromeVisible = true
        }

        // Apply a specific mode if requested.
        if let setModeArg = args.first(where: { $0.hasPrefix("UITestingSetMode=") }) {
            let raw = String(setModeArg.split(separator: "=", maxSplits: 1).last ?? "")
            if let mode = DriftMode(rawValue: raw) {
                engine.currentMode = mode
            }
        }
    }
#endif
}
#endif
