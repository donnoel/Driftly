import SwiftUI
import UIKit
import Combine
import os

struct DriftlyRootView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @StateObject private var coordinator: DriftlyRootCoordinator
    @State private var motionUnavailable = false
    @State private var brightnessDragLastTranslation: CGFloat = 0
#if DEBUG
    private let testInitialModePickerPresented: Bool
    private let testInitialSleepTimerDialogPresented: Bool
#endif
#if os(tvOS)
    @FocusState private var focusedButton: ChromeFocusTarget?
    @FocusState private var fallbackFocus: Bool
#endif
    
    init(testOverrides: (modePicker: Bool, sleepDialog: Bool)? = nil) {
#if DEBUG
        let flags = Self.initialPresentationFlags(testOverrides: testOverrides)
        self.testInitialModePickerPresented = flags.modePicker
        self.testInitialSleepTimerDialogPresented = flags.sleepDialog
#endif
        _coordinator = StateObject(wrappedValue: DriftlyRootCoordinator(testOverrides: testOverrides))
    }
    
#if DEBUG
    // Test-only helpers
    var test_isModePickerPresented: Bool { testInitialModePickerPresented }
    var test_isSleepTimerDialogPresented: Bool { testInitialSleepTimerDialogPresented }
#endif
    
    var body: some View {
        baseContent
            // Screen darkening overlay based on brightness
            .overlay(
                Color.black
                    .opacity(coordinator.sleepState.sleepTimerHasExpired ? 1 : (1 - engine.brightness))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
            .overlay(alignment: .topTrailing) {
                if coordinator.brightnessHUDVisible && !coordinator.sleepState.sleepTimerHasExpired {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(.yellow.opacity(0.95))
                        Text(brightnessLabel)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.top, 18)
                    .padding(.trailing, 16)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .top) {
                if motionUnavailable && !coordinator.sleepState.sleepTimerHasExpired {
                    Text("Motion unavailable")
                        .font(.caption2.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(.top, 18)
                        .padding(.horizontal, 16)
                }
            }
            .overlay {
                if coordinator.sleepState.sleepTimerHasExpired {
                    sleepOverlay
                }
            }
            .overlay(alignment: .topLeading) {
                if engine.clockEnabled && !coordinator.sleepState.sleepTimerHasExpired {
                    let style = clockStyle(for: engine.currentMode, idiom: UIDevice.current.userInterfaceIdiom)
                    GeometryReader { proxy in
                        ClockOverlayView(
                            time: coordinator.clockNow,
                            style: style,
                            anchorDate: coordinator.phaseAnchorDate,
                            containerSize: proxy.size
                        )
                        .padding(.top, 18)
                        .padding(.leading, 16)
                    }
                }
            }
            // Global animation speed for all lamp views
            .environment(\.driftPhaseAnchorDate, coordinator.phaseAnchorDate)
            .environment(\.driftAnimationSpeed, effectiveAnimationSpeed)
            .environment(\.driftAnimationsPaused, coordinator.sleepState.sleepTimerHasExpired || scenePhase != .active)
            .background(Color.black)
            .ignoresSafeArea()
#if os(iOS)
            .statusBar(hidden: true)
#endif
#if DEBUG
            .task {
                DebugMetrics.startHeartbeat()
            }
#endif
#if os(iOS)
            .onTapGesture {
                if coordinator.sleepState.sleepTimerHasExpired {
                    wakeFromSleepTimer()
                    return
                }
#if DEBUG
                if ProcessInfo.processInfo.arguments.contains("UITestingNoChromeToggle") {
                    return
                }
#endif
                withAnimation(.easeInOut(duration: 0.35)) {
                    engine.isChromeVisible.toggle()
                }
                DriftHaptics.chromeToggled()
            }
#elseif os(tvOS)
        // Leave Play/Pause for media; use tap and long-press on the touch surface for UI.
        .onTapGesture {
            if coordinator.sleepState.sleepTimerHasExpired {
                wakeFromSleepTimer()
                return
            }
            // Only toggle when nothing is focused (chrome hidden)
            if focusedButton == nil {
                toggleChromeTvOS()
            }
        }
#if os(tvOS)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    handlePlayPauseCommand()
                }
        )
#endif
        .onMoveCommand { direction in
            // Do not intercept directional navigation while a sheet/screen is presented.
            // This keeps tvOS Lists (Settings, Sleep Timer) scrollable and focus-friendly.
            guard !coordinator.isSettingsPresented, !coordinator.isSleepTimerDialogPresented, !coordinator.isModePickerPresented else {
                return
            }
            
            // Only use up/down for brightness when chrome is hidden; otherwise let focus/navigation work normally.
            guard focusedButton == nil else {
                return
            }
            
            switch direction {
            case .up:
                adjustBrightness(by: 0.04)
            case .down:
                adjustBrightness(by: -0.04)
            default:
                break
            }
        }
        .onExitCommand {
            withAnimation(.easeInOut(duration: 0.35)) {
                engine.isChromeVisible = true
                focusedButton = .modePicker
            }
        }
#endif
        .onAppear {
            // Defer setup work until the next runloop to avoid mutating state
            // while SwiftUI is still computing the initial view update.
            DispatchQueue.main.async { @MainActor in
#if os(tvOS)
                coordinator.runInitialSetupIfNeeded(
                    engine: engine,
                    scenePhase: scenePhase,
                    updateIdleTimer: updateIdleTimer,
                    updateClockTicking: updateClockTicking,
                    focusChromeIfNeeded: {
                        if engine.isChromeVisible {
                            focusedButton = .modePicker
                            fallbackFocus = false
                        }
                    }
                )
#else
                coordinator.runInitialSetupIfNeeded(
                    engine: engine,
                    scenePhase: scenePhase,
                    updateIdleTimer: updateIdleTimer,
                    updateClockTicking: updateClockTicking
                )
#endif
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                engine.flushPendingScenePersistence()
            }
            coordinator.handleScenePhaseChange(to: newPhase)
            updateIdleTimer()
            updateClockTicking()
            coordinator.updateTicking(engine: engine, scenePhase: newPhase)
            #if DEBUG
            DebugMetrics.uiSignposter.emitEvent("ui.safeAreaChanged")
            DebugMetrics.uiSignposter.emitEvent("ui.appearanceChanged")
            #endif
        }
        .onChange(of: engine.preventAutoLock) { _, _ in
            updateIdleTimer()
        }
#if os(tvOS)
        .onChange(of: engine.isChromeVisible) { _, isVisible in
            DispatchQueue.main.async {
                if isVisible {
                    focusedButton = .modePicker
                    fallbackFocus = false
                } else {
                    focusedButton = nil
                    fallbackFocus = true
                }
            }
        }
#endif
        .onChange(of: engine.autoDriftEnabled) { _, newValue in
            if newValue {
                coordinator.resetAutoDriftClock()
            }
            coordinator.updateTicking(engine: engine, scenePhase: scenePhase)
        }
        .onChange(of: engine.autoDriftIntervalMinutes) { _, _ in
            if engine.autoDriftEnabled {
                coordinator.resetAutoDriftClock()
            }
        }
        .onChange(of: engine.currentMode) { _, _ in
            if engine.autoDriftEnabled {
                coordinator.resetAutoDriftClock()
            }
        }
        .onChange(of: engine.clockEnabled) { _, _ in
            updateClockTicking()
        }
        .onReceive(coordinator.tickTimer) { now in
            handleSleepTimerTick(now: now)
        }
        .onReceive(coordinator.clockTimer) { now in
            coordinator.clockNow = now
        }
            // Mode picker (sparkles)
#if os(tvOS)
            .fullScreenCover(isPresented: $coordinator.isModePickerPresented) {
                DriftModePickerView()
                    .environmentObject(engine)
            }
#else
            .sheet(isPresented: $coordinator.isModePickerPresented) {
                DriftModePickerView()
                    .environmentObject(engine)
            }
#endif
            // Sleep timer picker (moon)
#if os(iOS)
            .confirmationDialog(
                "Sleep Timer",
                isPresented: $coordinator.isSleepTimerDialogPresented,
                titleVisibility: .visible
            ) {
                Button("Off") {
                    engine.setSleepTimer(minutes: nil)
                    withAnimation(.easeInOut(duration: 0.6)) {
                        coordinator.sleepState.sleepTimerHasExpired = false
                    }
                    coordinator.sleepState.sleepTimerAllowsLock = false
                    updateIdleTimer()
                    DriftHaptics.sleepTimerSet()
                    coordinator.updateTicking(engine: engine, scenePhase: scenePhase)
                    updateClockTicking()
                }
                .accessibilityIdentifier("Off")
                Button("15 minutes") {
                    engine.setSleepTimer(minutes: 15)
                    withAnimation(.easeInOut(duration: 0.6)) {
                        coordinator.sleepState.sleepTimerHasExpired = false
                    }
                    coordinator.sleepState.sleepTimerAllowsLock = false
                    updateIdleTimer()
                    DriftHaptics.sleepTimerSet()
                    coordinator.updateTicking(engine: engine, scenePhase: scenePhase)
                    updateClockTicking()
                }
                .accessibilityIdentifier("15 minutes")
                Button("30 minutes") {
                    engine.setSleepTimer(minutes: 30)
                    withAnimation(.easeInOut(duration: 0.6)) {
                        coordinator.sleepState.sleepTimerHasExpired = false
                    }
                    coordinator.sleepState.sleepTimerAllowsLock = false
                    updateIdleTimer()
                    DriftHaptics.sleepTimerSet()
                    coordinator.updateTicking(engine: engine, scenePhase: scenePhase)
                    updateClockTicking()
                }
                .accessibilityIdentifier("30 minutes")
                Button("60 minutes") {
                    engine.setSleepTimer(minutes: 60)
                    withAnimation(.easeInOut(duration: 0.6)) {
                        coordinator.sleepState.sleepTimerHasExpired = false
                    }
                    coordinator.sleepState.sleepTimerAllowsLock = false
                    updateIdleTimer()
                    DriftHaptics.sleepTimerSet()
                    coordinator.updateTicking(engine: engine, scenePhase: scenePhase)
                    updateClockTicking()
                }
                .accessibilityIdentifier("60 minutes")
                Button("Custom…") {
                    coordinator.customSleepMinutes = 20
                    coordinator.isCustomSleepTimerPresented = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(sleepTimerStatusText)
            }
#elseif os(tvOS)
            .fullScreenCover(isPresented: $coordinator.isSleepTimerDialogPresented) {
                SleepTimerScreenTV(
                    statusText: sleepTimerStatusText,
                    isActive: sleepTimerActive,
                    onSetMinutes: { minutes in
                        setSleepTimerTvOS(minutes: minutes)
                        coordinator.isSleepTimerDialogPresented = false
                    },
                    onCancel: {
                        coordinator.isSleepTimerDialogPresented = false
                    }
                )
            }
#endif
            // Settings sheet (gear)
#if os(tvOS)
            .fullScreenCover(isPresented: $coordinator.isSettingsPresented) {
                DriftlySettingsView()
                    .environmentObject(engine)
            }
#else
            .sheet(isPresented: $coordinator.isSettingsPresented) {
                DriftlySettingsView()
                    .environmentObject(engine)
            }
#endif
#if os(iOS)
            // Custom sleep timer picker
            .sheet(isPresented: $coordinator.isCustomSleepTimerPresented) {
                NavigationStack {
                    VStack(spacing: 16) {
                        Text("Custom Sleep Timer")
                            .font(.headline)
                        
                        // Dial-style picker with haptic feedback
                        Picker("", selection: $coordinator.customSleepMinutes) {
                            ForEach(Array(stride(from: 5, through: 240, by: 5)), id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
#if !os(tvOS)
                        .pickerStyle(.wheel)
#endif
                        .frame(width: 200, height: 160)
                        .onChange(of: coordinator.customSleepMinutes) { _, _ in
                            DriftHaptics.settingsAdjusted()
                        }
                        
                        Spacer()
                    }
                    .frame(width: 360, height: 360)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Set") {
                                engine.setSleepTimer(minutes: coordinator.customSleepMinutes)
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    coordinator.sleepState.sleepTimerHasExpired = false
                                }
                                coordinator.sleepState.sleepTimerAllowsLock = false
                                updateIdleTimer()
                                DriftHaptics.sleepTimerSet()
                                coordinator.updateTicking(engine: engine, scenePhase: scenePhase)
                                updateClockTicking()
                                coordinator.isCustomSleepTimerPresented = false
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                coordinator.isCustomSleepTimerPresented = false
                            }
                        }
                    }
                }
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(22)
            }
#endif
            .onDisappear {
                coordinator.stopTimers()
#if os(tvOS)
                UIApplication.shared.isIdleTimerDisabled = false
#endif
            }
    }

    @ViewBuilder
    private var baseContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !coordinator.sleepState.sleepTimerHasExpired {
                DriftSceneRendererView(
                    currentMode: engine.currentMode,
                    prewarmMode: coordinator.prewarmMode,
                    scenePhase: scenePhase,
                    reduceMotion: reduceMotion,
                    sleepTimerHasExpired: coordinator.sleepState.sleepTimerHasExpired,
                    isChromeVisible: engine.isChromeVisible,
                    brightness: engine.brightness,
                    motionUnavailable: $motionUnavailable
                )
            }
            
            if engine.isChromeVisible && !coordinator.sleepState.sleepTimerHasExpired {
                VStack {
                    Spacer()
                    chromeBarView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 32)
                        .padding(.horizontal, 24)
                }
            }
            
            // Edge brightness gesture zones (left & right)
#if os(iOS)
            HStack {
                brightnessEdgeView(isLeading: true)
                Spacer()
                brightnessEdgeView(isLeading: false)
            }
#elseif os(tvOS)
            // Keep a tiny focusable target so Play/Pause commands are delivered even when chrome is hidden.
            if !coordinator.sleepState.sleepTimerHasExpired {
                Color.clear
                    .frame(width: 1, height: 1)
                    .focusable(true)
                    .focused($fallbackFocus)
            }
#endif
        }
    }
    
    @ViewBuilder
    private var chromeBarView: some View {
#if os(tvOS)
        ChromeBarView(
            modeName: engine.currentMode.displayName,
            chromeTint: chromeTint,
            isTvOS: isTvOSDevice,
            sleepTimerActive: sleepTimerActive,
            onModePicker: { coordinator.isModePickerPresented = true },
            onSleepTimer: { coordinator.isSleepTimerDialogPresented = true },
            onSettings: { coordinator.isSettingsPresented = true },
            onNextMode: { engine.goToNextMode() },
            focusedButton: $focusedButton
        )
#else
        ChromeBarView(
            modeName: engine.currentMode.displayName,
            chromeTint: chromeTint,
            isTvOS: isTvOSDevice,
            sleepTimerActive: sleepTimerActive,
            onModePicker: { coordinator.isModePickerPresented = true },
            onSleepTimer: { coordinator.isSleepTimerDialogPresented = true },
            onSettings: { coordinator.isSettingsPresented = true },
            onNextMode: { engine.goToNextMode() }
        )
#endif
    }
    
    private var sleepOverlay: some View {
        VStack(spacing: 14) {
            Text("Sleep timer ended")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            
#if os(tvOS)
            Text("Press Home to exit Driftly, or wake to continue.")
                .font(.footnote)
                .foregroundStyle(.secondary)
#else
            Text("Tap to wake Driftly, or press Home to exit.")
                .font(.footnote)
                .foregroundStyle(.secondary)
#endif
            
            Button {
                wakeFromSleepTimer()
            } label: {
                Text("Wake Driftly")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .controlSize(.large)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 24)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .transition(.opacity)
    }
    
    // MARK: - Brightness edges
    
    private func brightnessEdgeView(isLeading: Bool) -> some View {
#if os(tvOS)
        Rectangle().fill(Color.clear).frame(width: 44)
#else
        Rectangle()
            .fill(Color.clear)
            .frame(width: 44)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        // Use incremental delta so brightness changes smoothly instead of compounding total translation.
                        let delta = value.translation.height - brightnessDragLastTranslation
                        brightnessDragLastTranslation = value.translation.height
                        // Drag up (negative height) → increase brightness
                        // Drag down (positive height) → decrease brightness
                        adjustBrightness(by: -delta / 1800.0)
                    }
                    .onEnded { _ in
                        brightnessDragLastTranslation = 0
                    }
            )
#endif
    }
    
    // MARK: - Idle timer handling
    
    private func updateIdleTimer() {
#if os(iOS)
        let prevent = shouldPreventLock(
            preventAutoLock: engine.preventAutoLock,
            sleepTimerAllowsLock: coordinator.sleepState.sleepTimerAllowsLock,
            scenePhase: scenePhase
        )
        UIApplication.shared.isIdleTimerDisabled = prevent
#elseif os(tvOS)
        UIApplication.shared.isIdleTimerDisabled = shouldPreventLockTvOS(
            preventAutoLock: engine.preventAutoLock,
            sleepTimerAllowsLock: coordinator.sleepState.sleepTimerAllowsLock,
            scenePhase: scenePhase
        )
#endif
    }
    
    private func updateClockTicking() {
        coordinator.updateClockTicking(clockEnabled: engine.clockEnabled, scenePhase: scenePhase)
    }
    
    // MARK: - Sleep timer tick & auto drift
    
    private func handleSleepTimerTick(now: Date) {
        let actions = coordinator.handleTick(now: now, engine: engine)
        
        for action in actions {
            switch action {
            case .expire:
                withAnimation(.easeInOut(duration: 1.5)) {
                    coordinator.sleepState.sleepTimerHasExpired = true
                }
                updateIdleTimer()
#if os(tvOS)
                // Drop focus target while asleep to avoid stray focus highlights.
                focusedButton = nil
                fallbackFocus = false
#endif
            case .wake:
                withAnimation(.easeInOut(duration: 0.8)) {
                    coordinator.sleepState.sleepTimerHasExpired = false
                }
                coordinator.sleepState.sleepTimerAllowsLock = false
                updateIdleTimer()
            case .autoDrift:
                withAnimation(.easeInOut(duration: 0.9)) {
                    engine.currentMode = engine.nextAutoDriftMode(after: engine.currentMode)
                }
                DriftHaptics.autoDriftTick()
            }
        }
        
        coordinator.updateTicking(engine: engine, scenePhase: scenePhase)
        coordinator.updateClockTicking(clockEnabled: engine.clockEnabled, scenePhase: scenePhase)
    }
    
    private func adjustBrightness(by delta: Double) {
        let performChange = {
            let proposed = engine.brightness + Double(delta)
            let clamped = max(0.2, min(1.0, proposed))
            
#if os(iOS)
            if (proposed < 0.2 && engine.brightness > 0.2) ||
                (proposed > 1.0 && engine.brightness < 1.0) {
                DriftHaptics.brightnessLimitHit()
            }
#endif
            
            engine.brightness = clamped
            coordinator.showBrightnessHUD(for: clamped)
        }
        
#if os(tvOS)
        DispatchQueue.main.async(execute: performChange)
#else
        performChange()
#endif
    }
    
#if os(tvOS)
    private func toggleChromeTvOS() {
        DispatchQueue.main.async {
            let willShow = !engine.isChromeVisible
            withAnimation(.easeInOut(duration: 0.35)) {
                engine.isChromeVisible = willShow
            }
            focusedButton = willShow ? .modePicker : nil
            fallbackFocus = !willShow
        }
    }
#endif
    
#if os(tvOS)
    private func handlePlayPauseCommand() {
        if coordinator.sleepState.sleepTimerHasExpired {
            wakeFromSleepTimer()
        } else {
            toggleChromeTvOS()
        }
    }
#endif
    
    private func wakeFromSleepTimer() {
        withAnimation(.easeInOut(duration: 0.8)) {
            coordinator.sleepState.sleepTimerHasExpired = false
        }
        coordinator.sleepState.sleepTimerAllowsLock = false
        coordinator.resetAutoDriftClock()
        updateIdleTimer()
        updateClockTicking()
        coordinator.updateTicking(engine: engine, scenePhase: scenePhase)
#if os(tvOS)
        // Restore fallback focus so remote commands still arrive when chrome is hidden.
        fallbackFocus = !engine.isChromeVisible
#endif
    }
    
    private var sleepTimerActive: Bool {
        engine.sleepTimerEndDate != nil && !coordinator.sleepState.sleepTimerHasExpired
    }
    
    private var sleepTimerStatusText: String {
        guard let end = engine.sleepTimerEndDate else { return "Timer off" }
        let remaining = Int(max(0, end.timeIntervalSince(Date()) / 60))
        if remaining <= 0 { return "Timer ended" }
        return "Time remaining: \(remaining) min"
    }
    
    private var brightnessLabel: String {
        let percent = Int((coordinator.brightnessHUDValue * 100).rounded())
        return "\(percent)%"
    }
    
    private var effectiveAnimationSpeed: Double {
        DriftAnimationPolicy.effectiveSpeed(
            base: engine.animationSpeed,
            reduceMotion: reduceMotion,
            respectSystemReduceMotion: engine.respectSystemReduceMotion
        )
    }
    
    private var isTvOSDevice: Bool {
#if os(tvOS)
        true
#else
        false
#endif
    }
    
    private var chromeTint: Color {
        engine.currentMode.config.palette.primary
    }

#if DEBUG
    private static func initialPresentationFlags(testOverrides: (modePicker: Bool, sleepDialog: Bool)?) -> (modePicker: Bool, sleepDialog: Bool) {
        let args = ProcessInfo.processInfo.arguments
        let defaultModePicker = args.contains("UITestingOpenModePicker")
        let defaultSleepDialog = args.contains("UITestingOpenSleepTimer")
        return (
            testOverrides?.modePicker ?? defaultModePicker,
            testOverrides?.sleepDialog ?? defaultSleepDialog
        )
    }
#endif
}

// MARK: - tvOS Sleep Timer (Apple-style screens)
#if os(tvOS)
extension DriftlyRootView {
    private func setSleepTimerTvOS(minutes: Int?) {
        engine.setSleepTimer(minutes: minutes)
        withAnimation(.easeInOut(duration: 0.6)) {
            coordinator.sleepState.sleepTimerHasExpired = false
        }
        coordinator.sleepState.sleepTimerAllowsLock = false
        updateIdleTimer()
        DriftHaptics.sleepTimerSet()
        coordinator.updateTicking(engine: engine, scenePhase: scenePhase)
        updateClockTicking()
    }
    
    private struct SleepTimerScreenTV: View {
        let statusText: String
        let isActive: Bool
        let onSetMinutes: (Int?) -> Void
        let onCancel: () -> Void
        
        private let commonDurations: [Int] = [15, 30, 60]
        private let moreDurations: [Int] = [5, 10, 20, 45, 90, 120, 180, 240]
        
        var body: some View {
            ZStack {
                // Force a stable, high-contrast backdrop regardless of the underlying mode.
                Color.black.ignoresSafeArea()
                
                NavigationStack {
                    List {
                        Section {
                            Text(statusText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 6)
                        }
                        
                        Section {
                            Button {
                                onSetMinutes(nil)
                            } label: {
                                Text("Off")
                                    .font(.headline)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(.primary)
                            }
                            
                            ForEach(commonDurations, id: \.self) { minutes in
                                Button {
                                    onSetMinutes(minutes)
                                } label: {
                                    Text("\(minutes) minutes")
                                        .font(.headline)
                                        .padding(.vertical, 6)
                                        .foregroundStyle(.primary)
                                }
                            }
                        } header: {
                            Text("Common")
                        }
                        
                        Section {
                            NavigationLink {
                                MoreDurationsView(
                                    durations: moreDurations,
                                    onSetMinutes: onSetMinutes
                                )
                            } label: {
                                HStack {
                                    Text("More durations")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("5–240 min")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.headline)
                                .padding(.vertical, 6)
                            }
                        } header: {
                            Text("More")
                        }
                    }
                    .listStyle(.plain)
                    // Prevent system list backgrounds from switching to light/gray.
                    .modifier(HideListBackground())
                    .navigationTitle("Sleep Timer")
                    .tint(.white)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Image(systemName: isActive ? "moon.zzz.fill" : "moon.zzz")
                                .foregroundStyle(isActive ? .yellow.opacity(0.92) : .secondary)
                        }
                    }
                }
            }
            // tvOS is effectively always dark in system apps; enforce it for legibility.
            .onExitCommand {
                onCancel()
            }
            .preferredColorScheme(.dark)
        }
        
        private struct MoreDurationsView: View {
            let durations: [Int]
            let onSetMinutes: (Int?) -> Void
            
            var body: some View {
                List {
                    Section {
                        ForEach(durations, id: \.self) { minutes in
                            Button {
                                onSetMinutes(minutes)
                            } label: {
                                Text("\(minutes) minutes")
                                    .font(.headline)
                                    .padding(.vertical, 6)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .modifier(HideListBackground())
                .tint(.white)
                .navigationTitle("More Durations")
            }
        }
        
        private struct HideListBackground: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .background(Color.black)
                    .onAppear {
                        // Keep List backgrounds consistently dark on tvOS.
                        UITableView.appearance().backgroundColor = .black
                        UITableViewCell.appearance().backgroundColor = .black
                    }
            }
        }
    }
}
#endif
