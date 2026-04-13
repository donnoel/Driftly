import SwiftUI

struct StarlitMistView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speedMultiplier
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.driftPhaseAnchorDate) private var phaseAnchorDate
    @State private var phaseController = PhaseController()

    var body: some View {
        Group {
            if animationsPaused {
                content(phase: currentPhase(for: Date()))
            } else {
                TimelineView(.periodic(from: .now, by: 1.0 / 60.0)) { context in
                    content(phase: currentPhase(for: context.date))
                }
            }
        }
        .onAppear {
            phaseController.resetStart(date: phaseAnchorDate)
        }
        .onChange(of: phaseAnchorDate) { _, newValue in
            phaseController.resetStart(date: newValue)
        }
    }

    @ViewBuilder
    private func content(phase t: Double) -> some View {
        ZStack {
            // Background: soft night sky
            LinearGradient(
                colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Starfield
            starField(phase: t)
                .blendMode(.screen)
                .opacity(0.95)

            // Mist / fog
            mistLayer(phase: t)
                .blendMode(.screen)
                .opacity(0.8)

            // Gentle sweeping light band
            sweepLayer(phase: t)
                .blendMode(.screen)
                .opacity(0.55)

            // Subtle vignette keeps edges calmer for long-duration viewing.
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.22)
                ],
                center: .center,
                startRadius: 80,
                endRadius: 760
            )
        }
        // Avoid forcing an offscreen group; layers already blend via gradients.
    }

    private func currentPhase(for date: Date) -> Double {
        phaseController.phase(
            for: date,
            speed: speedMultiplier,
            cycleDuration: max(config.cycleDuration, 12),
            paused: animationsPaused
        )
    }

    // MARK: - Starfield

    @ViewBuilder
    private func starField(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size

            Canvas { context, canvasSize in
                let starCount = 150
                let phase = t * .pi * 2

                for index in 0..<starCount {
                    // Pseudo-random-ish positions, stable over time
                    let fi = CGFloat(index)
                    let xBase = (sin(fi * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let yBase = (cos(fi * 78.233) * 12345.6789).truncatingRemainder(dividingBy: 1)

                    let x = abs(xBase) * canvasSize.width
                    let y = abs(yBase) * canvasSize.height

                    // Calm twinkle: each star has its own cadence and gentle variation.
                    let r1 = hash01(index, 11)
                    let r2 = hash01(index, 97)
                    let r3 = hash01(index, 211)

                    // Slower cadence biases toward ambient, premium motion.
                    let speed1 = 0.16 + 0.72 * r1
                    let speed2 = 0.08 + 0.42 * r2
                    let off1 = 6.283185307179586 * r2
                    let off2 = 6.283185307179586 * r3

                    // Scintillation is a mix of two low-frequency waves (non-synchronized)
                    let s1 = sin(phase * speed1 + off1)
                    let s2 = cos(phase * speed2 + off2)
                    var scint = 0.58 + 0.28 * s1 + 0.14 * s2
                    scint = min(1.0, max(0.0, scint))

                    // Nonlinear response: strong bias toward subtle twinkle.
                    let gamma = 2.1 + 1.0 * (1.0 - r1)
                    let tw = pow(scint, gamma)

                    // Rare, restrained sparkle spikes.
                    let sparkleWave = 0.5 + 0.5 * sin(phase * (1.1 + 0.8 * r2) + off2)
                    let sparkle = (r3 > 0.92) ? smoothstep((sparkleWave - 0.86) / 0.14) : 0.0

                    // Star "magnitude" distribution: many faint, few bright
                    let mag = 0.18 + 0.82 * pow(r1, 1.7)

                    let radius = 0.80 + 1.28 * tw + 0.26 * sparkle
                    let baseOpacity: CGFloat = CGFloat((0.09 + 0.66 * tw + 0.20 * sparkle) * mag)

                    var star = Path()
                    star.addEllipse(in: CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))

                    // Slight temperature variation (warm/cool) like real stars
                    let temp = r2
                    let tint = starTintColor(temperature: temp, opacity: Double(baseOpacity))

                    context.fill(star, with: .color(tint))
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    // MARK: - Mist

    @ViewBuilder
    private func mistLayer(phase t: Double) -> some View {
        let phase = t * .pi * 2
        let shiftA = 0.10 * sin(phase * 0.55)
        let shiftB = 0.07 * cos(phase * 0.42)

        ZStack {
            RadialGradient(
                colors: [
                    config.palette.secondary.opacity(0.34),
                    Color.clear
                ],
                center: UnitPoint(x: 0.30 + shiftB, y: 0.28 + shiftA),
                startRadius: 0,
                endRadius: 320
            )

            RadialGradient(
                colors: [
                    config.palette.tertiary.opacity(0.30),
                    Color.clear
                ],
                center: UnitPoint(x: 0.72 - shiftA, y: 0.40 - shiftB),
                startRadius: 0,
                endRadius: 340
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.clear,
                    Color.white.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.50)
        }
        // Keep haze soft without creating a heavy offscreen blur.
        .blur(radius: 1.0)
    }

    // MARK: - Sweep

    @ViewBuilder
    private func sweepLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = max(size.width, size.height)

            let phase = t * .pi * 2
            let sweepX = 0.5 + 0.26 * CGFloat(sin(phase * 0.45))
            let sweepY = 0.44 + 0.05 * CGFloat(cos(phase * 0.32))
            let sweepAngle = Angle.degrees(Double(7 * sin(phase * 0.35)))

            RoundedRectangle(cornerRadius: base * 0.5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            config.palette.secondary.opacity(0.18),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size.width * 0.84, height: base * 0.42)
                .position(
                    x: size.width * sweepX,
                    y: size.height * sweepY
                )
                .rotationEffect(sweepAngle)
                // Reduced blur to limit offscreen rendering cost
                .blur(radius: base * 0.055)
        }
    }
// MARK: - Helpers

    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Double(n & 0x7fffffff) / 2147483647.0
    }

    private func smoothstep(_ x: Double) -> Double {
        let t = max(0.0, min(1.0, x))
        return t * t * (3.0 - 2.0 * t)
    }

    private func starTintColor(temperature t: Double, opacity: Double) -> Color {
        let tt = max(0.0, min(1.0, t))
        let warm = (r: 1.00, g: 0.94, b: 0.84)
        let cool = (r: 0.86, g: 0.92, b: 1.00)
        let red = warm.r + (cool.r - warm.r) * tt
        let green = warm.g + (cool.g - warm.g) * tt
        let blue = warm.b + (cool.b - warm.b) * tt
        return Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}
