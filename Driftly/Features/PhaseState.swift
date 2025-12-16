import Foundation

/// Keeps animation phase continuous, even when pausing/resuming, by shifting the start date.
struct PhaseController {
    private var startDate: Date = Date()
    private var pausedElapsed: TimeInterval? = nil

    mutating func resetStart(date: Date = Date()) {
        startDate = date
        pausedElapsed = nil
    }

    /// Returns a continuously increasing phase (not wrapped), scaled by cycle duration.
    mutating func phase(for date: Date, speed: Double, cycleDuration: TimeInterval, paused: Bool) -> Double {
        if paused {
            if let pausedElapsed {
                return pausedElapsed / max(cycleDuration, 0.0001)
            } else {
                let elapsed = rawElapsed(date: date, speed: speed)
                pausedElapsed = elapsed
                return elapsed / max(cycleDuration, 0.0001)
            }
        } else {
            if let pausedElapsed {
                // Shift start so the resumed phase continues smoothly from pausedElapsed
                let elapsed = pausedElapsed / max(speed, 0.0001)
                startDate = date.addingTimeInterval(-elapsed)
                self.pausedElapsed = nil
            }
            let elapsed = rawElapsed(date: date, speed: speed)
            return elapsed / max(cycleDuration, 0.0001)
        }
    }

    private func rawElapsed(date: Date, speed: Double) -> TimeInterval {
        date.timeIntervalSince(startDate) * max(speed, 0.0001)
    }
}
