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
        return DriftlyEngine()
    }
}
#endif
