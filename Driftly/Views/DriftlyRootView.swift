import SwiftUI
import UIKit
import Combine

struct DriftlyRootView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var motionManager = DriftMotionManager()
    @State private var sleepState = SleepAndDriftController.State()
    @State private var tickTimer = Timer.publish(every: 1, on: .main, in: .common)
    @State private var tickConnection: Cancellable?
    @State private var isModePickerPresented: Bool
    @State private var isSettingsPresented = false
    @State private var isSleepTimerDialogPresented: Bool
    @State private var isCustomSleepTimerPresented = false
    @State private var customSleepMinutes: Int = 20
    @State private var brightnessHUDVisible = false
    @State private var brightnessHUDValue: Double = 1.0
    @State private var brightnessHUDHideWorkItem: DispatchWorkItem?
#if os(tvOS)
    @FocusState private var focusedButton: FocusTarget?
    @FocusState private var fallbackFocus: Bool

    private enum FocusTarget: Hashable {
        case modePicker, sleepTimer, settings
    }
#endif

    init(testOverrides: (modePicker: Bool, sleepDialog: Bool)? = nil) {
        let args = ProcessInfo.processInfo.arguments
        let defaultModePicker = args.contains("UITestingOpenModePicker")
        let defaultSleepDialog = args.contains("UITestingOpenSleepTimer")

        _isModePickerPresented = State(initialValue: testOverrides?.modePicker ?? defaultModePicker)
        _isSleepTimerDialogPresented = State(initialValue: testOverrides?.sleepDialog ?? defaultSleepDialog)
    }

#if DEBUG
    // Test-only helpers
    var test_isModePickerPresented: Bool { isModePickerPresented }
    var test_isSleepTimerDialogPresented: Bool { isSleepTimerDialogPresented }
#endif
    
    var body: some View {
        ZStack {
            if !sleepState.sleepTimerHasExpired {
                activeModeView
                    .offset(motionManager.parallaxOffset)
                    .scaleEffect(1.03) // tiny scale so edges don’t reveal gaps when moving
                    .id(engine.currentMode) // ensures clean crossfade per mode
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.9), value: engine.currentMode)
                    .ignoresSafeArea()
            }

            // Minimal chrome (hidden when asleep)
            if engine.isChromeVisible && !sleepState.sleepTimerHasExpired {
                VStack {
                    Spacer()
                    bottomChrome
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
            Color.clear
                .frame(width: 1, height: 1)
                .focusable(true)
                .focused($fallbackFocus)
#endif
        }
        // Screen darkening overlay based on brightness
        .overlay(
            Color.black
                .opacity(1 - engine.brightness)
                .allowsHitTesting(false)
        )
        .overlay(alignment: .topTrailing) {
            if brightnessHUDVisible {
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
            if motionManager.motionUnavailable {
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
            if sleepState.sleepTimerHasExpired {
                VStack(spacing: 10) {
                    Text("Sleep timer ended")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Tap to wake Driftly")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity)
            }
        }
        // Global animation speed for all lamp views
        .environment(\.driftAnimationSpeed, engine.animationSpeed)
        .environment(\.driftAnimationsPaused, sleepState.sleepTimerHasExpired || scenePhase != .active)
        .background(Color.black)
        .ignoresSafeArea()
#if os(iOS)
        .statusBar(hidden: true)
#endif
#if os(iOS)
        .onTapGesture {
            if sleepState.sleepTimerHasExpired {
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
        .onPlayPauseCommand {
            toggleChromeTvOS(forceToggle: true)
        }
        .onTapGesture {
            if sleepState.sleepTimerHasExpired {
                wakeFromSleepTimer()
                return
            }
            // Only toggle when nothing is focused (chrome hidden)
            if focusedButton == nil {
                toggleChromeTvOS(forceToggle: true)
            }
        }
        .onMoveCommand { direction in
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
            DispatchQueue.main.async {
                applyUITestOverridesIfNeeded()
                updateIdleTimer()
                SleepAndDriftController.resetAutoDriftClock(state: &sleepState)
                updateMotionSampling()
                startMotionIfNeeded()
                updateTicking()
#if os(tvOS)
                if engine.isChromeVisible {
                    focusedButton = .modePicker
                    fallbackFocus = false
                }
                UIApplication.shared.beginReceivingRemoteControlEvents()
#endif
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            updateIdleTimer()
            handleMotion(for: newPhase)
            updateMotionSampling()
            updateTicking()
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
                SleepAndDriftController.resetAutoDriftClock(state: &sleepState)
            }
            updateTicking()
        }
        .onChange(of: engine.autoDriftIntervalMinutes) { _, _ in
            if engine.autoDriftEnabled {
                SleepAndDriftController.resetAutoDriftClock(state: &sleepState)
            }
        }
        .onChange(of: engine.currentMode) { _, _ in
            if engine.autoDriftEnabled {
                SleepAndDriftController.resetAutoDriftClock(state: &sleepState)
            }
        }
        .onChange(of: engine.brightness) { _, _ in
            updateMotionSampling()
        }
        .onChange(of: engine.isChromeVisible) { _, _ in
            updateMotionSampling()
        }
        .onReceive(tickTimer) { now in
            handleSleepTimerTick(now: now)
        }
        // Mode picker (sparkles)
        .sheet(isPresented: $isModePickerPresented) {
            DriftModePickerView()
                .environmentObject(engine)
        }
        // Sleep timer picker (moon)
        .confirmationDialog(
            "Sleep Timer",
            isPresented: $isSleepTimerDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Off") {
                engine.setSleepTimer(minutes: nil)
                withAnimation(.easeInOut(duration: 0.6)) {
                    sleepState.sleepTimerHasExpired = false
                }
                sleepState.sleepTimerAllowsLock = false
                updateIdleTimer()
                startMotionIfNeeded()
                DriftHaptics.sleepTimerSet()
                updateTicking()
            }
            .accessibilityIdentifier("Off")
            Button("15 minutes") {
                engine.setSleepTimer(minutes: 15)
                withAnimation(.easeInOut(duration: 0.6)) {
                    sleepState.sleepTimerHasExpired = false
                }
                sleepState.sleepTimerAllowsLock = false
                startMotionIfNeeded()
                DriftHaptics.sleepTimerSet()
                updateTicking()
            }
            .accessibilityIdentifier("15 minutes")
            Button("30 minutes") {
                engine.setSleepTimer(minutes: 30)
                withAnimation(.easeInOut(duration: 0.6)) {
                    sleepState.sleepTimerHasExpired = false
                }
                sleepState.sleepTimerAllowsLock = false
                startMotionIfNeeded()
                DriftHaptics.sleepTimerSet()
                updateTicking()
            }
            .accessibilityIdentifier("30 minutes")
            Button("60 minutes") {
                engine.setSleepTimer(minutes: 60)
                withAnimation(.easeInOut(duration: 0.6)) {
                    sleepState.sleepTimerHasExpired = false
                }
                sleepState.sleepTimerAllowsLock = false
                startMotionIfNeeded()
                DriftHaptics.sleepTimerSet()
                updateTicking()
            }
            .accessibilityIdentifier("60 minutes")
            Button("Custom…") {
                customSleepMinutes = 20
                isCustomSleepTimerPresented = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(sleepTimerStatusText)
        }
        // Settings sheet (gear)
        .sheet(isPresented: $isSettingsPresented) {
            DriftlySettingsView()
                .environmentObject(engine)
        }
        // Custom sleep timer picker
        .sheet(isPresented: $isCustomSleepTimerPresented) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Custom Sleep Timer")
                        .font(.headline)

                    // Dial-style picker with haptic feedback
                    Picker("", selection: $customSleepMinutes) {
                        ForEach(Array(stride(from: 5, through: 240, by: 5)), id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    #if !os(tvOS)
                    .pickerStyle(.wheel)
                    #endif
                    .frame(width: 200, height: 160)
                    .onChange(of: customSleepMinutes) { _, _ in
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
                            engine.setSleepTimer(minutes: customSleepMinutes)
                            withAnimation(.easeInOut(duration: 0.6)) {
                                sleepState.sleepTimerHasExpired = false
                            }
                            sleepState.sleepTimerAllowsLock = false
                            startMotionIfNeeded()
                            DriftHaptics.sleepTimerSet()
                            updateTicking()
                            isCustomSleepTimerPresented = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isCustomSleepTimerPresented = false
                        }
                    }
                }
            }
            .presentationDetents([.fraction(0.55)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(22)
        }
        .onDisappear {
            tickConnection?.cancel()
            tickConnection = nil
            #if os(tvOS)
            UIApplication.shared.endReceivingRemoteControlEvents()
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
    }
    
    // MARK: - Active mode
    
    @ViewBuilder
    private var activeModeView: some View {
        switch engine.currentMode {
        case .nebulaLake:
            NebulaLakeView(config: engine.currentMode.config)
        case .cosmicTide:
            CosmicTideView(config: engine.currentMode.config)
        case .auroraVeil:
            AuroraVeilView(config: engine.currentMode.config)
        case .abyssGlow:
            AbyssGlowView(config: engine.currentMode.config)
        case .starlitMist:
            StarlitMistView(config: engine.currentMode.config)
        case .lunarDrift:
            LunarDriftView(config: engine.currentMode.config)
        case .solarBloom:
            SolarBloomView(config: engine.currentMode.config)
        case .plasmaReef:
            PlasmaReefView(config: engine.currentMode.config)
        case .velvetEclipse:
            VelvetEclipseView(config: engine.currentMode.config)
        case .neonKelp:
            NeonKelpView(config: engine.currentMode.config)
        case .emberDrift:
            EmberDriftView(config: engine.currentMode.config)
        // Batch 2 cases
        case .pulseAurora:
            PulseAuroraView(config: engine.currentMode.config)
        case .vitalWave:
            VitalWaveView(config: engine.currentMode.config)
        case .echoBloom:
            EchoBloomView(config: engine.currentMode.config)
        case .cosmicHeart:
            CosmicHeartView(config: engine.currentMode.config)
        case .signalDrift:
            SignalDriftView(config: engine.currentMode.config)
        // Batch 3 cases
        case .horizonPulse:
            HorizonPulseView(config: engine.currentMode.config)
        case .photonRain:
            PhotonRainView(config: engine.currentMode.config)
        case .gravityRings:
            GravityRingsView(config: engine.currentMode.config)
        case .driftGrid:
            DriftGridView(config: engine.currentMode.config)
        case .quietSignal:
            QuietSignalView(config: engine.currentMode.config)
        // Batch 4 cases
        case .chromaticSpine:
            ChromaticSpineView(config: engine.currentMode.config)
        case .ribbonOrbit:
            RibbonOrbitView(config: engine.currentMode.config)
        case .inkTopography:
            InkTopographyView(config: engine.currentMode.config)
        case .prismShards:
            PrismShardsView(config: engine.currentMode.config)
        case .lissajousBloom:
            LissajousBloomView(config: engine.currentMode.config)
        case .meridianArcs:
            MeridianArcsView(config: engine.currentMode.config)
        case .spectralLoom:
            SpectralLoomView(config: engine.currentMode.config)
        case .voxelMirage:
            VoxelMirageView(config: engine.currentMode.config)
        case .haloInterference:
            HaloInterferenceView(config: engine.currentMode.config)
        }
    }
    
    // MARK: - Chrome
    
    private var bottomChrome: some View {
        HStack(spacing: 16) {
            // Left: current mode
            VStack(alignment: .leading, spacing: 4) {
                Text(engine.currentMode.displayName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                
                Text("Tap name to change • Tap anywhere to hide controls")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
#if os(tvOS)
                    .opacity(0.0) // hide small helper text on tvOS
#endif
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.35)) {
                    engine.goToNextMode()
                }
                DriftHaptics.modeChanged()
            }
            
            Spacer()
            
            // Right: tiny buttons
            HStack(spacing: isTvOSDevice ? 24 : 12) {
                CircleButton(systemName: "sparkles", action: {
                    isModePickerPresented = true
                }, accessibilityIdentifier: "modePickerButton", isTvOS: isTvOSDevice)
#if os(tvOS)
                .focused($focusedButton, equals: .modePicker)
#endif
                
                CircleButton(systemName: "moon.zzz", action: {
                    isSleepTimerDialogPresented = true
                }, accessibilityIdentifier: "sleepTimerButton", isActive: sleepTimerActive, isTvOS: isTvOSDevice)
#if os(tvOS)
                .focused($focusedButton, equals: .sleepTimer)
#endif
                
                CircleButton(systemName: "gearshape", action: {
                    isSettingsPresented = true
                }, accessibilityIdentifier: "settingsButton", isTvOS: isTvOSDevice)
#if os(tvOS)
                .focused($focusedButton, equals: .settings)
#endif
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.35))
                .blur(radius: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.08))
                )
        )
    }
    
    private struct CircleButton: View {
        let systemName: String
        let action: () -> Void
        var accessibilityIdentifier: String? = nil
        var isActive: Bool = false
        var isTvOS: Bool = false
        
        var body: some View {
            Button(action: action) {
                let tint = isActive ? Color.yellow.opacity(0.95) : Color.white.opacity(0.95)
                let size: CGFloat = isTvOS ? 40 : 36
                let fontSize: CGFloat = isTvOS ? 16 : 15
                Image(systemName: systemName)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: size, height: size)
                    .background(
                        Circle()
                            .fill(isActive ? Color.white.opacity(0.14) : Color.black.opacity(0.45))
                            .blur(radius: 0.5)
                            .overlay(
                                Circle()
                                    .stroke(tint.opacity(0.6))
                            )
                    )
            }
            .accessibilityIdentifier(accessibilityIdentifier ?? systemName)
            .buttonStyle(.plain)
        }
    }
    
    private var isTvOSDevice: Bool {
#if os(tvOS)
        true
#else
        false
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
                        // Drag up (negative height) → increase brightness
                        // Drag down (positive height) → decrease brightness
                        adjustBrightness(by: -value.translation.height / 1800.0)
                    }
            )
#endif
    }
    
    // MARK: - Idle timer handling
    
    private func updateIdleTimer() {
#if os(iOS)
        let prevent = shouldPreventLock(
            preventAutoLock: engine.preventAutoLock,
            sleepTimerAllowsLock: sleepState.sleepTimerAllowsLock,
            scenePhase: scenePhase
        )
        UIApplication.shared.isIdleTimerDisabled = prevent
#elseif os(tvOS)
        // Keep Driftly in the foreground on tvOS by preventing the screen saver while active/awake.
        let prevent = !sleepState.sleepTimerAllowsLock && !sleepState.sleepTimerHasExpired && scenePhase == .active
        UIApplication.shared.isIdleTimerDisabled = prevent
#endif
    }

    private func handleMotion(for phase: ScenePhase) {
#if os(iOS)
        guard !sleepState.sleepTimerHasExpired else {
            motionManager.stopUpdates()
            return
        }
        MotionPhaseHandler.updateMotion(for: phase, motionController: motionManager)
#endif
    }

    private func startMotionIfNeeded() {
#if os(iOS)
        guard !sleepState.sleepTimerHasExpired, scenePhase == .active else { return }
        updateMotionSampling()
        motionManager.startIfNeeded()
#endif
    }

    private func updateMotionSampling() {
#if os(iOS)
        motionManager.updateSampling(
            brightness: engine.brightness,
            isChromeVisible: engine.isChromeVisible
        )
#endif
    }
    
    // MARK: - Sleep timer tick & auto drift
    
    private func handleSleepTimerTick(now: Date) {
        guard SleepAndDriftController.shouldTick(engine: engine, state: sleepState) else { return }

        let actions = SleepAndDriftController.handleTick(now: now, engine: engine, state: &sleepState)

        for action in actions {
            switch action {
            case .expire:
                withAnimation(.easeInOut(duration: 1.5)) {
                    sleepState.sleepTimerHasExpired = true
                }
                updateIdleTimer()
                stopMotionForSleep()
            case .wake:
                withAnimation(.easeInOut(duration: 0.8)) {
                    sleepState.sleepTimerHasExpired = false
                }
                sleepState.sleepTimerAllowsLock = false
                updateIdleTimer()
                startMotionIfNeeded()
            case .autoDrift:
                withAnimation(.easeInOut(duration: 0.9)) {
                    engine.currentMode = engine.nextAutoDriftMode(after: engine.currentMode)
                }
                DriftHaptics.autoDriftTick()
            }
        }

        updateTicking()
    }

    private func updateTicking() {
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

    private func stopMotionForSleep() {
#if os(iOS)
        motionManager.stopUpdates()
#endif
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
            showBrightnessHUD(for: clamped)
        }

#if os(tvOS)
        DispatchQueue.main.async(execute: performChange)
#else
        performChange()
#endif
    }

#if os(tvOS)
    private func toggleChromeTvOS(forceToggle: Bool) {
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

    private func applyUITestOverridesIfNeeded() {
#if DEBUG
        guard ProcessInfo.processInfo.arguments.contains(where: { arg in
            arg == "UITestingForceChromeVisible" ||
            arg == "UITestingOpenModePicker" ||
            arg == "UITestingOpenSleepTimer"
        }) else { return }

        DispatchQueue.main.async {
            if ProcessInfo.processInfo.arguments.contains("UITestingForceChromeVisible") {
                engine.isChromeVisible = true
            }
        }
#endif
    }

    private func wakeFromSleepTimer() {
        withAnimation(.easeInOut(duration: 0.8)) {
            sleepState.sleepTimerHasExpired = false
        }
        sleepState.sleepTimerAllowsLock = false
        SleepAndDriftController.resetAutoDriftClock(state: &sleepState)
        updateIdleTimer()
        startMotionIfNeeded()
        updateTicking()
    }

    private var sleepTimerActive: Bool {
        engine.sleepTimerEndDate != nil && !sleepState.sleepTimerHasExpired
    }

    private var sleepTimerStatusText: String {
        guard let end = engine.sleepTimerEndDate else { return "Timer off" }
        let remaining = Int(max(0, end.timeIntervalSince(Date()) / 60))
        if remaining <= 0 { return "Timer ended" }
        return "Time remaining: \(remaining) min"
    }

    private func showBrightnessHUD(for value: Double) {
        brightnessHUDValue = value
        withAnimation(.easeInOut(duration: 0.15)) {
            brightnessHUDVisible = true
        }

        brightnessHUDHideWorkItem?.cancel()
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.35)) {
                brightnessHUDVisible = false
            }
        }
        brightnessHUDHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private var brightnessLabel: String {
        let percent = Int((brightnessHUDValue * 100).rounded())
        return "\(percent)%"
    }
}
