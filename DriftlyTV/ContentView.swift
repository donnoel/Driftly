import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @State private var isRemoteGuidePresented = false

    var body: some View {
        DriftlyRootView()
            .environmentObject(engine)
            .task {
                isRemoteGuidePresented = TVRemoteGuideProgress.shouldPresent()
            }
            .fullScreenCover(isPresented: $isRemoteGuidePresented) {
                TVRemoteGuideView {
                    TVRemoteGuideProgress.complete()
                    isRemoteGuidePresented = false
                }
            }
    }
}
