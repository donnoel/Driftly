import SwiftUI

struct AuroraVeilView: View {
    let config: DriftModeConfig

    var body: some View {
        TimelineView(.animation) { context in
            let t = normalizedPhase(for: context.date)

            ZStack {
                // Background driven by palette
                LinearGradient(
                    colors: [
                        config.palette.backgroundTop,
                        config.palette.backgroundBottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Main aurora curtains
                auroraCurtains(phase: t)
                    .blendMode(.screen)
                    .opacity(0.95)

                // Soft mist / haze
                auroraMist(phase: t)
                    .blendMode(.screen)
                    .opacity(0.6)
            }
            .compositingGroup()
        }
    }

    private func normalizedPhase(for date: Date) -> Double {
        let raw = date.timeIntervalSinceReferenceDate
        let cycle = max(config.cycleDuration, 10)
        let wrapped = raw.truncatingRemainder(dividingBy: cycle)
        return wrapped / cycle // 0...1
    }

    // MARK: - Curtains

    @ViewBuilder
    private func auroraCurtains(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = max(size.width, size.height)

            let wave1 = CGFloat(sin(t * .pi * 2))
            let wave2 = CGFloat(cos(t * .pi * 2))
            let wave3 = CGFloat(sin(t * .pi * 4))

            ZStack {
                auroraBand(
                    in: size,
                    base: base,
                    centerXFactor: 0.25 + 0.02 * wave1,
                    tilt: -10,
                    heightFactor: 1.2,
                    color: config.palette.primary
                )

                auroraBand(
                    in: size,
                    base: base,
                    centerXFactor: 0.50 + 0.03 * wave2,
                    tilt: 0,
                    heightFactor: 1.35,
                    color: config.palette.secondary
                )

                auroraBand(
                    in: size,
                    base: base,
                    centerXFactor: 0.75 + 0.02 * wave3,
                    tilt: 12,
                    heightFactor: 1.15,
                    color: config.palette.tertiary
                )
            }
        }
    }

    private func auroraBand(
        in size: CGSize,
        base: CGFloat,
        centerXFactor: CGFloat,
        tilt: Double,
        heightFactor: CGFloat,
        color: Color
    ) -> some View {
        let bandWidth = size.width * 0.32
        let bandHeight = base * heightFactor

        return RoundedRectangle(cornerRadius: bandWidth / 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(0.0),
                        color.opacity(0.85),
                        color.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: bandWidth, height: bandHeight)
            .position(
                x: size.width * centerXFactor,
                y: size.height * 0.45
            )
            .rotationEffect(.degrees(tilt))
            .blur(radius: bandWidth * 0.45)
    }

    // MARK: - Mist / Haze

    @ViewBuilder
    private func auroraMist(phase t: Double) -> some View {
        let yShift = 0.1 * sin(t * .pi * 2)

        ZStack {
            RadialGradient(
                colors: [
                    config.palette.secondary.opacity(0.35),
                    Color.clear
                ],
                center: UnitPoint(x: 0.3, y: 0.1 + yShift),
                startRadius: 0,
                endRadius: 260
            )

            RadialGradient(
                colors: [
                    config.palette.primary.opacity(0.30),
                    Color.clear
                ],
                center: UnitPoint(x: 0.7, y: 0.25 - yShift),
                startRadius: 0,
                endRadius: 260
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.clear,
                    Color.white.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.45)
        }
        .blur(radius: 2.0)
    }
}
