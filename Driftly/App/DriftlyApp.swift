import SwiftUI

@main
struct DriftlyApp: App {
    @StateObject private var engine = DriftlyEngine()

    var body: some Scene {
        WindowGroup {
            DriftlyRootView()
                .environmentObject(engine)
        }
    }
}
