import SwiftUI

struct StarlitMistView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speedMultiplier
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        Group {
            if animationsPaused {
                content(phase: 0)
            } else {
                TimelineView(.animation) { context in
                    content(phase: normalizedPhase(for: context.date))
                }
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

    private func normalizedPhase(for date: Date) -> Double {
        let raw = date.timeIntervalSinceReferenceDate * max(speedMultiplier, 0.1)
        let cycle = max(config.cycleDuration, 12)
        let wrapped = raw.truncatingRemainder(dividingBy: cycle)
        return wrapped / cycle
    }

    // MARK: - Starfield

    @ViewBuilder
    private func starField(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size

            Canvas { context, canvasSize in
                let starCount = 140
                let phase = t * .pi * 2

                for index in 0..<starCount {
                    // Pseudo-random-ish positions, stable over time
                    let fi = CGFloat(index)
                    let xBase = (sin(fi * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let yBase = (cos(fi * 78.233) * 12345.6789).truncatingRemainder(dividingBy: 1)

                    let x = abs(xBase) * canvasSize.width
                    let y = abs(yBase) * canvasSize.height

                    // Tiny twinkle using phase offset
                    let twinkle = 0.5 + 0.5 * sin(phase * 0.8 + Double(fi) * 0.35)
                    let radius = 1.0 + 1.1 * twinkle

                    let baseOpacity: CGFloat = 0.25 + 0.6 * CGFloat(twinkle)

                    var star = Path()
                    star.addEllipse(in: CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))

                    let starColor = Color.white
                        .opacity(Double(baseOpacity))

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
}
