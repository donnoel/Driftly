import SwiftUI

/// One continuous staff surface keeps the notes and the flowing scale attached as both move.
enum CausticSilkScore {
    static let railCount = 9

    struct Note {
        let head: CGPoint
        let secondHead: CGPoint
        let lane: Double
        let u: Double
        let unit: CGFloat
        let climb: Double
    }

    static func point(u: Double, lane: Double, size: CGSize, time: Double) -> CGPoint {
        let p = (lane + 0.5) / Double(railCount)
        let amplitude = min(size.width, size.height) * (0.032 + 0.006 * sin(p * 3))
        let a = sin(u * .pi * 2 * 1.51 + time * 0.12 + p * 7 + 3.46)
        let b = cos(u * .pi * 2 * 2.54 - time * 0.075 + p * 4)
        let offset = amplitude * (a + 0.55 * b)
        return CGPoint(x: size.width * (u + (p - 0.5) * 0.72) + offset,
                       y: size.height * (1 - u) + offset * 0.55)
    }

    static func point(atX x: Double, lane: Double, size: CGSize, time: Double) -> CGPoint {
        var low = -0.25, high = 1.25
        for _ in 0..<24 {
            let middle = (low + high) * 0.5
            if point(u: middle, lane: lane, size: size, time: time).x < x { low = middle }
            else { high = middle }
        }
        return point(u: (low + high) * 0.5, lane: lane, size: size, time: time)
    }

    static func note(index: Int, size: CGSize, time: Double) -> Note {
        let base = min(size.width, size.height)
        let phase = Double(index) * 1.73
        let unit = max(3.8, base * (0.010 + 0.003 * DriftNoise.hash(index, 19, seed: 1200)))
        // Each voice holds a pitch briefly, then glides one step up or down with soft landings.
        let clock = time / (5.2 + Double(index % 4) * 0.45) + Double(index) * 0.67
        let step = Int(floor(clock))
        let fraction = clock - floor(clock)
        let progress = min(1, max(0, (fraction - 0.38) / 0.62))
        let ease = progress * progress * (3 - 2 * progress)
        func pitch(_ step: Int) -> Double {
            let slot = (step % 10 + 10) % 10
            return 2 + Double(slot <= 5 ? slot : 10 - slot)
        }
        let lane = pitch(step) + (pitch(step + 1) - pitch(step)) * ease
        let p = (lane + 0.5) / Double(railCount)
        let shift = (p - 0.5) * 0.72
        let xPad = unit * 6 + base * 0.075 + 10
        let pairRoom = index % 6 == 4 ? 4.0 * size.height / max(1, size.width) : 0
        let topPad = unit * (7.5 + pairRoom) + base * 0.05 + 10
        let bottomPad = unit * 2 + base * 0.05 + 10
        let lower = max(bottomPad / max(1, size.height), xPad / max(1, size.width) - shift)
        let upper = min(1 - topPad / max(1, size.height), 1 - xPad / max(1, size.width) - shift)
        let position = 0.05 + 0.90 * DriftNoise.fract((Double(index) + 0.5) * 0.61803398875)
            + 0.035 * sin(time * 0.025 + phase)
        let u = lower + max(0, upper - lower) * position
        let head = point(u: u, lane: lane, size: size, time: time)
        let second = index % 6 == 4
            ? point(atX: head.x + unit * 3.6, lane: lane, size: size, time: time) : head
        return Note(head: head, secondHead: second, lane: lane, u: u, unit: unit,
                    climb: sin(.pi * progress))
    }
}
