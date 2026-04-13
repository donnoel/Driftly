import SwiftUI

struct NeonKelpView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        AcidRainPollockView(config: config, speed: speed)
            .ignoresSafeArea()
    }
}

// MARK: - Organic Kelp Field

private struct AcidRainPollockView: View {
    let config: DriftModeConfig
    let speed: Double
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let raw = date.timeIntervalSinceReferenceDate
            let t = raw * max(0.25, speed) * 0.072

            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let center = CGPoint(x: size.width * 0.52, y: size.height * 0.48)

                // Soft atmospheric backdrop.
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        Gradient(colors: [
                            config.palette.backgroundTop.opacity(0.98),
                            config.palette.backgroundBottom.opacity(0.95)
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )

                // Subtle haze bloom for depth.
                context.fill(
                    Path(rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            config.palette.tertiary.opacity(0.11),
                            config.palette.secondary.opacity(0.09),
                            config.palette.primary.opacity(0.07),
                            Color.clear
                        ]),
                        center: center,
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 1.10
                    )
                )

                // MARK: Kelp strands (soft diagonal flow)

                let area = size.width * size.height
                let rainCount = Int((area / 18_500).clamped(to: 90...260))

                let wind = 0.14 + 0.05 * sin(t * 0.07)
                let baseAngle = (-Double.pi * (0.18 + wind))

                let rainA = Color(red: 0.35, green: 0.96, blue: 0.78)
                let rainB = Color(red: 0.54, green: 0.88, blue: 0.97)
                let rainC = config.palette.tertiary

                for i in 0..<rainCount {
                    let r1 = hash01(i, 31)
                    let r2 = hash01(i, 67)
                    let r3 = hash01(i, 101)

                    // Start positions
                    let x0 = CGFloat(r1) * size.width

                    // Falling phase
                    let sp = 0.10 + 0.34 * r2
                    let ph = fract(t * (0.07 + sp) + r3)
                    let y0 = (CGFloat(ph) * (size.height + 240)) - 120

                    let len = CGFloat(48 + 102 * r2)
                    let w = CGFloat(0.8 + 1.5 * pow(r3, 1.6))

                    let wav = CGFloat(3.8 * sin(t * (0.34 + 0.16 * r2) + Double(i) * 0.7))

                    // Keep direction coherent with mild variation.
                    let spread = (hash01(i, 151) - 0.5) * 0.36 // ~±0.18 rad
                    let flip = (hash01(i, 173) > 0.97) ? Double.pi : 0.0
                    let angle = baseAngle + spread + flip

                    let dx = CGFloat(cos(angle))
                    let dy = CGFloat(sin(angle))

                    let p0 = CGPoint(x: x0 + wav, y: y0)
                    let p1 = CGPoint(x: p0.x + dx * len, y: p0.y + dy * len)

                    // Occasional soft curvature keeps strands organic.
                    let shimmyOn = (i % 14 == 0) || (r3 > 0.95)

                    var path = Path()
                    if shimmyOn {
                        let steps = 5
                        let perp = CGPoint(x: -dy, y: dx)
                        let amp = CGFloat(2.5 + 5.5 * r2)
                        let freq = 1.8 + 3.0 * r1
                        let spd = 0.42 + 0.35 * r2
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

                    let col: Color = (i % 21 == 0) ? rainC : ((i % 2 == 0) ? rainA : rainB)

                    // Opacity ramp — brighter mid‑flight
                    let mid = 1.0 - abs(Double(ph) - 0.5) * 2.0
                    let a = 0.04 + 0.11 * mid

                    context.stroke(path, with: .color(col.opacity(a * 0.34)), lineWidth: w * 4.4)
                    context.stroke(path, with: .color(col.opacity(a * 0.66)), lineWidth: w * 2.0)
                    context.stroke(path, with: .color(col.opacity(a * 0.92)), lineWidth: w)
                    context.stroke(path, with: .color(Color.white.opacity(a * 0.16)), lineWidth: max(0.7, w * 0.45))
                }

                // MARK: Suspended bioluminescent flecks

                let splatCount = Int((area / 15_500).clamped(to: 90...300))
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
                    let dx = CGFloat(3.4 * sin(t * 0.04 + Double(i) * 0.9))
                    let dy = CGFloat(2.8 * cos(t * 0.03 + Double(i) * 0.7))

                    let s = 0.7 + 2.0 * pow(r3, 1.6)

                    // Color mix, with occasional bright speck
                    let col: Color = {
                        if i % 43 == 0 { return Color.white }
                        if i % 19 == 0 { return splatC }
                        if i % 13 == 0 { return splatB }
                        return splatA
                    }()

                    let sparkle = (r3 > 0.92) ? (0.5 + 0.5 * sin(t * (0.54 + 0.40 * r2) + Double(i))) : 0.0
                    let a = (0.018 + 0.060 * r3) + 0.065 * sparkle

                    context.fill(
                        Path(ellipseIn: CGRect(x: x + dx, y: y + dy, width: s, height: s)),
                        with: .color(col.opacity(a))
                    )

                    // Rare subtle drip for organic character.
                    if i % 79 == 0 {
                        let dripLen = CGFloat(12 + 26 * r2)
                        let w = CGFloat(0.9 + 1.2 * r3)
                        let dripRect = CGRect(x: x + dx, y: y + dy, width: w, height: dripLen)
                        context.fill(Path(roundedRect: dripRect, cornerRadius: w * 0.6), with: .color(col.opacity(0.03 + 0.05 * r3)))
                    }
                }

                // MARK: Soft pulse rings

                let pulseCount = 5
                for k in 0..<pulseCount {
                    let r1 = hash01(k, 911)
                    let r2 = hash01(k, 947)

                    let baseX = size.width * (0.16 + 0.70 * CGFloat(r1))
                    let baseY = size.height * (0.16 + 0.70 * CGFloat(r2))

                    // Each pulse has its own phase (slow)
                    let ph = fract(t * (0.04 + 0.02 * Double(k)) + Double(k) * 0.37)
                    let s = smoothstep(1.0 - abs(ph - 0.5) * 2.0)

                    let r = (min(size.width, size.height) * 0.06) + (min(size.width, size.height) * 0.10) * CGFloat(ph)
                    let op = 0.015 + 0.060 * s

                    let ring = Path(ellipseIn: CGRect(x: baseX - r, y: baseY - r, width: r * 2, height: r * 2))

                    let col: Color = (k % 3 == 0) ? rainA : ((k % 3 == 1) ? rainB : rainC)
                    context.stroke(ring, with: .color(col.opacity(op * 0.45)), lineWidth: 7)
                    context.stroke(ring, with: .color(col.opacity(op * 0.70)), lineWidth: 3)
                    context.stroke(ring, with: .color(Color.white.opacity(op * 0.16)), lineWidth: 1.0)
                }

                // Gentle sweep to unify the whole composition
                let sweepX = center.x + CGFloat(sin(t * 0.075)) * size.width * 0.34
                let sweepRect = CGRect(x: sweepX - 130, y: 0, width: 260, height: size.height)
                context.fill(
                    Path(sweepRect),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.00),
                            Color.white.opacity(0.03),
                            Color.white.opacity(0.00)
                        ]),
                        startPoint: CGPoint(x: sweepRect.minX, y: 0),
                        endPoint: CGPoint(x: sweepRect.maxX, y: 0)
                    )
                )

                // Edge vignette for calmer long-session viewing.
                context.fill(
                    Path(rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.clear,
                            Color.black.opacity(0.18)
                        ]),
                        center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                        startRadius: min(size.width, size.height) * 0.20,
                        endRadius: max(size.width, size.height) * 0.86
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
