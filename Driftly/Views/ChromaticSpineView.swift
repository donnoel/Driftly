import SwiftUI

struct ChromaticSpineView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    // Background
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    // Spine curves (layered) — diagonal snake + occasional tangles
                    let midY = size.height * 0.5
                    let midX = size.width * (0.50 + 0.06 * sin(t * 0.10))

                    func makeSpine(xBase: CGFloat, phase: Double, ampScale: Double, freqScale: Double, slope: CGFloat, tangle: CGFloat) -> Path {
                        var p = Path()
                        p.move(to: CGPoint(x: xBase, y: -30))

                        for y in stride(from: -30.0, through: Double(size.height) + 60.0, by: 12.0) {
                            let yy = CGFloat(y)

                            // Diagonal drift across the screen (snake path)
                            let diag = slope * (yy - midY)

                            // Primary wobble
                            let wobble = (22.0 * sin(y * 0.012 * freqScale + t * 0.35 + phase)
                                          + 10.0 * cos(y * 0.020 * freqScale + t * 0.22 + phase * 0.6)) * ampScale

                            // Tangling term: a y-dependent oscillation that can push spines across each other
                            let knot = tangle * sin((Double(yy) * 0.010 * freqScale) + t * 0.55 + phase * 1.7)
                                   + (tangle * 0.55) * cos((Double(yy) * 0.018 * freqScale) + t * 0.38 + phase * 0.9)

                            // Slow lateral drift so tangles migrate over time
                            let drift = 18.0 * sin(t * 0.06 + phase)

                            let x = xBase + diag + CGFloat(wobble + knot + drift)
                            p.addLine(to: CGPoint(x: x, y: yy))
                        }

                        return p
                    }

                    let spineMain = makeSpine(
                        xBase: midX,
                        phase: 0.0,
                        ampScale: 1.00,
                        freqScale: 1.00,
                        slope: size.width * 0.00022,
                        tangle: 20
                    )
                    let spineLeft = makeSpine(
                        xBase: midX - 30,
                        phase: 1.15,
                        ampScale: 0.90,
                        freqScale: 0.94,
                        slope: size.width * 0.00024,
                        tangle: 26
                    )
                    let spineRight = makeSpine(
                        xBase: midX + 30,
                        phase: -0.95,
                        ampScale: 0.90,
                        freqScale: 0.94,
                        slope: size.width * 0.00020,
                        tangle: 26
                    )
                    // Extra strands to create "tangles"
                    let spineLeft2 = makeSpine(
                        xBase: midX - 54,
                        phase: 2.05,
                        ampScale: 0.78,
                        freqScale: 0.88,
                        slope: size.width * 0.00026,
                        tangle: 30
                    )
                    let spineRight2 = makeSpine(
                        xBase: midX + 54,
                        phase: -1.95,
                        ampScale: 0.78,
                        freqScale: 0.88,
                        slope: size.width * 0.00018,
                        tangle: 30
                    )

                    // Main spine (existing look)
                    context.stroke(spineMain, with: .color(config.palette.secondary.opacity(0.18)), lineWidth: 18)
                    context.stroke(spineMain, with: .color(config.palette.primary.opacity(0.24)), lineWidth: 8)
                    context.stroke(spineMain, with: .color(Color.white.opacity(0.10)), lineWidth: 2)

                    // Side spines (slightly thinner, accented)
                    let pink = Color(red: 1.00, green: 0.40, blue: 0.82)
                    let red = Color(red: 1.00, green: 0.22, blue: 0.32)

                    context.stroke(spineLeft, with: .color(pink.opacity(0.14)), lineWidth: 12)
                    context.stroke(spineLeft, with: .color(config.palette.primary.opacity(0.14)), lineWidth: 6)
                    context.stroke(spineLeft, with: .color(Color.white.opacity(0.08)), lineWidth: 1.6)

                    context.stroke(spineRight, with: .color(red.opacity(0.12)), lineWidth: 12)
                    context.stroke(spineRight, with: .color(config.palette.secondary.opacity(0.12)), lineWidth: 6)
                    context.stroke(spineRight, with: .color(Color.white.opacity(0.08)), lineWidth: 1.6)

                    // Additional strands (thin) to increase tangling
                    context.stroke(spineLeft2, with: .color(pink.opacity(0.10)), lineWidth: 9)
                    context.stroke(spineLeft2, with: .color(config.palette.tertiary.opacity(0.10)), lineWidth: 4)
                    context.stroke(spineLeft2, with: .color(Color.white.opacity(0.06)), lineWidth: 1.2)

                    context.stroke(spineRight2, with: .color(red.opacity(0.09)), lineWidth: 9)
                    context.stroke(spineRight2, with: .color(config.palette.primary.opacity(0.09)), lineWidth: 4)
                    context.stroke(spineRight2, with: .color(Color.white.opacity(0.06)), lineWidth: 1.2)

                    // Ribs: short lines perpendicular-ish
                    for i in 0..<150 {
                        let yy = CGFloat(i) / 150 * size.height
                        let phase = Double(i) * 0.2
                        let rib = 20 + 24 * (0.5 + 0.5 * sin(t * 0.25 + phase))
                        // Follow the diagonal snake a bit so ribs feel attached during tangles
                        let xShift = 18 * sin(Double(yy) * 0.01 + t * 0.35) + 10 * sin(Double(yy) * 0.006 + t * 0.22)

                        // A few ribs tilt diagonally for extra energy
                        let tilt = (i % 14 == 0) ? CGFloat(16) : ((i % 19 == 0) ? CGFloat(-14) : 0)

                        let left = CGPoint(x: midX - CGFloat(rib) + CGFloat(xShift), y: yy + tilt)
                        let right = CGPoint(x: midX + CGFloat(rib) + CGFloat(xShift), y: yy - tilt)

                        var p = Path()
                        p.move(to: left)
                        p.addLine(to: right)

                        let c: Color = {
                            // Add accent ribs (pink/red) mixed with palette colors
                            if i % 11 == 0 {
                                return Color(red: 1.00, green: 0.40, blue: 0.82) // pink
                            }
                            if i % 17 == 0 {
                                return Color(red: 1.00, green: 0.22, blue: 0.32) // red
                            }
                            switch i % 3 {
                            case 0: return config.palette.primary
                            case 1: return config.palette.secondary
                            default: return config.palette.tertiary
                            }
                        }()
                        context.stroke(p, with: .color(c.opacity(0.11)), lineWidth: 1.1)
                    }
                }
                .blur(radius: 0.7)
            }
            .ignoresSafeArea()
        }
    }
}
