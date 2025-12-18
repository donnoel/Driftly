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

    @ViewBuilder
    var body: some View {
        if paused {
            content(Date(timeIntervalSinceReferenceDate: 0))
        } else {
            TimelineView(.animation) { timeline in
                content(timeline.date)
            }
        }
    }
}
