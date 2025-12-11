import SwiftUI
import Combine

final class DriftlyEngine: ObservableObject {
    @Published var currentMode: DriftMode = .nebulaLake
    @Published var isChromeVisible: Bool = true

    /// 1.0 = normal speed, 0.5 = slower, 1.5 = faster
    @Published var animationSpeed: Double = 1.0

    /// When true, Driftly will try to prevent auto-lock while active
    @Published var preventAutoLock: Bool = false

    /// When set, Driftly will fade out once this time is reached
    @Published var sleepTimerEndDate: Date? = nil

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

    /// minutes = nil → turn timer off
    func setSleepTimer(minutes: Int?) {
        if let minutes {
            sleepTimerEndDate = Date().addingTimeInterval(Double(minutes) * 60.0)
        } else {
            sleepTimerEndDate = nil
        }
    }
}
