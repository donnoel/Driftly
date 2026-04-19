import SwiftUI

@main
struct DriftlyTVApp: App {
    @StateObject private var engine = DriftlyTVApp.makeEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .environmentObject(engine.preferences)
                .environmentObject(engine.sleepDrift)
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
        return DriftlyEngine()
    }
}
