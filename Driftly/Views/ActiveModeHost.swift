import SwiftUI

/// Hosts the active Drift mode with crossfade and optional prewarm layer.
struct ActiveModeHost: View {
    let currentMode: DriftMode
    let prewarmMode: DriftMode?

    @State private var previousMode: DriftMode?
    @State private var previousModeLayerID: UUID?
    @State private var currentModeLayerID = UUID()
    @State private var prewarmLayerID: UUID?
    @State private var warmedMode: DriftMode?
    @State private var modeCrossfade: Double = 1.0
    @State private var modeFadeCleanupWorkItem: DispatchWorkItem?

    private let crossfadeDuration: TimeInterval = 1.1
    private let cleanupDelay: TimeInterval = 1.0

    var body: some View {
        ZStack {
            if let previousMode, let previousModeLayerID {
                ModeViewRegistry.view(for: previousMode)
                    .id(previousModeLayerID)
                    .opacity(1 - modeCrossfade)
            }

            ModeViewRegistry.view(for: currentMode)
                .id(currentModeLayerID)
                .opacity(modeCrossfade)

            if let prewarmMode, prewarmMode != currentMode, let prewarmLayerID {
                ModeViewRegistry.view(for: prewarmMode)
                    .id(prewarmLayerID)
                    .opacity(0)
                    .environment(\.driftAnimationsPaused, true)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: currentMode) { oldMode, newMode in
            guard oldMode != newMode else { return }
            beginModeCrossfade(from: oldMode, to: newMode)
        }
        .onChange(of: prewarmMode) { _, newValue in
            updatePrewarmLayer(for: newValue)
        }
        .onAppear {
            updatePrewarmLayer(for: prewarmMode)
        }
    }

    private func beginModeCrossfade(from oldMode: DriftMode, to newMode: DriftMode) {
        previousMode = oldMode
        previousModeLayerID = currentModeLayerID
        if warmedMode == newMode, let prewarmLayerID {
            currentModeLayerID = prewarmLayerID
        } else {
            currentModeLayerID = UUID()
        }
        prewarmLayerID = nil
        warmedMode = nil

        modeFadeCleanupWorkItem?.cancel()
        modeCrossfade = 0
        // Defer the animation a tick so the new layer can render once before we start fading.
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: crossfadeDuration)) {
                modeCrossfade = 1
            }
        }

        let cleanup = DispatchWorkItem {
            guard currentMode == newMode else { return }
            previousMode = nil
            previousModeLayerID = nil
        }
        modeFadeCleanupWorkItem = cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + cleanupDelay, execute: cleanup)
    }

    private func updatePrewarmLayer(for mode: DriftMode?) {
        guard let mode, mode != currentMode else {
            prewarmLayerID = nil
            warmedMode = nil
            return
        }
        if warmedMode == mode, prewarmLayerID != nil {
            return
        }
        warmedMode = mode
        prewarmLayerID = prewarmLayerID ?? UUID()
    }
}
