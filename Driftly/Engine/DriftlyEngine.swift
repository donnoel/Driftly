import SwiftUI
import Combine

final class DriftlyEngine: ObservableObject {
    @Published var currentMode: DriftMode = .nebulaLake
    @Published var isChromeVisible: Bool = true

    var allModes: [DriftMode] {
        DriftMode.allCases
    }

    func goToNextMode() {
        let modes = allModes
        guard let index = modes.firstIndex(of: currentMode) else {
            currentMode = modes.first ?? .nebulaLake
            return
        }
        let nextIndex = modes.index(after: index)
        currentMode = nextIndex < modes.endIndex ? modes[nextIndex] : modes.first ?? .nebulaLake
    }
}
