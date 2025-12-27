import SwiftUI

struct MeridianArcsView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        if animationsPaused {
            staticBackground
        } else {
            TimelineView(.periodic(from: .now, by: 1.0 / 60.0)) { timeline in
                let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                let effectiveSpeed = max(0.25, speed) * (isLowPower ? 0.75 : 1.0)
                let t = timeline.date.timeIntervalSinceReferenceDate * effectiveSpeed

                GeometryReader { proxy in
                    let size = proxy.size
                    let center = CGPoint(x: size.width * 0.5, y: size.height * 0.55)

                    Canvas { context, _ in
                        context.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .linearGradient(
                                Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                                startPoint: CGPoint(x: 0, y: 0),
                                endPoint: CGPoint(x: size.width, y: size.height)
                            )
                        )

                        // Soft bloom overlay to lift the scene for daytime viewing
                        context.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .radialGradient(
                                Gradient(colors: [
                                    config.palette.primary.opacity(0.14),
                                    config.palette.secondary.opacity(0.10),
                                    Color.clear
                                ]),
                                center: center,
                                startRadius: 0,
                                endRadius: max(size.width, size.height) * 0.85
                            )
                        )

                        guard !animationsPaused else { return }

                        let arcCount = isLowPower ? 10 : 14
                        let steps = isLowPower ? 120 : 180

                        // Ripple selection switches smoothly over time (no popping)
                        let window = 6.0
                        let k0 = Int(floor(t / window))
                        let uWin = fract(t / window)
                        let sWin = smoothstep(uWin)

                        for i in 0..<arcCount {
                            let p = Double(i) / Double(max(1, arcCount - 1))

                            // Some arcs ripple; selection crossfades between windows
                            let sel0 = rippleSelection(index: i, key: k0)
                            let sel1 = rippleSelection(index: i, key: k0 + 1)
                            let rippleMix = lerp(sel0, sel1, sWin) // 0..1

                            let lobes = 8 + (i % 4) * 2
                            let ripplePhase = t * (0.55 + 0.05 * Double(i)) + Double(i) * 0.7

                            let radiusX = min(size.width, size.height) * (0.22 + 0.38 * p)
                            let radiusY = radiusX * (0.55 + 0.10 * sin(t*0.05 + p*3))

                            var arc = Path()
                            let start = Double.pi * (0.15 + 0.08 * sin(t*0.03 + p*4))
                            let end = Double.pi * (1.85 + 0.08 * cos(t*0.03 + p*3))

                            for s in 0...steps {
                                let u = DriftNoise.lerp(start, end, Double(s) / Double(steps))
                                // Ripple is a small radial modulation around the arc (only for selected arcs)
                                let amp = (radiusX * 0.020) * rippleMix
                                let rMod = amp * sin(Double(lobes) * u + ripplePhase)
                                let x = center.x + CGFloat((radiusX + rMod) * cos(u))
                                let y = center.y + CGFloat((radiusY + 0.85 * rMod) * sin(u))
                                if s == 0 { arc.move(to: CGPoint(x: x, y: y)) }
                                else { arc.addLine(to: CGPoint(x: x, y: y)) }
                            }

                            let col: Color = (i % 3 == 0) ? config.palette.tertiary : (i % 3 == 1 ? config.palette.secondary : config.palette.primary)
                            // Layered glow so arcs read clearly
                            context.stroke(arc, with: .color(col.opacity(0.08)), lineWidth: 7.0)
                            context.stroke(arc, with: .color(col.opacity(0.14)), lineWidth: 3.2)
                            context.stroke(arc, with: .color(col.opacity(0.26)), lineWidth: 1.6)
                            context.stroke(arc, with: .color(Color.white.opacity(0.08)), lineWidth: 0.9)
                        }
                    }
                    .blur(radius: 0.45)
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Ripple Helpers

    private func rippleSelection(index: Int, key: Int) -> Double {
        // Select ~1/3 of arcs per window; pattern rotates over time.
        let a = (index + key * 2) % 9
        return (a == 0 || a == 3 || a == 6) ? 1.0 : 0.0
    }

    private func fract(_ x: Double) -> Double { x - floor(x) }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    private func smoothstep(_ x: Double) -> Double {
        let t = max(0.0, min(1.0, x))
        return t * t * (3.0 - 2.0 * t)
    }

    private var staticBackground: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.55)
            ZStack {
                LinearGradient(
                    colors: [config.palette.backgroundTop, config.palette.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        config.palette.primary.opacity(0.14),
                        config.palette.secondary.opacity(0.10),
                        Color.clear
                    ],
                    center: .init(x: center.x / size.width, y: center.y / size.height),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.85
                )
            }
            .ignoresSafeArea()
        }
    }
}
