import SwiftUI
import os

/// Hosts the active Drift mode with crossfade and optional prewarm layer.
struct ActiveModeHost: View {
    let currentMode: DriftMode
    let prewarmMode: DriftMode?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previousMode: DriftMode?
    @State private var previousModeLayerID: UUID?
    @State private var currentModeLayerID = UUID()
    @State private var prewarmLayerID: UUID?
    @State private var warmedMode: DriftMode?
    @State private var modeCrossfade: Double = 1.0
    @State private var modeFadeCleanupWorkItem: DispatchWorkItem?
    @State private var modeTransitionInterval: OSSignpostIntervalState?

    private let crossfadeDuration: TimeInterval = 1.1
    private let cleanupDelay: TimeInterval = 1.0

    var body: some View {
        ZStack {
            if let previousMode, let previousModeLayerID {
                ModeViewRegistry.view(for: previousMode)
                    .id(previousModeLayerID)
                    .opacity(1 - modeCrossfade)
                    .environment(\.driftAnimationsPaused, true)
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
            DriftProfiling.event(
                DriftProfiling.Signpost.rendererSetup,
                message: "activeModeHost current=\(currentMode.rawValue)"
            )
            updatePrewarmLayer(for: prewarmMode)
        }
        .onDisappear {
            modeFadeCleanupWorkItem?.cancel()
            if let interval = modeTransitionInterval {
                DriftProfiling.end(
                    DriftProfiling.Signpost.modeTransition,
                    interval,
                    message: "status=teardown to=\(currentMode.rawValue)"
                )
                modeTransitionInterval = nil
            }
            DriftProfiling.event(
                DriftProfiling.Signpost.rendererTeardown,
                message: "activeModeHost current=\(currentMode.rawValue)"
            )
        }
    }

    private func beginModeCrossfade(from oldMode: DriftMode, to newMode: DriftMode) {
#if DEBUG
        debugValidateSinglePreviousLayer(context: "begin.before")
#endif
        if let interval = modeTransitionInterval {
            DriftProfiling.end(
                DriftProfiling.Signpost.modeTransition,
                interval,
                message: "status=interrupted from=\(oldMode.rawValue) to=\(newMode.rawValue)"
            )
            modeTransitionInterval = nil
        }
        modeTransitionInterval = DriftProfiling.begin(
            DriftProfiling.Signpost.modeTransition,
            message: "source=renderer from=\(oldMode.rawValue) to=\(newMode.rawValue)"
        )
        DriftProfiling.event(
            DriftProfiling.Signpost.rendererReconfigure,
            message: "crossfade prepare from=\(oldMode.rawValue) to=\(newMode.rawValue)"
        )

        previousMode = oldMode
        previousModeLayerID = currentModeLayerID
        if warmedMode == newMode, let prewarmLayerID {
            currentModeLayerID = prewarmLayerID
        } else {
            currentModeLayerID = UUID()
        }
        prewarmLayerID = nil
        warmedMode = nil

#if DEBUG
        debugTransitionEvent(
            "start from=\(oldMode.rawValue) to=\(newMode.rawValue) previousTracked=\(previousMode?.rawValue ?? "none")"
        )
        debugValidateSinglePreviousLayer(context: "begin.afterAssign")
#endif

        modeFadeCleanupWorkItem?.cancel()

        if reduceMotion {
            // Skip crossfade when Reduce Motion is enabled.
            modeCrossfade = 1
            previousMode = nil
            previousModeLayerID = nil
#if DEBUG
            debugTransitionEvent("cleanup.reduceMotion from=\(oldMode.rawValue) to=\(newMode.rawValue)")
            debugValidateSinglePreviousLayer(context: "cleanup.reduceMotion")
#endif
            if let interval = modeTransitionInterval {
                DriftProfiling.end(
                    DriftProfiling.Signpost.modeTransition,
                    interval,
                    message: "source=renderer reduceMotion from=\(oldMode.rawValue) to=\(newMode.rawValue)"
                )
                modeTransitionInterval = nil
            }
            return
        }

        modeCrossfade = 0
        // Defer the animation a tick so the new layer can render once before we start fading.
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: crossfadeDuration)) {
                modeCrossfade = 1
            }
        }

        let cleanup = DispatchWorkItem {
            guard previousMode == oldMode else {
#if DEBUG
                debugTransitionEvent(
                    "cleanup.skip expected=\(oldMode.rawValue) actual=\(previousMode?.rawValue ?? "none") to=\(newMode.rawValue)"
                )
                debugValidateSinglePreviousLayer(context: "cleanup.skip")
#endif
                return
            }
#if DEBUG
            debugValidateSinglePreviousLayer(context: "cleanup.before")
#endif
            previousMode = nil
            previousModeLayerID = nil
#if DEBUG
            debugTransitionEvent("cleanup.complete from=\(oldMode.rawValue) to=\(newMode.rawValue)")
            debugValidateSinglePreviousLayer(context: "cleanup.after")
#endif
            if let interval = modeTransitionInterval {
                DriftProfiling.end(
                    DriftProfiling.Signpost.modeTransition,
                    interval,
                    message: "source=renderer complete from=\(oldMode.rawValue) to=\(newMode.rawValue)"
                )
                modeTransitionInterval = nil
            }
        }
        modeFadeCleanupWorkItem = cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + cleanupDelay, execute: cleanup)
    }

    private func updatePrewarmLayer(for mode: DriftMode?) {
        guard let mode, mode != currentMode else {
            if warmedMode != nil || prewarmLayerID != nil {
                DriftProfiling.event(
                    DriftProfiling.Signpost.rendererReconfigure,
                    message: "prewarm clear current=\(currentMode.rawValue)"
                )
            }
            prewarmLayerID = nil
            warmedMode = nil
            return
        }
        if warmedMode == mode, prewarmLayerID != nil {
            return
        }
        warmedMode = mode
        prewarmLayerID = prewarmLayerID ?? UUID()
        DriftProfiling.event(
            DriftProfiling.Signpost.rendererReconfigure,
            message: "prewarm set mode=\(mode.rawValue)"
        )
    }
}

#if DEBUG
private extension ActiveModeHost {
    func debugValidateSinglePreviousLayer(context: StaticString) {
        let hasMode = previousMode != nil
        let hasLayerID = previousModeLayerID != nil
        if hasMode != hasLayerID {
            assertionFailure("ActiveModeHost previous-layer state mismatch at \(context)")
            DriftProfiling.event(
                DriftProfiling.Signpost.rendererReconfigure,
                message: "debug invariantFailure context=\(context) hasMode=\(hasMode) hasLayerID=\(hasLayerID)"
            )
        }
    }

    func debugTransitionEvent(_ message: String) {
        DriftProfiling.event(
            DriftProfiling.Signpost.rendererReconfigure,
            message: "debug transition \(message)"
        )
    }
}
#endif
