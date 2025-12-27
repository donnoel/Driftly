import SwiftUI

/// Isolated renderer so per-frame updates stay scoped to the animated scene.
struct DriftSceneRendererView: View {
    let currentMode: DriftMode
    let prewarmMode: DriftMode?
    let scenePhase: ScenePhase
    let reduceMotion: Bool
    let sleepTimerHasExpired: Bool
    let isChromeVisible: Bool
    let brightness: Double
    @Binding var motionUnavailable: Bool

    @StateObject private var motionManager = DriftMotionManager()
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        ActiveModeHost(currentMode: currentMode, prewarmMode: prewarmMode)
            .offset(effectiveOffset)
            .scaleEffect(effectiveScale)
            .ignoresSafeArea()
            .onAppear { syncMotion() }
            .onChange(of: scenePhase) { _, _ in syncMotion() }
            .onChange(of: reduceMotion) { _, _ in syncMotion() }
            .onChange(of: sleepTimerHasExpired) { _, _ in syncMotion() }
            .onChange(of: isChromeVisible) { _, _ in updateSampling() }
            .onChange(of: brightness) { _, _ in updateSampling() }
            .onChange(of: motionManager.motionUnavailable) { _, unavailable in
                if unavailable != motionUnavailable {
                    motionUnavailable = unavailable
                }
                if unavailable {
                    motionManager.stopUpdates()
                }
            }
    }

    private var allowMotion: Bool {
        !reduceMotion && !sleepTimerHasExpired && scenePhase == .active && !animationsPaused
    }

    private var effectiveOffset: CGSize {
        allowMotion ? motionManager.parallaxOffset : .zero
    }

    private var effectiveScale: CGFloat {
        allowMotion ? 1.03 : 1.0
    }

    private func syncMotion() {
        motionUnavailable = motionManager.motionUnavailable
        guard allowMotion else {
            motionManager.stopUpdates()
            return
        }
        updateSampling()
        motionManager.startIfNeeded()
        motionUnavailable = motionManager.motionUnavailable
    }

    private func updateSampling() {
#if os(iOS)
        guard allowMotion else { return }
        motionManager.updateSampling(
            brightness: brightness,
            isChromeVisible: isChromeVisible
        )
#endif
    }
}
