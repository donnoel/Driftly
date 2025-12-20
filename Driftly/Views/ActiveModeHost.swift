import SwiftUI

/// Hosts the active Drift mode with crossfade and optional prewarm layer.
struct ActiveModeHost: View {
    let currentMode: DriftMode
    let prewarmMode: DriftMode?

    @State private var previousMode: DriftMode?
    @State private var previousModeLayerID: UUID?
    @State private var currentModeLayerID = UUID()
    @State private var prewarmLayerID: UUID?
    @State private var modeCrossfade: Double = 1.0
    @State private var modeFadeCleanupWorkItem: DispatchWorkItem?

    private let crossfadeDuration: TimeInterval = 0.9
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
        currentModeLayerID = UUID()
        prewarmLayerID = nil

        modeFadeCleanupWorkItem?.cancel()
        modeCrossfade = 0

        withAnimation(.easeInOut(duration: crossfadeDuration)) {
            modeCrossfade = 1
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
            return
        }
        prewarmLayerID = UUID()
    }
}
