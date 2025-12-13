import SwiftUI

struct AuroraVeilView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speedMultiplier
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @State private var phaseController = PhaseController()

    var body: some View {
        TimelineView(.animation) { context in
            content(phase: currentPhase(for: context.date))
        }
    }

    @ViewBuilder
    private func content(phase t: Double) -> some View {
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

    private func currentPhase(for date: Date) -> Double {
        phaseController.phase(
            for: date,
            speed: speedMultiplier,
            cycleDuration: max(config.cycleDuration, 10),
            paused: animationsPaused
        )
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
            let wave4 = CGFloat(sin(t * .pi * 3 + .pi / 4))

            ZStack {
                auroraBand(
                    in: size,
                    base: base,
                    centerXFactor: 0.25 + 0.10 * wave1,
                    tilt: -14,
                    heightFactor: 1.35,
                    color: config.palette.primary
                )

                auroraBand(
                    in: size,
                    base: base,
                    centerXFactor: 0.50 + 0.12 * wave2,
                    tilt: 0,
                    heightFactor: 1.55,
                    color: config.palette.secondary
                )

                auroraBand(
                    in: size,
                    base: base,
                    centerXFactor: 0.75 + 0.10 * wave3 + 0.04 * wave4,
                    tilt: 18,
                    heightFactor: 1.30,
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
        let bandWidth = size.width * 0.38
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
        let yShift = 0.18 * sin(t * .pi * 2)
        let yShift2 = 0.12 * cos(t * .pi * 3)

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
            .opacity(0.55)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.0)
                ],
                startPoint: UnitPoint(x: 0.2, y: 0.2 + yShift2),
                endPoint: UnitPoint(x: 0.8, y: 0.5 - yShift2)
            )
            .blur(radius: 2.0)
        }
        .blur(radius: 2.6)
    }
}
