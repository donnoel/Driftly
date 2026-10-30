import SwiftUI
import os

/// Retains two live scene renderers through a complete, brightness-preserving dissolve.
struct ActiveModeHost: View {
    static let crossfadeDuration: TimeInterval = 2.0

    let presentation: DriftScenePresentation
    let prewarmMode: DriftMode?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @State private var transition: DriftSceneTransitionState
    @State private var warmedLayer: DriftSceneTransitionState.Layer?
    @State private var blendProgress: Double = 1
    @State private var modeTransitionInterval: OSSignpostIntervalState?

    init(presentation: DriftScenePresentation, prewarmMode: DriftMode?) {
        self.presentation = presentation
        self.prewarmMode = prewarmMode
        _transition = State(initialValue: DriftSceneTransitionState(presentation: presentation))
    }

    var body: some View {
        ZStack {
            // Keep a renderer at the same structural location as it becomes the outgoing layer.
            // Moving it into a separate conditional branch discards its local animation state.
            ForEach(renderLayers) { layer in
                ModeViewRegistry.view(for: layer.presentation.mode)
                    .environment(\.driftAnimationSpeed, layer.presentation.animationSpeed)
                    .environment(\.driftAnimationsPaused, animationsPaused || isPrewarm(layer))
                    .background(Color.black)
                    .compositingGroup()
                    .opacity(opacity(for: layer))
                    .allowsHitTesting(layer.id == transition.layers.last?.id)
                    .accessibilityHidden(layer.id != transition.layers.last?.id)
            }
        }
        .onChange(of: presentation) { _, newValue in
            request(newValue)
        }
        .onChange(of: prewarmMode) { _, _ in updatePrewarmLayer() }
        .onChange(of: transition.transitionID) { _, id in
            if id == nil { updatePrewarmLayer() }
        }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled { settleImmediately() } else { updatePrewarmLayer() }
        }
        .onChange(of: animationsPaused) { _, paused in
            if paused { settleImmediately() } else { updatePrewarmLayer() }
        }
        .task(id: transition.transitionID) {
            guard let id = transition.transitionID else { return }
            // Mount the incoming tree before changing its opacity, including prewarm promotion.
            await Task.yield()
            guard !Task.isCancelled, transition.transitionID == id else { return }
            withAnimation(
                .easeInOut(duration: Self.crossfadeDuration),
                completionCriteria: .removed
            ) {
                blendProgress = 1
            } completion: {
                finishTransition(id)
            }
        }
        .onAppear {
            DriftProfiling.event(
                DriftProfiling.Signpost.rendererSetup,
                message: "activeModeHost current=\(presentation.mode.rawValue)"
            )
            updatePrewarmLayer()
        }
        .onDisappear {
            settleImmediately()
            DriftProfiling.event(
                DriftProfiling.Signpost.rendererTeardown,
                message: "activeModeHost current=\(presentation.mode.rawValue)"
            )
        }
    }

    private var renderLayers: [DriftSceneTransitionState.Layer] {
        if let warmedLayer { return transition.layers + [warmedLayer] }
        return transition.layers
    }

    private func isPrewarm(_ layer: DriftSceneTransitionState.Layer) -> Bool {
        layer.id == warmedLayer?.id
    }

    private func opacity(for layer: DriftSceneTransitionState.Layer) -> Double {
        if isPrewarm(layer) { return 0 }
        if transition.transitionID != nil, layer.id == transition.layers.last?.id {
            return blendProgress
        }
        // The outgoing layer stays opaque underneath. Its visible contribution falls as the
        // incoming layer covers it; fading both opacities would expose black at the midpoint.
        return 1
    }

    private func request(_ newPresentation: DriftScenePresentation) {
        guard !reduceMotion, !animationsPaused else {
            settleImmediately(to: newPresentation)
            return
        }

        let oldMode = transition.layers.last?.presentation.mode
        let preparedID = warmedLayer?.presentation.mode == newPresentation.mode ? warmedLayer?.id : nil
        var startedID: UUID?
        withoutAnimation {
            startedID = transition.request(newPresentation, animated: true, preparedLayerID: preparedID)
            if startedID != nil {
                warmedLayer = nil
                blendProgress = 0
            }
        }
        guard startedID != nil else { return }
        modeTransitionInterval = DriftProfiling.begin(
            DriftProfiling.Signpost.modeTransition,
            message: "source=renderer from=\(oldMode?.rawValue ?? "none") to=\(newPresentation.mode.rawValue)"
        )
        DriftProfiling.event(
            DriftProfiling.Signpost.rendererReconfigure,
            message: "crossfade start duration=\(Self.crossfadeDuration) layers=\(transition.layers.count)"
        )
    }

    private func finishTransition(_ id: UUID) {
        guard transition.transitionID == id else { return }
        var pending: DriftScenePresentation?
        withoutAnimation {
            pending = transition.complete(id)
            blendProgress = 1
        }
        endTransition(status: "complete")
        if let pending { request(pending) }
    }

    private func settleImmediately(to target: DriftScenePresentation? = nil) {
        withoutAnimation {
            transition.request(target ?? presentation, animated: false)
            blendProgress = 1
            warmedLayer = nil
        }
        endTransition(status: "settled")
    }

    private func updatePrewarmLayer() {
        guard !reduceMotion, !animationsPaused, transition.transitionID == nil,
              let prewarmMode, prewarmMode != transition.layers.last?.presentation.mode else {
            warmedLayer = nil
            return
        }
        let prepared = DriftScenePresentation(
            mode: prewarmMode,
            sceneID: presentation.sceneID,
            animationSpeed: presentation.animationSpeed
        )
        let preparedID = warmedLayer.flatMap { $0.presentation.mode == prewarmMode ? $0.id : nil }
        warmedLayer = DriftSceneTransitionState.Layer(
            id: preparedID ?? UUID(),
            presentation: prepared
        )
    }

    private func endTransition(status: String) {
        if let interval = modeTransitionInterval {
            DriftProfiling.end(DriftProfiling.Signpost.modeTransition, interval, message: "source=renderer status=\(status)")
            modeTransitionInterval = nil
        }
    }

    private func withoutAnimation(_ changes: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, changes)
    }
}
