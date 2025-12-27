import Foundation

struct FrameGate {
    private var lastCommit: Double = 0
    private let minInterval: Double

    init(maxFPS: Double) {
        minInterval = 1.0 / max(maxFPS, 1.0)
    }

    mutating func shouldCommit(now: Double) -> Bool {
        if now - lastCommit >= minInterval {
            lastCommit = now
            return true
        }
        return false
    }
}
