import SwiftUI

enum DriftNoise {
    static func fract(_ x: Double) -> Double { x - floor(x) }
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
    static func smoothstep(_ t: Double) -> Double { t * t * (3 - 2 * t) }

    static func hash(_ x: Int, _ y: Int, seed: Int) -> Double {
        var n = x &* 374761393 &+ y &* 668265263 &+ seed &* 69069
        n = (n ^ (n >> 13)) &* 1274126177
        return fract(Double(n & 0x7fffffff) / 2147483647.0)
    }

    static func valueNoise(x: Double, y: Double, seed: Int) -> Double {
        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let x1 = x0 + 1
        let y1 = y0 + 1

        let sx = smoothstep(fract(x))
        let sy = smoothstep(fract(y))

        let n00 = hash(x0, y0, seed: seed)
        let n10 = hash(x1, y0, seed: seed)
        let n01 = hash(x0, y1, seed: seed)
        let n11 = hash(x1, y1, seed: seed)

        let ix0 = lerp(n00, n10, sx)
        let ix1 = lerp(n01, n11, sx)
        return lerp(ix0, ix1, sy)
    }

    static func fbm(x: Double, y: Double, seed: Int, octaves: Int = 4) -> Double {
        var sum = 0.0
        var amp = 0.5
        var freq = 1.0
        for i in 0..<octaves {
            sum += amp * valueNoise(x: x * freq, y: y * freq, seed: seed + i * 1013)
            amp *= 0.5
            freq *= 2.0
        }
        return sum
    }
}
