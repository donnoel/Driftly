import SwiftUI

@main
struct DriftlyTVApp: App {
    @StateObject private var engine = DriftlyEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
        }
    }
}
