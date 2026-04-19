import SwiftUI
import Combine

@MainActor
final class DriftlyRootCoordinator: ObservableObject {
    enum SleepTransition {
        case none
        case expired
        case woke
    }

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
    private var lastSignpostedAutoDriftFireDate: Date?
    private var lastSignpostedPrewarmFireDate: Date?
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
        let previousPhase = currentScenePhase
        let interval = DriftProfiling.begin(
            DriftProfiling.Signpost.scenePhaseChange,
            message: "from=\(Self.phaseName(previousPhase)) to=\(Self.phaseName(newPhase))"
        )
        defer {
            DriftProfiling.end(
                DriftProfiling.Signpost.scenePhaseChange,
                interval,
                message: "from=\(Self.phaseName(previousPhase)) to=\(Self.phaseName(newPhase))"
            )
        }

        currentScenePhase = newPhase
        if newPhase == .active {
            if let pausedAt = autoDriftPausedAt {
                let now = Date()
                let delta = now.timeIntervalSince(pausedAt)
                let adjusted = sleepState.lastAutoDriftChange.addingTimeInterval(delta)
                sleepState.lastAutoDriftChange = min(adjusted, now)
                autoDriftPausedAt = nil
                DriftProfiling.event(
                    DriftProfiling.Signpost.autoDriftSchedule,
                    message: "resume adjustedBy=\(delta)s"
                )
            }
        } else {
            autoDriftPausedAt = Date()
            cancelAutoDriftTimers()
        }
    }

    func applySleepTimerSelection(minutes: Int?, engine: DriftlyEngine, scenePhase: ScenePhase) {
        engine.setSleepTimer(minutes: minutes)
        setSleepAwakeStateIfNeeded()
        updateTicking(engine: engine, scenePhase: scenePhase)
        updateClockTicking(clockEnabled: engine.clockEnabled, scenePhase: scenePhase)
        updateAutoDriftScheduling(engine: engine, scenePhase: scenePhase)
    }

    func wakeFromSleep(engine: DriftlyEngine, scenePhase: ScenePhase) {
        setSleepAwakeStateIfNeeded()
        resetAutoDriftClock()
        updateTicking(engine: engine, scenePhase: scenePhase)
        updateClockTicking(clockEnabled: engine.clockEnabled, scenePhase: scenePhase)
        updateAutoDriftScheduling(engine: engine, scenePhase: scenePhase)
    }

    func processSleepTimerTick(now: Date, engine: DriftlyEngine, scenePhase: ScenePhase) -> SleepTransition {
        guard SleepAndDriftController.shouldSleepTick(engine: engine, state: sleepState) else { return .none }
        let actions = SleepAndDriftController.handleTick(
            now: now,
            engine: engine,
            state: &sleepState,
            includeAutoDrift: false
        )
        updateTicking(engine: engine, scenePhase: scenePhase)
        updateClockTicking(clockEnabled: engine.clockEnabled, scenePhase: scenePhase)
        updateAutoDriftScheduling(engine: engine, scenePhase: scenePhase)

        if actions.contains(.expire) {
            return .expired
        }
        if actions.contains(.wake) {
            return .woke
        }
        return .none
    }

    func updateTicking(engine: DriftlyEngine, scenePhase: ScenePhase) {
        let shouldTick = SleepAndDriftController.shouldSleepTick(engine: engine, state: sleepState)
            && scenePhase == .active
            && !sleepState.sleepTimerHasExpired
        if shouldTick {
            if tickConnection == nil {
                tickTimer = Timer.publish(every: 1, on: .main, in: .common)
                tickConnection = tickTimer.connect()
                DriftProfiling.event(
                    DriftProfiling.Signpost.timerLifecycle,
                    message: "sleepTick create interval=1s"
                )
            }
        } else {
            if tickConnection != nil {
                tickConnection?.cancel()
                tickConnection = nil
                DriftProfiling.event(
                    DriftProfiling.Signpost.timerLifecycle,
                    message: "sleepTick cancel"
                )
            }
        }
    }

    func updateClockTicking(clockEnabled: Bool, scenePhase: ScenePhase) {
        let shouldTickClock = clockEnabled && scenePhase == .active && !sleepState.sleepTimerHasExpired
        if shouldTickClock {
            if clockConnection == nil {
                clockTimer = Timer.publish(every: 1, on: .main, in: .common)
                clockConnection = clockTimer.connect()
                DriftProfiling.event(
                    DriftProfiling.Signpost.timerLifecycle,
                    message: "clockTick create interval=1s"
                )
            }
        } else {
            if clockConnection != nil {
                clockConnection?.cancel()
                clockConnection = nil
                DriftProfiling.event(
                    DriftProfiling.Signpost.timerLifecycle,
                    message: "clockTick cancel"
                )
            }
        }
    }

    func stopTimers() {
        if tickConnection != nil {
            tickConnection?.cancel()
            tickConnection = nil
            DriftProfiling.event(
                DriftProfiling.Signpost.timerLifecycle,
                message: "sleepTick cancel stopTimers"
            )
        }
        if clockConnection != nil {
            clockConnection?.cancel()
            clockConnection = nil
            DriftProfiling.event(
                DriftProfiling.Signpost.timerLifecycle,
                message: "clockTick cancel stopTimers"
            )
        }
        cancelAutoDriftTimers(emitSignposts: false)
    }

    func resetAutoDriftClock() {
        SleepAndDriftController.resetAutoDriftClock(state: &sleepState)
    }

    func triggerImmediateAutoDriftIfPossible(engine: DriftlyEngine, scenePhase: ScenePhase) {
        guard engine.isAutoDriftOperational else { return }
        guard scenePhase == .active, !sleepState.sleepTimerHasExpired else { return }

        let intervalSeconds = Double(max(1, engine.autoDriftIntervalMinutes) * 60)
        sleepState.lastAutoDriftChange = Date().addingTimeInterval(-intervalSeconds)

        DriftProfiling.event(
            DriftProfiling.Signpost.autoDriftSchedule,
            message: "profiling immediateAutoDriftTrigger"
        )
        updateAutoDriftScheduling(engine: engine, scenePhase: scenePhase)
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
        guard engine.isAutoDriftOperational, currentScenePhase == .active, !sleepState.sleepTimerHasExpired else {
            cancelAutoDriftTimers(emitSignposts: false)
            return
        }

        let intervalSeconds = Double(max(1, engine.autoDriftIntervalMinutes) * 60)
        let now = Date()
        let nextDriftDate = sleepState.lastAutoDriftChange.addingTimeInterval(intervalSeconds)

        if nextDriftDate <= now {
            cancelAutoDriftTimers(emitSignposts: false)
            DriftProfiling.event(
                DriftProfiling.Signpost.autoDriftSchedule,
                message: "nextDrift immediate"
            )
            performAutoDrift(engine: engine)
            return
        }

        // Frequent scheduling refresh calls can happen during mode/settings updates.
        // Keep an existing one-shot if it's already targeting the same fire date.
        if let existingFireDate = autoDriftFireTimer?.fireDate,
           abs(existingFireDate.timeIntervalSince(nextDriftDate)) < 0.001 {
            return
        }

        cancelAutoDriftTimers(emitSignposts: false)

        schedulePrewarmTimer(fireDate: nextDriftDate, engine: engine)

        let fireTimer = Timer(fire: nextDriftDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.autoDriftFireTimer = nil
                DriftProfiling.event(
                    DriftProfiling.Signpost.taskLifecycle,
                    message: "task create source=autoDriftTimer"
                )
                self.performAutoDrift(engine: engine)
            }
        }
        autoDriftFireTimer = fireTimer
        RunLoop.main.add(fireTimer, forMode: .common)
        if lastSignpostedAutoDriftFireDate != nextDriftDate {
            DriftProfiling.event(
                DriftProfiling.Signpost.timerLifecycle,
                message: "autoDriftFire create fireAt=\(nextDriftDate.timeIntervalSinceReferenceDate)"
            )
            lastSignpostedAutoDriftFireDate = nextDriftDate
        }
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
            DriftProfiling.event(
                DriftProfiling.Signpost.prewarmPrepare,
                message: "apply immediate"
            )
            setPrewarmMode(engine: engine)
            return
        }

        let timer = Timer(fire: prewarmDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.prewarmFireTimer = nil
                DriftProfiling.event(
                    DriftProfiling.Signpost.taskLifecycle,
                    message: "task create source=prewarmTimer"
                )
                self.setPrewarmMode(engine: engine)
            }
        }
        prewarmFireTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        if lastSignpostedPrewarmFireDate != prewarmDate {
            DriftProfiling.event(
                DriftProfiling.Signpost.timerLifecycle,
                message: "prewarmFire create fireAt=\(prewarmDate.timeIntervalSinceReferenceDate)"
            )
            lastSignpostedPrewarmFireDate = prewarmDate
        }
    }

    private func setPrewarmMode(engine: DriftlyEngine) {
        guard engine.isAutoDriftOperational, !sleepState.sleepTimerHasExpired else {
            prewarmMode = nil
            DriftProfiling.event(
                DriftProfiling.Signpost.prewarmPrepare,
                message: "clear unavailable"
            )
            return
        }

        let heavyPrewarmModes: Set<DriftMode> = [.photonRain, .voxelMirage, .inkTopography]
        let next = engine.peekNextAutoDriftMode(after: engine.currentMode)
        prewarmMode = heavyPrewarmModes.contains(next) ? nil : next
        DriftProfiling.event(
            DriftProfiling.Signpost.prewarmPrepare,
            message: "next=\(next.rawValue) selected=\(prewarmMode?.rawValue ?? "none")"
        )
    }

    private func performAutoDrift(engine: DriftlyEngine) {
        let currentMode = engine.currentMode
        let interval = DriftProfiling.begin(
            DriftProfiling.Signpost.autoDriftApply,
            message: "from=\(currentMode.rawValue)"
        )
        defer {
            DriftProfiling.end(
                DriftProfiling.Signpost.autoDriftApply,
                interval,
                message: "to=\(engine.currentMode.rawValue)"
            )
        }

        cancelAutoDriftTimers()

        guard engine.isAutoDriftOperational, currentScenePhase == .active, !sleepState.sleepTimerHasExpired else {
            prewarmMode = nil
            DriftProfiling.event(
                DriftProfiling.Signpost.autoDriftApply,
                message: "skip operational=\(engine.isAutoDriftOperational) phase=\(Self.phaseName(currentScenePhase)) expired=\(sleepState.sleepTimerHasExpired)"
            )
            return
        }

        let now = Date()
        let nextMode = engine.nextAutoDriftMode(after: engine.currentMode)
        DriftProfiling.event(
            DriftProfiling.Signpost.autoDriftSelect,
            message: "from=\(engine.currentMode.rawValue) to=\(nextMode.rawValue)"
        )

        engine.currentMode = nextMode
        DriftProfiling.event(
            DriftProfiling.Signpost.modeTransition,
            message: "source=autoDrift from=\(currentMode.rawValue) to=\(nextMode.rawValue)"
        )
        DriftHaptics.autoDriftTick()
        sleepState.lastAutoDriftChange = now
        prewarmMode = nil

        scheduleAutoDriftTimers(engine: engine)
    }

    private func cancelAutoDriftTimers(emitSignposts: Bool = true) {
        if autoDriftFireTimer != nil {
            autoDriftFireTimer?.invalidate()
            if emitSignposts {
                DriftProfiling.event(
                    DriftProfiling.Signpost.timerLifecycle,
                    message: "autoDriftFire cancel"
                )
            }
        }
        autoDriftFireTimer = nil
        lastSignpostedAutoDriftFireDate = nil
        if prewarmFireTimer != nil {
            prewarmFireTimer?.invalidate()
            if emitSignposts {
                DriftProfiling.event(
                    DriftProfiling.Signpost.timerLifecycle,
                    message: "prewarmFire cancel"
                )
            }
        }
        prewarmFireTimer = nil
        lastSignpostedPrewarmFireDate = nil
        if prewarmMode != nil {
            if emitSignposts {
                DriftProfiling.event(
                    DriftProfiling.Signpost.prewarmPrepare,
                    message: "prewarmMode clear"
                )
            }
        }
        prewarmMode = nil
    }

    private func setSleepAwakeStateIfNeeded() {
        if sleepState.sleepTimerHasExpired {
            sleepState.sleepTimerHasExpired = false
        }
        if sleepState.sleepTimerAllowsLock {
            sleepState.sleepTimerAllowsLock = false
        }
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

    private static func phaseName(_ phase: ScenePhase) -> String {
        switch phase {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
}
