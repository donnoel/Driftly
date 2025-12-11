import SwiftUI
import UIKit
import Combine

struct DriftlyRootView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var motionManager = DriftMotionManager()
    
    @State private var isModePickerPresented = false
    @State private var isSettingsPresented = false
    @State private var isSleepTimerDialogPresented = false
    @State private var sleepTimerHasExpired = false
    @State private var sleepTimerAllowsLock = false
    @State private var lastAutoDriftChange: Date = Date()
    
    var body: some View {
        ZStack {
            activeModeView
                .offset(motionManager.parallaxOffset)
                .scaleEffect(1.03) // tiny scale so edges don’t reveal gaps when moving
                .opacity(sleepTimerHasExpired ? 0.0 : 1.0)
                .ignoresSafeArea()
            
            // Minimal chrome (hidden when asleep)
            if engine.isChromeVisible && !sleepTimerHasExpired {
                VStack {
                    Spacer()
                    bottomChrome
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 32)
                        .padding(.horizontal, 24)
                }
            }
            
            // Edge brightness gesture zones (left & right)
            HStack {
                brightnessEdgeView(isLeading: true)
                Spacer()
                brightnessEdgeView(isLeading: false)
            }
        }
        // Screen darkening overlay based on brightness
        .overlay(
            Color.black
                .opacity(1 - engine.brightness)
                .allowsHitTesting(false)
        )
        // Global animation speed for all lamp views
        .environment(\.driftAnimationSpeed, engine.animationSpeed)
        .background(Color.black)
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.35)) {
                engine.isChromeVisible.toggle()
            }
            DriftHaptics.chromeToggled()
        }
        .onAppear {
            updateIdleTimer()
            resetAutoDriftClock()
            startMotionIfNeeded()
        }
        .onChange(of: scenePhase) { phase in
            updateIdleTimer()
            handleMotion(for: phase)
        }
        .onChange(of: engine.preventAutoLock) { _ in
            updateIdleTimer()
        }
        .onChange(of: engine.autoDriftEnabled) { enabled in
            if enabled {
                resetAutoDriftClock()
            }
        }
        .onChange(of: engine.autoDriftIntervalMinutes) { _ in
            if engine.autoDriftEnabled {
                resetAutoDriftClock()
            }
        }
        .onChange(of: engine.currentMode) { _ in
            if engine.autoDriftEnabled {
                resetAutoDriftClock()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
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
                    sleepTimerHasExpired = false
                }
                sleepTimerAllowsLock = false
                updateIdleTimer()
                DriftHaptics.sleepTimerSet()
            }
            Button("15 minutes") {
                engine.setSleepTimer(minutes: 15)
                withAnimation(.easeInOut(duration: 0.6)) {
                    sleepTimerHasExpired = false
                }
                sleepTimerAllowsLock = false
                DriftHaptics.sleepTimerSet()
            }
            Button("30 minutes") {
                engine.setSleepTimer(minutes: 30)
                withAnimation(.easeInOut(duration: 0.6)) {
                    sleepTimerHasExpired = false
                }
                sleepTimerAllowsLock = false
                DriftHaptics.sleepTimerSet()
            }
            Button("60 minutes") {
                engine.setSleepTimer(minutes: 60)
                withAnimation(.easeInOut(duration: 0.6)) {
                    sleepTimerHasExpired = false
                }
                sleepTimerAllowsLock = false
                DriftHaptics.sleepTimerSet()
            }
            Button("Cancel", role: .cancel) {}
        }
        // Settings sheet (gear)
        .sheet(isPresented: $isSettingsPresented) {
            DriftlySettingsView()
                .environmentObject(engine)
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
            HStack(spacing: 12) {
                CircleButton(systemName: "sparkles") {
                    isModePickerPresented = true
                }
                
                CircleButton(systemName: "moon.zzz") {
                    isSleepTimerDialogPresented = true
                }
                
                CircleButton(systemName: "gearshape") {
                    isSettingsPresented = true
                }
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
        
        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.black.opacity(0.45))
                            .blur(radius: 0.5)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.14))
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Brightness edges
    
    private func brightnessEdgeView(isLeading: Bool) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 44)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        // Drag up (negative height) → increase brightness
                        // Drag down (positive height) → decrease brightness
                        let delta = -value.translation.height / 300.0
                        let proposed = engine.brightness + Double(delta)
                        let clamped = max(0.2, min(1.0, proposed))

                        // If we tried to go past the limits and just hit them, give a tiny rigid tap
                        if (proposed < 0.2 && engine.brightness > 0.2) ||
                           (proposed > 1.0 && engine.brightness < 1.0) {
                            DriftHaptics.brightnessLimitHit()
                        }

                        engine.brightness = clamped
                    }
            )
    }
    
    // MARK: - Idle timer handling
    
    private func updateIdleTimer() {
#if os(iOS)
        let shouldPreventLock = engine.preventAutoLock && !sleepTimerAllowsLock && scenePhase == .active
        UIApplication.shared.isIdleTimerDisabled = shouldPreventLock
#endif
    }

    private func handleMotion(for phase: ScenePhase) {
#if os(iOS)
        switch phase {
        case .active:
            motionManager.startIfNeeded()
        default:
            motionManager.stopUpdates()
        }
#endif
    }

    private func startMotionIfNeeded() {
#if os(iOS)
        motionManager.startIfNeeded()
#endif
    }
    
    // MARK: - Sleep timer tick & auto drift
    
    private func handleSleepTimerTick(now: Date) {
        // Sleep timer logic
        if let end = engine.sleepTimerEndDate {
            if now >= end && !sleepTimerHasExpired {
                withAnimation(.easeInOut(duration: 1.5)) {
                    sleepTimerHasExpired = true
                }
                // Once timer fires, allow device to auto-lock again without changing the persisted setting
                sleepTimerAllowsLock = true
                updateIdleTimer()
            }
        } else {
            // If timer was cleared, reset fade state
            if sleepTimerHasExpired {
                withAnimation(.easeInOut(duration: 0.8)) {
                    sleepTimerHasExpired = false
                }
            }
            sleepTimerAllowsLock = false
            updateIdleTimer()
        }
        
        // Auto drift logic (only when awake & not faded out)
        guard engine.autoDriftEnabled,
              !sleepTimerHasExpired
        else { return }
        
        let interval = max(3, engine.autoDriftIntervalMinutes)
        let seconds = Double(interval * 60)
        let elapsed = now.timeIntervalSince(lastAutoDriftChange)
        
        if elapsed >= seconds {
            withAnimation(.easeInOut(duration: 0.9)) {
                engine.goToNextMode()
            }
            DriftHaptics.autoDriftTick()
            lastAutoDriftChange = now
        }
    }

    private func resetAutoDriftClock() {
        lastAutoDriftChange = Date()
    }
}
