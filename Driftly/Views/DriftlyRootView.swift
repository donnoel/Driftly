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
    @State private var clockTimer = Timer.publish(every: 1, on: .main, in: .common)
    @State private var clockConnection: Cancellable?
    @State private var clockNow = Date()
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
            // Base background so sleep state never shows white
            Color.black.ignoresSafeArea()

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
            if !sleepState.sleepTimerHasExpired {
                Color.clear
                    .frame(width: 1, height: 1)
                    .focusable(true)
                    .focused($fallbackFocus)
            }
#endif
        }
        // Screen darkening overlay based on brightness
        .overlay(
            Color.black
                .opacity(sleepState.sleepTimerHasExpired ? 1 : (1 - engine.brightness))
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
        .overlay(alignment: .topTrailing) {
            if brightnessHUDVisible && !sleepState.sleepTimerHasExpired {
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
            if motionManager.motionUnavailable && !sleepState.sleepTimerHasExpired {
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
        }
        .overlay(alignment: .topLeading) {
            if engine.clockEnabled && !sleepState.sleepTimerHasExpired {
                let style = Self.clockStyle(for: engine.currentMode)
                ClockOverlay(
                    time: clockNow,
                    style: style
                )
                .padding(.top, 18)
                .padding(.leading, 16)
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
        // Leave Play/Pause for media; use tap and long-press on the touch surface for UI.
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
            guard !isSettingsPresented, !isSleepTimerDialogPresented, !isModePickerPresented else {
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
            DispatchQueue.main.async {
                applyUITestOverridesIfNeeded()
                updateIdleTimer()
                updateClockTicking()
                SleepAndDriftController.resetAutoDriftClock(state: &sleepState)
                updateMotionSampling()
                startMotionIfNeeded()
                updateTicking()
#if os(tvOS)
                if engine.isChromeVisible {
                    focusedButton = .modePicker
                    fallbackFocus = false
                }
#endif
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            updateIdleTimer()
            updateClockTicking()
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
        .onChange(of: engine.clockEnabled) { _, _ in
            updateClockTicking()
        }
        .onReceive(tickTimer) { now in
            handleSleepTimerTick(now: now)
        }
        .onReceive(clockTimer) { now in
            clockNow = now
        }
        // Mode picker (sparkles)
#if os(tvOS)
        .fullScreenCover(isPresented: $isModePickerPresented) {
            DriftModePickerView()
                .environmentObject(engine)
        }
#else
        .sheet(isPresented: $isModePickerPresented) {
            DriftModePickerView()
                .environmentObject(engine)
        }
#endif
        // Sleep timer picker (moon)
#if os(iOS)
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
                updateClockTicking()
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
                updateClockTicking()
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
                updateClockTicking()
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
                updateClockTicking()
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
#elseif os(tvOS)
        .fullScreenCover(isPresented: $isSleepTimerDialogPresented) {
            SleepTimerScreenTV(
                statusText: sleepTimerStatusText,
                isActive: sleepTimerActive,
                onSetMinutes: { minutes in
                    setSleepTimerTvOS(minutes: minutes)
                    isSleepTimerDialogPresented = false
                },
                onCancel: {
                    isSleepTimerDialogPresented = false
                }
            )
        }
#endif
        // Settings sheet (gear)
#if os(tvOS)
        .fullScreenCover(isPresented: $isSettingsPresented) {
            DriftlySettingsView()
                .environmentObject(engine)
        }
#else
        .sheet(isPresented: $isSettingsPresented) {
            DriftlySettingsView()
                .environmentObject(engine)
        }
#endif
#if os(iOS)
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
#endif
        .onDisappear {
            tickConnection?.cancel()
            tickConnection = nil
#if os(tvOS)
            UIApplication.shared.isIdleTimerDisabled = false
#endif
            clockConnection?.cancel()
            clockConnection = nil
        }
    }
    
    // MARK: - Active mode
    
    @ViewBuilder
    private var activeModeView: some View {
        if sleepState.sleepTimerHasExpired {
            Color.black.ignoresSafeArea()
        } else {
            if let builder = Self.modeViewBuilders[engine.currentMode] {
                builder(engine.currentMode.config)
            } else {
                Color.black
            }
        }
    }

    static let modeViewBuilders: [DriftMode: (DriftModeConfig) -> AnyView] = [
        .nebulaLake: { AnyView(NebulaLakeView(config: $0)) },
        .cosmicTide: { AnyView(CosmicTideView(config: $0)) },
        .auroraVeil: { AnyView(AuroraVeilView(config: $0)) },
        .abyssGlow: { AnyView(AbyssGlowView(config: $0)) },
        .starlitMist: { AnyView(StarlitMistView(config: $0)) },
        .lunarDrift: { AnyView(LunarDriftView(config: $0)) },
        .solarBloom: { AnyView(SolarBloomView(config: $0)) },
        .plasmaReef: { AnyView(PlasmaReefView(config: $0)) },
        .velvetEclipse: { AnyView(VelvetEclipseView(config: $0)) },
        .neonKelp: { AnyView(NeonKelpView(config: $0)) },
        .emberDrift: { AnyView(EmberDriftView(config: $0)) },
        .pulseAurora: { AnyView(PulseAuroraView(config: $0)) },
        .vitalWave: { AnyView(VitalWaveView(config: $0)) },
        .echoBloom: { AnyView(EchoBloomView(config: $0)) },
        .cosmicHeart: { AnyView(CosmicHeartView(config: $0)) },
        .signalDrift: { AnyView(SignalDriftView(config: $0)) },
        .horizonPulse: { AnyView(HorizonPulseView(config: $0)) },
        .photonRain: { AnyView(PhotonRainView(config: $0)) },
        .gravityRings: { AnyView(GravityRingsView(config: $0)) },
        .driftGrid: { AnyView(DriftGridView(config: $0)) },
        .quietSignal: { AnyView(QuietSignalView(config: $0)) },
        .chromaticSpine: { AnyView(ChromaticSpineView(config: $0)) },
        .ribbonOrbit: { AnyView(RibbonOrbitView(config: $0)) },
        .inkTopography: { AnyView(InkTopographyView(config: $0)) },
        .prismShards: { AnyView(PrismShardsView(config: $0)) },
        .lissajousBloom: { AnyView(LissajousBloomView(config: $0)) },
        .meridianArcs: { AnyView(MeridianArcsView(config: $0)) },
        .spectralLoom: { AnyView(SpectralLoomView(config: $0)) },
        .voxelMirage: { AnyView(VoxelMirageView(config: $0)) },
        .haloInterference: { AnyView(HaloInterferenceView(config: $0)) }
    ]
    
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
            HStack(spacing: isTvOSDevice ? 40 : 12) {
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
        UIApplication.shared.isIdleTimerDisabled = shouldPreventLockTvOS(
            preventAutoLock: engine.preventAutoLock,
            sleepTimerAllowsLock: sleepState.sleepTimerAllowsLock,
            scenePhase: scenePhase
        )
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
#if os(tvOS)
                // Drop focus target while asleep to avoid stray focus highlights.
                focusedButton = nil
                fallbackFocus = false
#endif
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
        updateClockTicking()
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

    private func updateClockTicking() {
        let shouldTickClock = engine.clockEnabled && scenePhase == .active && !sleepState.sleepTimerHasExpired
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

#if os(tvOS)
    private func handlePlayPauseCommand() {
        if sleepState.sleepTimerHasExpired {
            wakeFromSleepTimer()
        } else {
            toggleChromeTvOS(forceToggle: true)
        }
    }
#endif

    private func applyUITestOverridesIfNeeded() {
#if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard args.contains(where: { arg in
            arg == "UITestingForceChromeVisible" ||
            arg == "UITestingOpenModePicker" ||
            arg == "UITestingOpenSleepTimer" ||
            arg.hasPrefix("UITestingSetMode=")
        }) else { return }

        DispatchQueue.main.async {
            if args.contains("UITestingForceChromeVisible") {
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
        updateClockTicking()
        startMotionIfNeeded()
        updateTicking()
#if os(tvOS)
        // Restore fallback focus so remote commands still arrive when chrome is hidden.
        fallbackFocus = !engine.isChromeVisible
#endif
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

    private static func clockStyle(for mode: DriftMode) -> ClockStyle {
        let styles: [ClockStyle] = [
            ClockStyle(
                font: .system(size: 32, weight: .heavy, design: .rounded).monospacedDigit(),
                color: mode.config.palette.primary,
                tracking: 1.2
            ),
            ClockStyle(
                font: .system(size: 30, weight: .semibold, design: .serif).monospacedDigit(),
                color: mode.config.palette.secondary,
                tracking: 1.6
            ),
            ClockStyle(
                font: .system(size: 28, weight: .bold, design: .monospaced),
                color: mode.config.palette.tertiary,
                tracking: 0.8
            ),
            ClockStyle(
                font: .system(size: 30, weight: .black, design: .rounded).monospacedDigit(),
                color: mode.config.palette.primary.opacity(0.9),
                tracking: 1.0
            )
        ]

        let idx = abs(mode.rawValue.hashValue) % styles.count
        return styles[idx]
    }

    private struct ClockStyle {
        let font: Font
        let color: Color
        let tracking: CGFloat
    }

    private struct ClockOverlay: View {
        let time: Date
        let style: ClockStyle

        private static let formatter: DateFormatter = {
            let df = DateFormatter()
            df.locale = .current
            df.dateFormat = "h:mm a"
            return df
        }()

        var body: some View {
            Text(Self.formatter.string(from: time).uppercased())
                .font(style.font)
                .foregroundStyle(style.color)
                .tracking(style.tracking)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)
                .accessibilityLabel("Current time \(Self.formatter.string(from: time))")
        }
    }
}

// MARK: - tvOS Sleep Timer (Apple-style screens)
#if os(tvOS)
extension DriftlyRootView {
    private func setSleepTimerTvOS(minutes: Int?) {
        engine.setSleepTimer(minutes: minutes)
        withAnimation(.easeInOut(duration: 0.6)) {
            sleepState.sleepTimerHasExpired = false
        }
        sleepState.sleepTimerAllowsLock = false
        updateIdleTimer()
        DriftHaptics.sleepTimerSet()
        updateTicking()
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
