import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var engine: DriftlyEngine

    var body: some View {
        DriftlyRootView()
            .environmentObject(engine)
    }
}
