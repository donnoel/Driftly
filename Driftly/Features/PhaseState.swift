import Foundation

/// Keeps animation phase continuous, even when pausing/resuming, by shifting the start date.
struct PhaseController {
    private var startDate: Date = Date()
    private var pausedPhase: Double? = nil

    mutating func resetStart(date: Date = Date()) {
        startDate = date
        pausedPhase = nil
    }

    mutating func phase(for date: Date, speed: Double, cycleDuration: TimeInterval, paused: Bool) -> Double {
        if paused {
            if let pausedPhase {
                return pausedPhase
            } else {
                let phase = rawPhase(date: date, speed: speed, cycleDuration: cycleDuration)
                pausedPhase = phase
                return phase
            }
        } else {
            if let pausedPhase {
                // Shift start so the resumed phase continues smoothly
                let elapsed = pausedPhase * cycleDuration / max(speed, 0.0001)
                startDate = date.addingTimeInterval(-elapsed)
                self.pausedPhase = nil
            }
            return rawPhase(date: date, speed: speed, cycleDuration: cycleDuration)
        }
    }

    private func rawPhase(date: Date, speed: Double, cycleDuration: TimeInterval) -> Double {
        let elapsed = date.timeIntervalSince(startDate) * max(speed, 0.0001)
        return wrap01(elapsed / max(cycleDuration, 0.001))
    }
}

func wrap01(_ value: Double) -> Double {
    let wrapped = value.truncatingRemainder(dividingBy: 1)
    return wrapped < 0 ? wrapped + 1 : wrapped
}
