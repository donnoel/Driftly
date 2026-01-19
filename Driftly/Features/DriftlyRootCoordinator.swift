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
    private var autoDriftFireTimer: Timer?
    private var prewarmFireTimer: Timer?
    private var autoDriftPausedAt: Date?
    private var currentScenePhase: ScenePhase = .active
    private let prewarmLead: TimeInterval = 1.5
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

        currentScenePhase = scenePhase
        applyUITestOverrides(engine: engine)
        updateIdleTimer()
        updateClockTicking()
        SleepAndDriftController.resetAutoDriftClock(state: &sleepState)
        updateTicking(engine: engine, scenePhase: scenePhase)
        updateAutoDriftScheduling(engine: engine, scenePhase: scenePhase)
        focusChromeIfNeeded()
    }

    func handleScenePhaseChange(to newPhase: ScenePhase) {
        currentScenePhase = newPhase
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
            cancelAutoDriftTimers()
        }
    }

    func handleSleepTimerTick(now: Date, engine: DriftlyEngine) -> [SleepAndDriftController.Action] {
        guard SleepAndDriftController.shouldSleepTick(engine: engine, state: sleepState) else { return [] }
        return SleepAndDriftController.handleTick(
            now: now,
            engine: engine,
            state: &sleepState,
            includeAutoDrift: false
        )
    }

    func updateTicking(engine: DriftlyEngine, scenePhase: ScenePhase) {
        let shouldTick = SleepAndDriftController.shouldSleepTick(engine: engine, state: sleepState)
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
        cancelAutoDriftTimers()
    }

    func resetAutoDriftClock() {
        SleepAndDriftController.resetAutoDriftClock(state: &sleepState)
    }

    func updateAutoDriftScheduling(engine: DriftlyEngine, scenePhase: ScenePhase) {
        currentScenePhase = scenePhase
        if engine.isAutoDriftOperational && scenePhase == .active && !sleepState.sleepTimerHasExpired {
            scheduleAutoDriftTimers(engine: engine)
        } else {
            cancelAutoDriftTimers()
        }
    }

    private func scheduleAutoDriftTimers(engine: DriftlyEngine) {
        cancelAutoDriftTimers()

        guard engine.isAutoDriftOperational, currentScenePhase == .active, !sleepState.sleepTimerHasExpired else {
            return
        }

        let intervalSeconds = Double(max(1, engine.autoDriftIntervalMinutes) * 60)
        let now = Date()
        let nextDriftDate = sleepState.lastAutoDriftChange.addingTimeInterval(intervalSeconds)

        if nextDriftDate <= now {
            performAutoDrift(engine: engine)
            return
        }

        schedulePrewarmTimer(fireDate: nextDriftDate, engine: engine)

        let fireTimer = Timer(fire: nextDriftDate, interval: 0, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.performAutoDrift(engine: engine)
        }
        autoDriftFireTimer = fireTimer
        RunLoop.main.add(fireTimer, forMode: .common)
    }

    private func schedulePrewarmTimer(fireDate driftDate: Date, engine: DriftlyEngine) {
        prewarmFireTimer?.invalidate()
        prewarmFireTimer = nil

        let prewarmDate = driftDate.addingTimeInterval(-prewarmLead)
        let now = Date()

        guard engine.isAutoDriftOperational, currentScenePhase == .active, !sleepState.sleepTimerHasExpired else {
            prewarmMode = nil
            return
        }

        if prewarmDate <= now {
            setPrewarmMode(engine: engine)
            return
        }

        let timer = Timer(fire: prewarmDate, interval: 0, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.setPrewarmMode(engine: engine)
        }
        prewarmFireTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func setPrewarmMode(engine: DriftlyEngine) {
        guard engine.isAutoDriftOperational, !sleepState.sleepTimerHasExpired else {
            prewarmMode = nil
            return
        }

        let heavyPrewarmModes: Set<DriftMode> = [.photonRain, .voxelMirage, .inkTopography]
        let next = engine.peekNextAutoDriftMode(after: engine.currentMode)
        prewarmMode = heavyPrewarmModes.contains(next) ? nil : next
    }

    private func performAutoDrift(engine: DriftlyEngine) {
        cancelAutoDriftTimers()

        guard engine.isAutoDriftOperational, currentScenePhase == .active, !sleepState.sleepTimerHasExpired else {
            prewarmMode = nil
            return
        }

        let now = Date()
        let nextMode = engine.nextAutoDriftMode(after: engine.currentMode)

        withAnimation(.easeInOut(duration: 0.9)) {
            engine.currentMode = nextMode
        }
        DriftHaptics.autoDriftTick()
        sleepState.lastAutoDriftChange = now
        prewarmMode = nil

        scheduleAutoDriftTimers(engine: engine)
    }

    private func cancelAutoDriftTimers() {
        autoDriftFireTimer?.invalidate()
        autoDriftFireTimer = nil
        prewarmFireTimer?.invalidate()
        prewarmFireTimer = nil
        prewarmMode = nil
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
