import Foundation

/// Keeps animation phase continuous, even when pausing/resuming, by shifting the start date.
struct PhaseController {
    private var startDate: Date = Date()
    private var pausedElapsed: TimeInterval? = nil
    private var lastSpeed: Double? = nil

    mutating func resetStart(date: Date = Date()) {
        startDate = date
        pausedElapsed = nil
        lastSpeed = nil
    }

    /// Returns a continuously increasing phase (not wrapped), scaled by cycle duration.
    mutating func phase(for date: Date, speed: Double, cycleDuration: TimeInterval, paused: Bool) -> Double {
        let safeSpeed = max(speed, 0.0001)

        if paused {
            if let pausedElapsed {
                lastSpeed = safeSpeed
                return pausedElapsed / max(cycleDuration, 0.0001)
            } else {
                let elapsed = rawElapsed(date: date, speed: safeSpeed)
                pausedElapsed = elapsed
                lastSpeed = safeSpeed
                return elapsed / max(cycleDuration, 0.0001)
            }
        } else {
            if let pausedElapsed {
                // Shift start so the resumed phase continues smoothly from pausedElapsed
                let elapsed = pausedElapsed / safeSpeed
                startDate = date.addingTimeInterval(-elapsed)
                self.pausedElapsed = nil
                lastSpeed = safeSpeed
            } else if let previousSpeed = lastSpeed, previousSpeed != safeSpeed {
                // Rebase start so changing speed does not introduce a phase jump.
                let elapsed = rawElapsed(date: date, speed: previousSpeed)
                startDate = date.addingTimeInterval(-elapsed / safeSpeed)
                lastSpeed = safeSpeed
            } else if lastSpeed == nil {
                lastSpeed = safeSpeed
            }
            let elapsed = rawElapsed(date: date, speed: safeSpeed)
            return elapsed / max(cycleDuration, 0.0001)
        }
    }

    private func rawElapsed(date: Date, speed: Double) -> TimeInterval {
        date.timeIntervalSince(startDate) * speed
    }
}
