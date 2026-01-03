import SwiftUI

private struct DriftAnimationSpeedKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

private struct DriftPhaseAnchorDateKey: EnvironmentKey {
    static let defaultValue: Date = Date()
}

extension EnvironmentValues {
    /// Global animation speed multiplier for Driftly lamp views.
    var driftAnimationSpeed: Double {
        get { self[DriftAnimationSpeedKey.self] }
        set { self[DriftAnimationSpeedKey.self] = newValue }
    }

    /// Shared phase anchor so mode views can stay in sync across transitions.
    var driftPhaseAnchorDate: Date {
        get { self[DriftPhaseAnchorDateKey.self] }
        set { self[DriftPhaseAnchorDateKey.self] = newValue }
    }
}

enum DriftAnimationPolicy {
    static let reduceMotionScale: Double = 0.55

    static func effectiveSpeed(base: Double, reduceMotion: Bool, respectSystemReduceMotion: Bool) -> Double {
        guard respectSystemReduceMotion, reduceMotion else { return base }
        return max(0.25, base * reduceMotionScale)
    }
}

/// Renders a single static frame when paused; otherwise mirrors `TimelineView(.animation)`.
struct PausableTimelineView<Content: View>: View {
    let paused: Bool
    let fps: Double = 60
    @ViewBuilder let content: (Date) -> Content

    // Maintains a continuous synthetic time value (seconds since reference date)
    // that stops advancing while paused.
    @State private var accumulated: TimeInterval = 0
    @State private var startDate = Date()

    @Environment(\.driftPhaseAnchorDate) private var phaseAnchorDate

    var body: some View {
        Group {
            if paused {
                // IMPORTANT: no TimelineView here => no ticking/redraw loop.
                content(Date(timeIntervalSinceReferenceDate: accumulated))
            } else {
            let interval = 1.0 / max(fps, 1.0)
            TimelineView(.periodic(from: .now, by: interval)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                let effective = accumulated + elapsed
                content(Date(timeIntervalSinceReferenceDate: effective))
            }
        }
        }
        .onAppear {
            // Sync initial start to the shared anchor so transitions stay coherent.
            startDate = phaseAnchorDate
        }
        .onChange(of: paused) { _, isPaused in
            if isPaused {
                // Freeze at the moment we paused.
                accumulated += Date().timeIntervalSince(startDate)
            } else {
                // Resume from the frozen value.
                startDate = Date()
            }
        }
    }
}
