import SwiftUI

struct StarlitMistView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speedMultiplier
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.driftPhaseAnchorDate) private var phaseAnchorDate
    @State private var phaseController = PhaseController()
    @State private var didApplyPhaseAnchor = false

    var body: some View {
        if animationsPaused {
            content(phase: currentPhase(for: Date()))
        } else {
            TimelineView(.animation) { context in
                content(phase: currentPhase(for: context.date))
            }
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
        }
        .compositingGroup()
    }

    private func currentPhase(for date: Date) -> Double {
        if !didApplyPhaseAnchor {
            phaseController.resetStart(date: phaseAnchorDate)
            didApplyPhaseAnchor = true
        }
        return phaseController.phase(
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
                let starCount = 180
                let phase = t * .pi * 2

                for index in 0..<starCount {
                    // Pseudo-random-ish positions, stable over time
                    let fi = CGFloat(index)
                    let xBase = (sin(fi * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let yBase = (cos(fi * 78.233) * 12345.6789).truncatingRemainder(dividingBy: 1)

                    let x = abs(xBase) * canvasSize.width
                    let y = abs(yBase) * canvasSize.height

                    // Real-ish twinkle: each star has its own cadence + amplitude + rare micro-sparkles
                    let r1 = hash01(index, 11)
                    let r2 = hash01(index, 97)
                    let r3 = hash01(index, 211)

                    // Most stars vary slowly; some twinkle a bit faster
                    let speed1 = 0.25 + 1.10 * r1
                    let speed2 = 0.10 + 0.70 * r2
                    let off1 = 6.283185307179586 * r2
                    let off2 = 6.283185307179586 * r3

                    // Scintillation is a mix of two low-frequency waves (non-synchronized)
                    let s1 = sin(phase * speed1 + off1)
                    let s2 = cos(phase * speed2 + off2)
                    var scint = 0.58 + 0.28 * s1 + 0.14 * s2
                    scint = min(1.0, max(0.0, scint))

                    // Nonlinear response: lots of subtle twinkle, fewer big flashes
                    let gamma = 1.6 + 1.4 * (1.0 - r1)
                    let tw = pow(scint, gamma)

                    // Rare micro-sparkle: a small spike that comes and goes smoothly
                    let sparkleWave = 0.5 + 0.5 * sin(phase * (1.8 + 1.2 * r2) + off2)
                    let sparkle = (r3 > 0.86) ? smoothstep((sparkleWave - 0.78) / 0.22) : 0.0

                    // Star "magnitude" distribution: many faint, few bright
                    let mag = 0.18 + 0.82 * pow(r1, 1.7)

                    let radius = 0.85 + 1.55 * tw + 0.55 * sparkle
                    let baseOpacity: CGFloat = CGFloat((0.10 + 0.70 * tw + 0.35 * sparkle) * mag)

                    var star = Path()
                    star.addEllipse(in: CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))

                    // Slight temperature variation (warm/cool) like real stars
                    let temp = r2
                    let warm = Color(red: 1.00, green: 0.94, blue: 0.84)
                    let cool = Color(red: 0.86, green: 0.92, blue: 1.00)
                    let tint = interpolateColor(warm, cool, t: temp)

                    let starColor = tint.opacity(Double(baseOpacity))

                    context.fill(star, with: .color(starColor))
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    // MARK: - Mist

    @ViewBuilder
    private func mistLayer(phase t: Double) -> some View {
        let shift = 0.18 * sin(t * .pi * 2)

        ZStack {
            RadialGradient(
                colors: [
                    config.palette.secondary.opacity(0.38),
                    Color.clear
                ],
                center: UnitPoint(x: 0.3, y: 0.25 + shift),
                startRadius: 0,
                endRadius: 280
            )

            RadialGradient(
                colors: [
                    config.palette.tertiary.opacity(0.35),
                    Color.clear
                ],
                center: UnitPoint(x: 0.7, y: 0.35 - shift),
                startRadius: 0,
                endRadius: 300
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.clear,
                    Color.white.opacity(0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.55)
        }
        .blur(radius: 3.0)
    }

    // MARK: - Sweep

    @ViewBuilder
    private func sweepLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = max(size.width, size.height)

            let sweepX = 0.5 + 0.45 * CGFloat(sin(t * .pi * 2))
            let sweepAngle = Angle.degrees(Double(18 * sin(t * .pi * 2)))

            RoundedRectangle(cornerRadius: base * 0.5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size.width * 0.95, height: base * 0.55)
                .position(
                    x: size.width * sweepX,
                    y: size.height * 0.40
                )
                .rotationEffect(sweepAngle)
                .blur(radius: base * 0.18)
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

    private func interpolateColor(_ a: Color, _ b: Color, t: Double) -> Color {
        let tt = max(0.0, min(1.0, t))
        #if canImport(UIKit)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(a).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(b).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: Double(r1 + (r2 - r1) * CGFloat(tt)),
            green: Double(g1 + (g2 - g1) * CGFloat(tt)),
            blue: Double(b1 + (b2 - b1) * CGFloat(tt)),
            opacity: Double(a1 + (a2 - a1) * CGFloat(tt))
        )
        #else
        return a
        #endif
    }
}
