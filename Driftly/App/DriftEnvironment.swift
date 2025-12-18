import SwiftUI

private struct DriftAnimationSpeedKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

extension EnvironmentValues {
    /// Global animation speed multiplier for Driftly lamp views.
    var driftAnimationSpeed: Double {
        get { self[DriftAnimationSpeedKey.self] }
        set { self[DriftAnimationSpeedKey.self] = newValue }
    }
}

/// Renders a single static frame when paused; otherwise mirrors `TimelineView(.animation)`.
struct PausableTimelineView<Content: View>: View {
    let paused: Bool
    @ViewBuilder let content: (Date) -> Content
    // Keeps a continuous timeline that stops advancing while paused.
    @State private var accumulated: TimeInterval = 0
    @State private var startDate = Date()

    @ViewBuilder
    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = paused ? 0 : timeline.date.timeIntervalSince(startDate)
            let effective = accumulated + elapsed
            content(Date(timeIntervalSinceReferenceDate: effective))
        }
        .onChange(of: paused) { _, isPaused in
            if isPaused {
                // Freeze time at the moment we paused.
                accumulated += Date().timeIntervalSince(startDate)
            } else {
                // Restart timing from the current wall clock.
                startDate = Date()
            }
        }
        .onAppear {
            startDate = Date()
        }
    }
}
