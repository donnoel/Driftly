import SwiftUI
import UIKit
import Combine
import os

struct DriftlyRootView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @EnvironmentObject private var preferences: DriftlyPreferencesState
    @EnvironmentObject private var sleepDrift: DriftlySleepDriftControlState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @StateObject private var coordinator: DriftlyRootCoordinator
    @State private var motionUnavailable = false
    @State private var brightnessDragLastTranslation: CGFloat = 0
    @State private var profilingSessionStart: Date?
    @State private var profilingPreviousMode: DriftMode?
    @State private var profilingTransitionCount: Int = 0
    @State private var profilingImmediateAutoDriftTriggered = false
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
            .overlay(brightnessDarkeningOverlay)
            .overlay(alignment: .topTrailing, content: { brightnessHUDOverlay })
            .overlay(alignment: .top, content: { motionUnavailableOverlay })
            .overlay {
                if coordinator.sleepState.sleepTimerHasExpired {
                    sleepOverlay
                }
            }
            .overlay(alignment: .topLeading, content: { clockOverlay })
            .overlay(alignment: .topTrailing, content: { profilingDebugOverlay })
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
                    preferences.isChromeVisible.toggle()
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
                preferences.isChromeVisible = true
                focusedButton = .modePicker
            }
        }
#endif
        .onAppear {
            handleRootAppear()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: preferences.preventAutoLock) { _, _ in
            updateIdleTimer()
        }
#if os(tvOS)
        .onChange(of: preferences.isChromeVisible) { _, isVisible in
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
        .onChange(of: sleepDrift.autoDriftEnabled) { _, newValue in
            if newValue && engine.isAutoDriftOperational {
                coordinator.resetAutoDriftClock()
            }
            coordinator.updateTicking(engine: engine, scenePhase: scenePhase)
            coordinator.updateAutoDriftScheduling(engine: engine, scenePhase: scenePhase)
        }
        .onChange(of: sleepDrift.autoDriftIntervalMinutes) { _, _ in
            if engine.isAutoDriftOperational {
                coordinator.resetAutoDriftClock()
            }
            coordinator.updateAutoDriftScheduling(engine: engine, scenePhase: scenePhase)
        }
        .onChange(of: engine.currentMode) { oldMode, newMode in
            guard oldMode != newMode else { return }
            if DriftProfiling.profilingOverlayEnabled {
                profilingPreviousMode = oldMode
                profilingTransitionCount &+= 1
            }
            if engine.isAutoDriftOperational {
                coordinator.resetAutoDriftClock()
            }
            coordinator.updateAutoDriftScheduling(engine: engine, scenePhase: scenePhase)
        }
        .onChange(of: preferences.clockEnabled) { _, _ in
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
                    .environmentObject(preferences)
            }
#else
            .sheet(isPresented: $coordinator.isModePickerPresented) {
                DriftModePickerView()
                    .environmentObject(engine)
                    .environmentObject(preferences)
                    .modifier(IPadModePickerSheetModifier())
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
                    applySleepTimer(minutes: nil)
                }
                .accessibilityIdentifier("Off")
                Button("15 minutes") {
                    applySleepTimer(minutes: 15)
                }
                .accessibilityIdentifier("15 minutes")
                Button("30 minutes") {
                    applySleepTimer(minutes: 30)
                }
                .accessibilityIdentifier("30 minutes")
                Button("60 minutes") {
                    applySleepTimer(minutes: 60)
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
                    .environmentObject(preferences)
                    .environmentObject(sleepDrift)
            }
#else
            .sheet(isPresented: $coordinator.isSettingsPresented) {
                DriftlySettingsView()
                    .environmentObject(engine)
                    .environmentObject(preferences)
                    .environmentObject(sleepDrift)
                    .modifier(IPadSettingsSheetModifier())
            }
#endif
#if os(iOS)
            // Custom sleep timer picker
            .sheet(isPresented: $coordinator.isCustomSleepTimerPresented) {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    NavigationStack {
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.06, green: 0.08, blue: 0.15),
                                    Color(red: 0.08, green: 0.08, blue: 0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .ignoresSafeArea()

                            VStack(spacing: 14) {
                                Text("Custom Sleep Timer")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.94))

                                // Dial-style picker with haptic feedback
                                Picker("", selection: $coordinator.customSleepMinutes) {
                                    ForEach(Array(stride(from: 5, through: 240, by: 5)), id: \.self) { minutes in
                                        Text("\(minutes) min").tag(minutes)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 220, height: 170)
                                .onChange(of: coordinator.customSleepMinutes) { _, _ in
                                    DriftHaptics.settingsAdjusted()
                                }

                                Text("Choose when Driftly should fade to rest.")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.66))
                                    .padding(.top, 2)

                                Spacer(minLength: 0)
                            }
                            .frame(width: 360, height: 320)
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                        }
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Set") {
                                    applySleepTimer(minutes: coordinator.customSleepMinutes)
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
                    .preferredColorScheme(.dark)
                    .presentationDetents([.fraction(0.56)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
                } else {
                    NavigationStack {
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.05, green: 0.07, blue: 0.14),
                                    Color(red: 0.09, green: 0.08, blue: 0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .ignoresSafeArea()

                            VStack(spacing: 22) {
                                Text("Custom Sleep Timer")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.94))

                                // Dial-style picker with haptic feedback
                                ZStack {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(.ultraThinMaterial.opacity(0.56))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 8)

                                    Picker("", selection: $coordinator.customSleepMinutes) {
                                        ForEach(Array(stride(from: 5, through: 240, by: 5)), id: \.self) { minutes in
                                            Text("\(minutes) min").tag(minutes)
                                        }
                                    }
#if !os(tvOS)
                                    .pickerStyle(.wheel)
#endif
                                    .frame(width: 300, height: 250)
                                    .onChange(of: coordinator.customSleepMinutes) { _, _ in
                                        DriftHaptics.settingsAdjusted()
                                    }
                                }
                                .frame(width: 390, height: 290)

                                Spacer(minLength: 0)
                            }
                            .frame(width: 620, height: 520)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        }
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Set") {
                                    applySleepTimer(minutes: coordinator.customSleepMinutes)
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
                    .preferredColorScheme(.dark)
                    .modifier(IPadSleepTimerSheetModifier())
                }
            }
#endif
            .onDisappear {
                coordinator.stopTimers()
#if os(tvOS)
                UIApplication.shared.isIdleTimerDisabled = false
#endif
            }
    }

    private var brightnessDarkeningOverlay: some View {
        Color.black
            .opacity(coordinator.sleepState.sleepTimerHasExpired ? 1 : (1 - preferences.brightness))
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var brightnessHUDOverlay: some View {
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

    @ViewBuilder
    private var motionUnavailableOverlay: some View {
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

    @ViewBuilder
    private var clockOverlay: some View {
        if preferences.clockEnabled && !coordinator.sleepState.sleepTimerHasExpired {
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

    @ViewBuilder
    private var profilingDebugOverlay: some View {
        if DriftProfiling.profilingOverlayEnabled {
            profilingOverlay
                .padding(.top, profilingOverlayTopPadding)
                .padding(.trailing, 16)
        }
    }

    private func handleRootAppear() {
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
                    if preferences.isChromeVisible {
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

            if DriftProfiling.profilingSessionEnabled {
                if profilingSessionStart == nil {
                    profilingSessionStart = Date()
                }
                if DriftProfiling.profilingImmediateAutoDriftEnabled, !profilingImmediateAutoDriftTriggered {
                    profilingImmediateAutoDriftTriggered = true
                    coordinator.triggerImmediateAutoDriftIfPossible(engine: engine, scenePhase: scenePhase)
                }
            }
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        let interval = DriftProfiling.begin(
            DriftProfiling.Signpost.scenePhaseChange,
            message: "phase=\(scenePhaseName(newPhase)) mode=\(engine.currentMode.rawValue)"
        )
        defer {
            DriftProfiling.end(
                DriftProfiling.Signpost.scenePhaseChange,
                interval,
                message: "phase=\(scenePhaseName(newPhase)) mode=\(engine.currentMode.rawValue)"
            )
        }

        if newPhase == .background {
            engine.flushPendingBrightnessPersistence()
            engine.flushPendingScenePersistence()
        }
        coordinator.handleScenePhaseChange(to: newPhase)
        updateIdleTimer()
        updateClockTicking()
        coordinator.updateTicking(engine: engine, scenePhase: newPhase)
        coordinator.updateAutoDriftScheduling(engine: engine, scenePhase: newPhase)
#if DEBUG
        DebugMetrics.uiSignposter.emitEvent("ui.safeAreaChanged")
        DebugMetrics.uiSignposter.emitEvent("ui.appearanceChanged")
#endif
    }

    private func applySleepTimer(minutes: Int?) {
        withAnimation(.easeInOut(duration: 0.6)) {
            coordinator.applySleepTimerSelection(minutes: minutes, engine: engine, scenePhase: scenePhase)
        }
        updateIdleTimer()
        DriftHaptics.sleepTimerSet()
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
                    isChromeVisible: preferences.isChromeVisible,
                    brightness: preferences.brightness,
                    motionUnavailable: $motionUnavailable
                )
            }
            
            if preferences.isChromeVisible && !coordinator.sleepState.sleepTimerHasExpired {
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
            modeDescriptor: DriftModePresentationCatalog.descriptor(for: engine.currentMode),
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
            modeDescriptor: DriftModePresentationCatalog.descriptor(for: engine.currentMode),
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
                .foregroundStyle(.white.opacity(0.96))
            
#if os(tvOS)
            Text("Press Home to exit Driftly, or wake to continue.")
                .font(.footnote)
                .foregroundStyle(.secondary)
#else
            Text("Tap to wake Driftly, or press Home to exit.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.72))
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
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.95))
            .background(sleepOverlayButtonBackground)
            .controlSize(.large)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .frame(maxWidth: 500)
        .background(sleepOverlayBackground)
        .transition(.opacity)
    }

    private var sleepOverlayBackground: some View {
#if os(iOS)
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.76))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                chromeTint.opacity(0.09),
                                Color.black.opacity(0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: .black.opacity(0.42), radius: 24, x: 0, y: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
#else
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(chromeTint.opacity(0.08))
            )
            .shadow(color: .black.opacity(0.38), radius: 22, x: 0, y: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
#endif
    }

    private var sleepOverlayButtonBackground: some View {
#if os(iOS)
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
#else
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
#endif
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
            preventAutoLock: preferences.preventAutoLock,
            sleepTimerAllowsLock: coordinator.sleepState.sleepTimerAllowsLock,
            scenePhase: scenePhase
        )
        UIApplication.shared.isIdleTimerDisabled = prevent
#elseif os(tvOS)
        UIApplication.shared.isIdleTimerDisabled = shouldPreventLockTvOS(
            preventAutoLock: preferences.preventAutoLock,
            sleepTimerAllowsLock: coordinator.sleepState.sleepTimerAllowsLock,
            scenePhase: scenePhase
        )
#endif
    }
    
    private func updateClockTicking() {
        coordinator.updateClockTicking(clockEnabled: preferences.clockEnabled, scenePhase: scenePhase)
    }
    
    // MARK: - Sleep timer tick & auto drift
    
    private func handleSleepTimerTick(now: Date) {
        let transition = coordinator.processSleepTimerTick(
            now: now,
            engine: engine,
            scenePhase: scenePhase
        )

        switch transition {
        case .expired:
            updateIdleTimer()
#if os(tvOS)
            // Drop focus target while asleep to avoid stray focus highlights.
            focusedButton = nil
            fallbackFocus = false
#endif
        case .woke:
            updateIdleTimer()
        case .none:
            break
        }
    }
    
    private func adjustBrightness(by delta: Double) {
        let performChange = {
            let proposed = preferences.brightness + Double(delta)
            let clamped = max(0.2, min(1.0, proposed))
            
#if os(iOS)
            if (proposed < 0.2 && preferences.brightness > 0.2) ||
                (proposed > 1.0 && preferences.brightness < 1.0) {
                DriftHaptics.brightnessLimitHit()
            }
#endif
            
            preferences.brightness = clamped
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
            let willShow = !preferences.isChromeVisible
            withAnimation(.easeInOut(duration: 0.35)) {
                preferences.isChromeVisible = willShow
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
            coordinator.wakeFromSleep(engine: engine, scenePhase: scenePhase)
        }
        updateIdleTimer()
#if os(tvOS)
        // Restore fallback focus so remote commands still arrive when chrome is hidden.
        fallbackFocus = !preferences.isChromeVisible
#endif
    }
    
    private var sleepTimerActive: Bool {
        sleepDrift.sleepTimerEndDate != nil && !coordinator.sleepState.sleepTimerHasExpired
    }

    private var sleepTimerStatusText: String {
        guard let end = sleepDrift.sleepTimerEndDate else { return "Timer off" }
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
            base: preferences.animationSpeed,
            reduceMotion: reduceMotion,
            respectSystemReduceMotion: preferences.respectSystemReduceMotion
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

    private var profilingOverlayTopPadding: CGFloat {
        coordinator.brightnessHUDVisible && !coordinator.sleepState.sleepTimerHasExpired ? 62 : 18
    }

    @ViewBuilder
    private var profilingOverlay: some View {
        VStack(alignment: .leading, spacing: 3) {
            profilingLine("Mode", engine.currentMode.rawValue)
            profilingLine("Prev", profilingPreviousMode?.rawValue ?? "none")
            profilingLine("Transitions", "\(profilingTransitionCount)")
            HStack(spacing: 6) {
                Text("Elapsed")
                if let profilingSessionStart {
                    Text(profilingSessionStart, style: .timer)
                } else {
                    Text("0:00")
                }
            }
            profilingLine("AutoDrift", sleepDrift.autoDriftEnabled ? "enabled" : "disabled")
            profilingLine("Operational", engine.isAutoDriftOperational ? "yes" : "no")
        }
        .font(.caption2.monospaced())
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func profilingLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
            Text(value)
        }
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

    private func scenePhaseName(_ phase: ScenePhase) -> String {
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

#if os(iOS)
private struct IPadModePickerSheetModifier: ViewModifier {
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPad {
            if #available(iOS 17.0, *) {
                content
                    .presentationDetents([.large])
                    .presentationSizing(.page)
                    .presentationDragIndicator(.visible)
            } else {
                content
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        } else {
            content
        }
    }
}

private struct IPadSettingsSheetModifier: ViewModifier {
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPad {
            if #available(iOS 17.0, *) {
                content
                    .presentationDetents([.large])
                    .presentationSizing(.page)
                    .presentationDragIndicator(.visible)
            } else {
                content
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        } else {
            content
        }
    }
}

private struct IPadSleepTimerSheetModifier: ViewModifier {
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPad {
            if #available(iOS 17.0, *) {
                content
                    .presentationDetents([.large])
                    .presentationSizing(.page)
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
                    .presentationBackground(.ultraThinMaterial)
            } else {
                content
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
                    .presentationBackground(.ultraThinMaterial)
            }
        } else {
            content
        }
    }
}
#endif

// MARK: - tvOS Sleep Timer (Apple-style screens)
#if os(tvOS)
extension DriftlyRootView {
    private func setSleepTimerTvOS(minutes: Int?) {
        applySleepTimer(minutes: minutes)
    }
    
    private struct SleepTimerScreenTV: View {
        let statusText: String
        let isActive: Bool
        let onSetMinutes: (Int?) -> Void
        let onCancel: () -> Void

        private let commonDurations: [Int] = [15, 30, 60]
        private let moreDurations: [Int] = [5, 10, 20, 45, 90, 120, 180, 240]

        // --- Focus enum and state ---
        private enum FocusRow: Hashable {
            case off
            case common(Int)
            case more
        }

        @FocusState private var focusedRow: FocusRow?
        @State private var isShowingMoreDurations = false

        private func primary(_ text: String, focused: Bool) -> some View {
            Text(text)
                .foregroundStyle(.white)
        }

        private func secondary(_ text: String, focused: Bool) -> some View {
            Text(text)
                .foregroundStyle(Color.white.opacity(0.70))
        }

        @ViewBuilder
        private func timerRowSurface<Content: View>(focused: Bool, @ViewBuilder content: () -> Content) -> some View {
            content()
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(focused ? 0.06 : 0.04))

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(focused ? 0.14 : 0.08),
                                lineWidth: focused ? 1.1 : 0.9
                            )

                        if focused {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.28),
                                            Color.white.opacity(0.10),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.15
                                )
                                .padding(1)
                        }
                    }
                }
                .shadow(
                    color: focused ? Color.white.opacity(0.035) : Color.black.opacity(0.16),
                    radius: focused ? 10 : 4,
                    x: 0,
                    y: focused ? 6 : 2
                )
                .scaleEffect(focused ? 1.015 : 1.0)
                .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: focused)
        }

        private var ambientBackground: some View {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.03, blue: 0.06),
                        Color(red: 0.04, green: 0.05, blue: 0.09),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 40,
                    endRadius: 560
                )
                .blendMode(.screen)
                .offset(x: -140, y: -160)
            }
            .ignoresSafeArea()
        }

        private var introCard: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: isActive ? "moon.zzz.fill" : "moon.zzz")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isActive ? .yellow.opacity(0.92) : .white.opacity(0.82))

                    Text("Sleep Timer")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Text("Choose when Driftly should wind down on Apple TV.")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.72))

                Text(statusText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.86))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    }
            )
        }

        private var timerChoicesPanel: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Common")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.38))
                            .textCase(nil)

                        VStack(spacing: 12) {
                            timerChoiceRow(
                                title: "Off",
                                focused: focusedRow == .off,
                                focusValue: .off,
                                action: { onSetMinutes(nil) }
                            )

                            ForEach(commonDurations, id: \.self) { minutes in
                                timerChoiceRow(
                                    title: "\(minutes) minutes",
                                    focused: focusedRow == .common(minutes),
                                    focusValue: .common(minutes),
                                    action: { onSetMinutes(minutes) }
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("More")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.38))
                            .textCase(nil)

                        timerChoiceRow(
                            title: "More durations",
                            trailingText: "5-240 min",
                            focused: focusedRow == .more,
                            focusValue: .more,
                            action: {
                                isShowingMoreDurations = true
                            }
                        )
                    }
                }
                .padding(24)
            }
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.24))
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
            )
            .navigationDestination(isPresented: $isShowingMoreDurations) {
                MoreDurationsView(
                    durations: moreDurations,
                    onSetMinutes: onSetMinutes
                )
            }
        }

        private func timerChoiceRow(
            title: String,
            trailingText: String? = nil,
            focused: Bool,
            focusValue: FocusRow,
            action: @escaping () -> Void
        ) -> some View {
            timerRowSurface(focused: focused) {
                HStack(spacing: 16) {
                    primary(title, focused: focused)
                        .font(.headline.weight(.semibold))

                    Spacer(minLength: 12)

                    if let trailingText {
                        secondary(trailingText, focused: focused)
                            .font(.headline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .focusable(true)
            .focusEffectDisabled()
            .focused($focusedRow, equals: focusValue)
            .onTapGesture {
                action()
            }
        }

        var body: some View {
            ZStack {
                ambientBackground

                NavigationStack {
                    GeometryReader { proxy in
                        let contentWidth = min(max(proxy.size.width - 140, 1220), 1700)
                        let introWidth = min(max(contentWidth * 0.31, 390), 520)

                        HStack(alignment: .top, spacing: 34) {
                            introCard
                                .frame(width: introWidth)

                            timerChoicesPanel
                                .frame(maxWidth: .infinity, minHeight: 700, maxHeight: 820, alignment: .top)
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 54)
                        .padding(.bottom, 44)
                    }
                    .padding(.horizontal, 70)
                    .navigationTitle("Sleep Timer")
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
            .onExitCommand {
                onCancel()
            }
            .preferredColorScheme(.dark)
        }

        private struct MoreDurationsView: View {
            let durations: [Int]
            let onSetMinutes: (Int?) -> Void

            @FocusState private var focusedMinutes: Int?

            private var ambientBackground: some View {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.03, blue: 0.06),
                            Color(red: 0.04, green: 0.05, blue: 0.09),
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 40,
                        endRadius: 560
                    )
                    .blendMode(.screen)
                    .offset(x: -140, y: -160)
                }
                .ignoresSafeArea()
            }

            private func primary(_ text: String, focused: Bool) -> some View {
                Text(text)
                    .foregroundStyle(.white)
            }

            @ViewBuilder
            private func timerRowSurface<Content: View>(focused: Bool, @ViewBuilder content: () -> Content) -> some View {
                content()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(focused ? 0.06 : 0.04))

                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    Color.white.opacity(focused ? 0.14 : 0.08),
                                    lineWidth: focused ? 1.1 : 0.9
                                )

                            if focused {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.28),
                                                Color.white.opacity(0.10),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.15
                                    )
                                    .padding(1)
                            }
                        }
                    }
                    .shadow(
                        color: focused ? Color.white.opacity(0.035) : Color.black.opacity(0.16),
                        radius: focused ? 10 : 4,
                        x: 0,
                        y: focused ? 6 : 2
                    )
                    .scaleEffect(focused ? 1.015 : 1.0)
                    .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: focused)
            }

            var body: some View {
                ZStack {
                    ambientBackground

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(durations, id: \.self) { minutes in
                                timerRowSurface(focused: focusedMinutes == minutes) {
                                    primary("\(minutes) minutes", focused: focusedMinutes == minutes)
                                        .font(.headline.weight(.semibold))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .focusable(true)
                                .focusEffectDisabled()
                                .focused($focusedMinutes, equals: minutes)
                                .onTapGesture {
                                    onSetMinutes(minutes)
                                }
                            }
                        }
                        .padding(24)
                    }
                    .frame(maxWidth: 980)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.black.opacity(0.28))
                            .overlay {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            }
                    )
                    .padding(.horizontal, 56)
                    .padding(.vertical, 36)
                }
                .background(Color.clear)
                .navigationTitle("More Durations")
                .toolbar(.hidden, for: .navigationBar)
            }
        }
    }
}
#endif
