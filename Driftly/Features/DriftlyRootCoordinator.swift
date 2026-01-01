import SwiftUI
import Combine

@MainActor
final class DriftlyRootCoordinator: ObservableObject {
    @Published var sleepState = SleepAndDriftController.State()
    @Published var clockNow = Date()
    @Published var phaseAnchorDate = Date()
    @Published var brightnessHUDVisible = false
    @Published var brightnessHUDValue: Double = 1.0
    @Published var prewarmMode: DriftMode?
    @Published var isModePickerPresented: Bool
    @Published var isSettingsPresented = false
    @Published var isSleepTimerDialogPresented: Bool
    @Published var isCustomSleepTimerPresented = false
    @Published var customSleepMinutes: Int = 20
    @Published private(set) var tickTimer = Timer.publish(every: 1, on: .main, in: .common)
    @Published private(set) var clockTimer = Timer.publish(every: 1, on: .main, in: .common)

    private var tickConnection: Cancellable?
    private var clockConnection: Cancellable?
    private var brightnessHUDHideWorkItem: DispatchWorkItem?
    private var autoDriftPausedAt: Date?
    private var didRunInitialSetup = false

    init(testOverrides: (modePicker: Bool, sleepDialog: Bool)? = nil) {
        let args = ProcessInfo.processInfo.arguments
        let defaultModePicker = args.contains("UITestingOpenModePicker")
        let defaultSleepDialog = args.contains("UITestingOpenSleepTimer")

        isModePickerPresented = testOverrides?.modePicker ?? defaultModePicker
        isSleepTimerDialogPresented = testOverrides?.sleepDialog ?? defaultSleepDialog
    }

    func runInitialSetupIfNeeded(
        engine: DriftlyEngine,
        scenePhase: ScenePhase,
        updateIdleTimer: () -> Void,
        updateClockTicking: () -> Void,
        focusChromeIfNeeded: () -> Void = {}
    ) {
        guard !didRunInitialSetup else { return }
        didRunInitialSetup = true

        applyUITestOverrides(engine: engine)
        updateIdleTimer()
        updateClockTicking()
        SleepAndDriftController.resetAutoDriftClock(state: &sleepState)
        updateTicking(engine: engine, scenePhase: scenePhase)
        focusChromeIfNeeded()
    }

    func handleScenePhaseChange(to newPhase: ScenePhase) {
        if newPhase == .active {
            if let pausedAt = autoDriftPausedAt {
                let now = Date()
                let delta = now.timeIntervalSince(pausedAt)
                let adjusted = sleepState.lastAutoDriftChange.addingTimeInterval(delta)
                sleepState.lastAutoDriftChange = min(adjusted, now)
                autoDriftPausedAt = nil
            }
        } else {
            autoDriftPausedAt = Date()
        }
    }

    func handleTick(now: Date, engine: DriftlyEngine) -> [SleepAndDriftController.Action] {
        guard SleepAndDriftController.shouldTick(engine: engine, state: sleepState) else { return [] }
        let actions = SleepAndDriftController.handleTick(now: now, engine: engine, state: &sleepState)
        updatePrewarm(now: now, engine: engine)
        return actions
    }

    func updateTicking(engine: DriftlyEngine, scenePhase: ScenePhase) {
        let shouldTick = SleepAndDriftController.shouldTick(engine: engine, state: sleepState)
        && scenePhase == .active
        && !sleepState.sleepTimerHasExpired
        if shouldTick {
            if tickConnection == nil {
                tickTimer = Timer.publish(every: 1, on: .main, in: .common)
                tickConnection = tickTimer.connect()
            }
        } else {
            tickConnection?.cancel()
            tickConnection = nil
        }
    }

    func updateClockTicking(clockEnabled: Bool, scenePhase: ScenePhase) {
        let shouldTickClock = clockEnabled && scenePhase == .active && !sleepState.sleepTimerHasExpired
        if shouldTickClock {
            if clockConnection == nil {
                clockTimer = Timer.publish(every: 1, on: .main, in: .common)
                clockConnection = clockTimer.connect()
            }
        } else {
            clockConnection?.cancel()
            clockConnection = nil
        }
    }

    func stopTimers() {
        tickConnection?.cancel()
        tickConnection = nil
        clockConnection?.cancel()
        clockConnection = nil
    }

    func updatePrewarm(now: Date, engine: DriftlyEngine) {
        guard engine.autoDriftEnabled, !sleepState.sleepTimerHasExpired else {
            prewarmMode = nil
            return
        }

        let heavyPrewarmModes: Set<DriftMode> = [.photonRain, .voxelMirage, .inkTopography]
        let intervalMinutes = max(1, engine.autoDriftIntervalMinutes)
        let intervalSeconds = Double(intervalMinutes * 60)
        let elapsed = now.timeIntervalSince(sleepState.lastAutoDriftChange)
        let remaining = intervalSeconds - elapsed
        let window: TimeInterval = 1.0

        if remaining <= window && remaining > 0 {
            let next = engine.peekNextAutoDriftMode(after: engine.currentMode)
            if heavyPrewarmModes.contains(next) {
                prewarmMode = nil
                return
            }
            if prewarmMode != next {
                prewarmMode = next
            }
        } else {
            prewarmMode = nil
        }
    }

    func resetAutoDriftClock() {
        SleepAndDriftController.resetAutoDriftClock(state: &sleepState)
    }

    func showBrightnessHUD(for value: Double) {
        brightnessHUDValue = value
        withAnimation(.easeInOut(duration: 0.15)) {
            brightnessHUDVisible = true
        }

        brightnessHUDHideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.35)) {
                    self?.brightnessHUDVisible = false
                }
            }
        }
        brightnessHUDHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func applyUITestOverrides(engine: DriftlyEngine) {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard args.contains(where: { arg in
            arg == "UITestingForceChromeVisible" ||
            arg == "UITestingOpenModePicker" ||
            arg == "UITestingOpenSleepTimer" ||
            arg.hasPrefix("UITestingSetMode=")
        }) else { return }

        if args.contains("UITestingForceChromeVisible") {
            engine.isChromeVisible = true
        }
        if args.contains("UITestingOpenModePicker") || args.contains("UITestingOpenSleepTimer") {
            engine.isChromeVisible = true
        }
        if args.contains("UITestingOpenModePicker") {
            isModePickerPresented = true
        }
        if args.contains("UITestingOpenSleepTimer") {
            isSleepTimerDialogPresented = true
        }
        if let setModeArg = args.first(where: { $0.hasPrefix("UITestingSetMode=") }) {
            let raw = String(setModeArg.split(separator: "=", maxSplits: 1).last ?? "")
            if let mode = DriftMode(rawValue: raw) {
                engine.currentMode = mode
            }
        }
        #endif
    }
}
