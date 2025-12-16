import SwiftUI

struct PhotonRainView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @State private var drops: [DropMeta] = Self.makeDrops(maxCount: 140)

    var body: some View {
        TimelineView(.animation) { timeline in
            let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            let effectiveSpeed = speed * (isLowPower ? 0.75 : 1.0)
            let dropCount = isLowPower ? 90 : 140

            if animationsPaused {
                Color.clear
                    .background(config.palette.backgroundBottom)
                    .ignoresSafeArea()
            } else {
                let t = timeline.date.timeIntervalSinceReferenceDate * effectiveSpeed

                Canvas { context, size in
                    var ctx = context
                    render(in: &ctx, size: size, t: t, dropCountBase: dropCount)
                }
                .background(config.palette.backgroundBottom)
                .ignoresSafeArea()
            }
        }
    }

    private func render(in context: inout GraphicsContext, size: CGSize, t: Double, dropCountBase: Int) {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        let dropCount = Self.adjustedDropCount(base: dropCountBase, size: size)
        let denom = Double(max(dropCount - 1, 1))

        let activeDrops = drops.prefix(dropCount)

        for drop in activeDrops {
            let p = Double(drop.index) / denom

            // Base x lane + drift so streaks cross and "clash"
            let baseX = CGFloat(p) * w
            let laneDrift = CGFloat(drop.laneDriftD) * CGFloat(sin(t * drop.laneDriftFreq + Double(drop.index) * 0.21))

            // Fall speed varies per drop
            let yRaw = (t * drop.fall + Double(drop.index) * 37.0).truncatingRemainder(dividingBy: Double(h + 220.0))
            let y0 = CGFloat(yRaw) - 120.0

            // Streak geometry
            let length = drop.length
            let lineWidth = drop.lineWidth

            // Build a wavy path using a few sample points
            var path = Path()
            let steps = 7
            let xBase = baseX + laneDrift

            for s in 0...steps {
                let u = Double(s) / Double(steps)
                let yy = y0 + length * CGFloat(u)

                // Two superposed waves to feel organic
                let w1 = sin((t * 1.3) * drop.freq + u * 9.0 + drop.phase)
                let w2 = cos((t * 0.9) * (drop.freq * 1.4) + u * 14.0 + drop.phase * 0.7)
                let wiggle = CGFloat(0.65 * w1 + 0.35 * w2)

                let xx = xBase + drop.amp * wiggle

                if s == 0 {
                    path.move(to: CGPoint(x: xx, y: yy))
                } else {
                    path.addLine(to: CGPoint(x: xx, y: yy))
                }
            }

            // Brightness: occasional stronger streaks ("clashes")
            let clash = 0.5 + 0.5 * sin(t * (0.55 + 0.25 * drop.a) + Double(drop.index) * 0.19)
            let hot = (drop.a > 0.82) ? (0.18 + 0.22 * clash) : (0.06 + 0.10 * clash)

            let o1 = 0.10 + hot
            let o2 = 0.22 + hot
            let o3 = 0.06 + 0.10 * hot

            // Layered strokes for depth
            context.stroke(path, with: .color(config.palette.primary.opacity(o1)), lineWidth: lineWidth * 3.2)
            context.stroke(path, with: .color(config.palette.primary.opacity(o2)), lineWidth: lineWidth * 1.4)
            context.stroke(path, with: .color(Color.white.opacity(o3)), lineWidth: max(0.8, lineWidth * 0.85))
        }
    }

    private static func makeDrops(maxCount: Int) -> [DropMeta] {
        guard maxCount > 0 else { return [] }

        return (0..<maxCount).map { i in
            let a = hash01(i, 17)
            let b = hash01(i, 41)
            let c = hash01(i, 83)

            let laneDriftD = (a - 0.5) * 110.0
            let laneDriftFreq = 0.14 + 0.04 * b

            let fall = 22.0 + 22.0 * b // 22..44

            let length = CGFloat(34.0 + 70.0 * c)
            let lineWidth = CGFloat(0.9 + 1.9 * (0.4 + 0.6 * a))

            let amp = CGFloat(6.0 + 14.0 * a)
            let freq = 0.10 + 0.22 * c
            let phase = Double(i) * 0.37 + 6.0 * a

            return DropMeta(
                index: i,
                a: a,
                laneDriftD: laneDriftD,
                laneDriftFreq: laneDriftFreq,
                fall: fall,
                length: length,
                lineWidth: lineWidth,
                amp: amp,
                freq: freq,
                phase: phase
            )
        }
    }

    private static func adjustedDropCount(base: Int, size: CGSize) -> Int {
        let area = max(size.width * size.height, 1)
        // Reference roughly a modern phone screen area
        let referenceArea: Double = 430 * 932
        let factor = sqrt(area / referenceArea)
        // Keep within a narrow band to avoid visual change
        let clamped = min(1.15, max(0.85, factor))
        let adjusted = Int(round(Double(base) * clamped))
        return min(180, max(60, adjusted))
    }

    // Deterministic hash -> 0..1 (stable per index)
    private static func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Double(n & 0x7fffffff) / 2147483647.0
    }
}

private struct DropMeta {
    let index: Int
    let a: Double
    let laneDriftD: Double
    let laneDriftFreq: Double
    let fall: Double
    let length: CGFloat
    let lineWidth: CGFloat
    let amp: CGFloat
    let freq: Double
    let phase: Double
}
