import SwiftUI
import Combine

final class DriftlyEngine: ObservableObject {
    @Published var currentMode: DriftMode = .nebulaLake
    @Published var isChromeVisible: Bool = true

    // Later this can hold:
    // - global brightness
    // - animation speed
    // - sleep timer state
    // - music-reactive state
}
