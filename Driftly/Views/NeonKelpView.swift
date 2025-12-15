import SwiftUI

struct NeonKelpView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        AcidRainPollockView(config: config, speed: speed)
            .ignoresSafeArea()
    }
}

// MARK: - Acid Rain + Pollock Splatter + Sparkle Pulses

private struct AcidRainPollockView: View {
    let config: DriftModeConfig
    let speed: Double

    var body: some View {
        TimelineView(.animation) { timeline in
            let raw = timeline.date.timeIntervalSinceReferenceDate
            let t = raw * max(0.25, speed) * 0.095

            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let center = CGPoint(x: size.width * 0.52, y: size.height * 0.48)

                // Lifted cosmic background (daytime friendly)
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        Gradient(colors: [
                            config.palette.backgroundTop.opacity(1.0),
                            config.palette.backgroundBottom.opacity(0.96)
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )

                // Acid haze bloom
                context.fill(
                    Path(rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            config.palette.tertiary.opacity(0.18),
                            config.palette.secondary.opacity(0.14),
                            config.palette.primary.opacity(0.10),
                            Color.clear
                        ]),
                        center: center,
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 1.10
                    )
                )

                // MARK: Acid rain streaks (diagonal, neon, slightly wavy)

                let area = size.width * size.height
                let rainCount = Int((area / 14_000).clamped(to: 110...420))

                // A tiny wind that oscillates (keeps it alive)
                let wind = 0.18 + 0.10 * sin(t * 0.09)
                let baseAngle = (-Double.pi * (0.17 + wind)) // diagonal baseline

                let rainA = Color(red: 0.35, green: 1.00, blue: 0.82) // acid mint
                let rainB = Color(red: 0.62, green: 0.92, blue: 1.00) // cold cyan
                let rainC = Color(red: 1.00, green: 0.44, blue: 0.92) // neon pink accent

                for i in 0..<rainCount {
                    let r1 = hash01(i, 31)
                    let r2 = hash01(i, 67)
                    let r3 = hash01(i, 101)

                    // Start positions
                    let x0 = CGFloat(r1) * size.width

                    // Falling phase
                    let sp = 0.14 + 0.46 * r2
                    let ph = fract(t * (0.07 + sp) + r3)
                    let y0 = (CGFloat(ph) * (size.height + 240)) - 120

                    let len = CGFloat(55 + 145 * r2)
                    let w = CGFloat(0.9 + 2.1 * pow(r3, 1.6))

                    // Slight wave so it isn't rigid
                    let wav = CGFloat(6.0 * sin(t * (0.48 + 0.22 * r2) + Double(i) * 0.7))

                    // Multi-direction rain: each streak gets a spread + occasional reversal
                    let spread = (hash01(i, 151) - 0.5) * 0.70 // ~±0.35 rad
                    let flip = (hash01(i, 173) > 0.86) ? Double.pi : 0.0
                    let angle = baseAngle + spread + flip

                    let dx = CGFloat(cos(angle))
                    let dy = CGFloat(sin(angle))

                    let p0 = CGPoint(x: x0 + wav, y: y0)
                    let p1 = CGPoint(x: p0.x + dx * len, y: p0.y + dy * len)

                    // Some streaks shimmy (like acid wind shear) — not all
                    let shimmyOn = (i % 9 == 0) || (r3 > 0.92)

                    var path = Path()
                    if shimmyOn {
                        let steps = 6
                        let perp = CGPoint(x: -dy, y: dx)
                        let amp = CGFloat(5.0 + 10.0 * r2) // shimmer strength
                        let freq = 2.5 + 4.5 * r1
                        let spd = 0.65 + 0.55 * r2
                        let phase2 = Double(i) * 0.9

                        for s in 0...steps {
                            let u = CGFloat(s) / CGFloat(steps)
                            let env = (1.0 - abs(u - 0.5) * 2.0) // strongest mid-streak
                            let off = amp * env * CGFloat(sin(Double(u) * Double.pi * 2.0 * freq + t * spd + phase2))

                            let bx = p0.x + (p1.x - p0.x) * u
                            let by = p0.y + (p1.y - p0.y) * u
                            let pt = CGPoint(x: bx + perp.x * off, y: by + perp.y * off)

                            if s == 0 {
                                path.move(to: pt)
                            } else {
                                path.addLine(to: pt)
                            }
                        }
                    } else {
                        path.move(to: p0)
                        path.addLine(to: p1)
                    }

                    // Color selection (mostly mint/cyan; occasional pink jab)
                    let col: Color = (i % 19 == 0) ? rainC : ((i % 2 == 0) ? rainA : rainB)

                    // Opacity ramp — brighter mid‑flight
                    let mid = 1.0 - abs(Double(ph) - 0.5) * 2.0
                    let a = 0.06 + 0.18 * mid

                    // Glow layering
                    context.stroke(path, with: .color(col.opacity(a * 0.42)), lineWidth: w * 6.0)
                    context.stroke(path, with: .color(col.opacity(a * 0.75)), lineWidth: w * 2.6)
                    context.stroke(path, with: .color(col.opacity(a * 1.05)), lineWidth: w)
                    context.stroke(path, with: .color(Color.white.opacity(a * 0.22)), lineWidth: max(0.8, w * 0.55))
                }

                // MARK: Pollock splatter (sparkly paint flecks + micro-drips)

                let splatCount = Int((area / 10_500).clamped(to: 140...520))
                let splatA = config.palette.primary
                let splatB = config.palette.secondary
                let splatC = config.palette.tertiary

                for i in 0..<splatCount {
                    let r1 = hash01(i, 211)
                    let r2 = hash01(i, 239)
                    let r3 = hash01(i, 263)

                    let x = CGFloat(r1) * size.width
                    let y = CGFloat(r2) * size.height

                    // Slow drift so the splatter feels suspended
                    let dx = CGFloat(6.0 * sin(t * 0.05 + Double(i) * 0.9))
                    let dy = CGFloat(5.0 * cos(t * 0.04 + Double(i) * 0.7))

                    let s = 0.8 + 2.9 * pow(r3, 1.7)

                    // Color mix, with occasional bright speck
                    let col: Color = {
                        if i % 29 == 0 { return Color.white }
                        if i % 17 == 0 { return splatC }
                        if i % 11 == 0 { return splatB }
                        return splatA
                    }()

                    // Sparkle pulse for some flecks
                    let sparkle = (r3 > 0.86) ? (0.5 + 0.5 * sin(t * (0.75 + 0.55 * r2) + Double(i))) : 0.0
                    let a = (0.02 + 0.08 * r3) + 0.10 * sparkle

                    context.fill(
                        Path(ellipseIn: CGRect(x: x + dx, y: y + dy, width: s, height: s)),
                        with: .color(col.opacity(a))
                    )

                    // Occasional micro-drip (tiny vertical streak)
                    if i % 41 == 0 {
                        let dripLen = CGFloat(16 + 44 * r2)
                        let w = CGFloat(1.0 + 1.8 * r3)
                        let dripRect = CGRect(x: x + dx, y: y + dy, width: w, height: dripLen)
                        context.fill(Path(roundedRect: dripRect, cornerRadius: w * 0.6), with: .color(col.opacity(0.05 + 0.10 * r3)))
                    }
                }

                // MARK: Sparkling pulses (soft rings that bloom, like electric raindrops)

                let pulseCount = 9
                for k in 0..<pulseCount {
                    let r1 = hash01(k, 911)
                    let r2 = hash01(k, 947)

                    let baseX = size.width * (0.16 + 0.70 * CGFloat(r1))
                    let baseY = size.height * (0.16 + 0.70 * CGFloat(r2))

                    // Each pulse has its own phase (slow)
                    let ph = fract(t * (0.06 + 0.03 * Double(k)) + Double(k) * 0.37)
                    let s = smoothstep(1.0 - abs(ph - 0.5) * 2.0)

                    let r = (min(size.width, size.height) * 0.05) + (min(size.width, size.height) * 0.14) * CGFloat(ph)
                    let op = 0.02 + 0.10 * s

                    let ring = Path(ellipseIn: CGRect(x: baseX - r, y: baseY - r, width: r * 2, height: r * 2))

                    let col: Color = (k % 3 == 0) ? rainA : ((k % 3 == 1) ? rainB : rainC)
                    context.stroke(ring, with: .color(col.opacity(op * 0.55)), lineWidth: 10)
                    context.stroke(ring, with: .color(col.opacity(op * 0.85)), lineWidth: 4)
                    context.stroke(ring, with: .color(Color.white.opacity(op * 0.22)), lineWidth: 1.2)
                }

                // Gentle sweep to unify the whole composition
                let sweepX = center.x + CGFloat(sin(t * 0.10)) * size.width * 0.42
                let sweepRect = CGRect(x: sweepX - 170, y: 0, width: 340, height: size.height)
                context.fill(
                    Path(sweepRect),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.00),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.00)
                        ]),
                        startPoint: CGPoint(x: sweepRect.minX, y: 0),
                        endPoint: CGPoint(x: sweepRect.maxX, y: 0)
                    )
                )
            }
        }
    }

    // MARK: - Helpers

    private func fract(_ x: Double) -> Double { x - floor(x) }

    private func smoothstep(_ x: Double) -> Double {
        let t = max(0.0, min(1.0, x))
        return t * t * (3.0 - 2.0 * t)
    }

    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Double(n & 0x7fffffff) / 2147483647.0
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
