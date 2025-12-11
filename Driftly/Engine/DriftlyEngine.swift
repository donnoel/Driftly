import SwiftUI
import Combine

private enum DriftlyDefaultsKey {
    static let currentMode      = "driftly.currentMode"
    static let animationSpeed   = "driftly.animationSpeed"
    static let preventAutoLock  = "driftly.preventAutoLock"
    static let isChromeVisible  = "driftly.isChromeVisible"
    static let brightness       = "driftly.brightness"
}

final class DriftlyEngine: ObservableObject {
    // MARK: - Published state

    @Published var currentMode: DriftMode {
        didSet { persistCurrentMode() }
    }

    @Published var isChromeVisible: Bool {
        didSet { persistChromeVisibility() }
    }

    /// 1.0 = normal speed, 0.5 = slower, 1.5 = faster
    @Published var animationSpeed: Double {
        didSet { persistAnimationSpeed() }
    }

    /// When true, Driftly will try to prevent auto-lock while active
    @Published var preventAutoLock: Bool {
        didSet { persistPreventAutoLock() }
    }

    /// 0.2 (dim) ... 1.0 (full brightness)
    @Published var brightness: Double {
        didSet { persistBrightness() }
    }

    /// When set, Driftly will fade out once this time is reached (not persisted across launches)
    @Published var sleepTimerEndDate: Date? = nil

    var allModes: [DriftMode] {
        DriftMode.allCases
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        // currentMode
        if let raw = defaults.string(forKey: DriftlyDefaultsKey.currentMode),
           let mode = DriftMode(rawValue: raw) {
            currentMode = mode
        } else {
            currentMode = .nebulaLake
        }

        // isChromeVisible (default: true)
        if defaults.object(forKey: DriftlyDefaultsKey.isChromeVisible) != nil {
            isChromeVisible = defaults.bool(forKey: DriftlyDefaultsKey.isChromeVisible)
        } else {
            isChromeVisible = true
        }

        // animationSpeed (default: 1.0)
        let storedSpeed = defaults.double(forKey: DriftlyDefaultsKey.animationSpeed)
        animationSpeed = storedSpeed == 0 ? 1.0 : storedSpeed

        // preventAutoLock (default: false)
        if defaults.object(forKey: DriftlyDefaultsKey.preventAutoLock) != nil {
            preventAutoLock = defaults.bool(forKey: DriftlyDefaultsKey.preventAutoLock)
        } else {
            preventAutoLock = false
        }

        // brightness (default: 1.0)
        let storedBrightness = defaults.double(forKey: DriftlyDefaultsKey.brightness)
        if storedBrightness == 0 {
            brightness = 1.0
        } else {
            brightness = max(0.2, min(1.0, storedBrightness))
        }
    }

    // MARK: - Public API

    func goToNextMode() {
        let modes = allModes
        guard let index = modes.firstIndex(of: currentMode) else {
            currentMode = modes.first ?? .nebulaLake
            return
        }
        let nextIndex = modes.index(after: index)
        currentMode = nextIndex < modes.endIndex ? modes[nextIndex] : modes.first ?? .nebulaLake
    }

    /// minutes = nil → turn timer off (not persisted)
    func setSleepTimer(minutes: Int?) {
        if let minutes {
            sleepTimerEndDate = Date().addingTimeInterval(Double(minutes) * 60.0)
        } else {
            sleepTimerEndDate = nil
        }
    }

    // MARK: - Persistence

    private func persistCurrentMode() {
        UserDefaults.standard.set(currentMode.rawValue, forKey: DriftlyDefaultsKey.currentMode)
    }

    private func persistBrightness() {
        UserDefaults.standard.set(brightness, forKey: DriftlyDefaultsKey.brightness)
    }

    private func persistAnimationSpeed() {
        UserDefaults.standard.set(animationSpeed, forKey: DriftlyDefaultsKey.animationSpeed)
    }

    private func persistPreventAutoLock() {
        UserDefaults.standard.set(preventAutoLock, forKey: DriftlyDefaultsKey.preventAutoLock)
    }

    private func persistChromeVisibility() {
        UserDefaults.standard.set(isChromeVisible, forKey: DriftlyDefaultsKey.isChromeVisible)
    }
}
