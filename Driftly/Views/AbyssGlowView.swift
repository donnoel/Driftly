import SwiftUI

struct AbyssGlowView: View {
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
            // Deep ocean background
            LinearGradient(
                colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Soft vertical glow columns
            glowColumns(phase: t)
                .blendMode(.screen)
                .opacity(0.9)

            // Bottom vents / bloom
            abyssVents(phase: t)
                .blendMode(.screen)
                .opacity(0.85)
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
            cycleDuration: max(config.cycleDuration, 10),
            paused: animationsPaused
        )
    }

    // MARK: - Vertical glow shafts

    @ViewBuilder
    private func glowColumns(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = max(size.width, size.height)

            let sway1 = CGFloat(sin(t * .pi * 2)) * 0.12
            let sway2 = CGFloat(cos(t * .pi * 2)) * 0.12
            let sway3 = CGFloat(sin(t * .pi * 4)) * 0.16

            ZStack {
                glowColumn(
                    in: size,
                    base: base,
                    centerXFactor: 0.25 + sway1,
                    heightFactor: 1.5,
                    color: config.palette.secondary.opacity(0.85)
                )

                glowColumn(
                    in: size,
                    base: base,
                    centerXFactor: 0.50 + sway2 * 0.9,
                    heightFactor: 1.7,
                    color: config.palette.primary.opacity(0.95)
                )

                glowColumn(
                    in: size,
                    base: base,
                    centerXFactor: 0.78 + sway3 * 0.8,
                    heightFactor: 1.4,
                    color: config.palette.tertiary.opacity(0.8)
                )
            }
        }
    }

    private func glowColumn(
        in size: CGSize,
        base: CGFloat,
        centerXFactor: CGFloat,
        heightFactor: CGFloat,
        color: Color
    ) -> some View {
        let columnWidth = size.width * 0.26
        let columnHeight = base * heightFactor

        return RoundedRectangle(cornerRadius: columnWidth / 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        color,
                        Color.clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: columnWidth, height: columnHeight)
            .position(
                x: size.width * centerXFactor,
                y: size.height * 0.55
            )
            .blur(radius: columnWidth * 0.55)
    }

    // MARK: - Bottom vents / blooms

    @ViewBuilder
    private func abyssVents(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = max(size.width, size.height)

            let pulse = 0.75 + 0.25 * sin(t * .pi * 2)
            let offset = CGFloat(sin(t * .pi * 2)) * base * 0.10
            let offset2 = CGFloat(cos(t * .pi * 3)) * base * 0.06

            ZStack {
                // Central vent
                RadialGradient(
                    colors: [
                        config.palette.primary.opacity(0.9 * pulse),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: base * 0.6
                )
                .frame(width: base * 1.4, height: base * 1.0)
                .position(
                    x: size.width * 0.5,
                    y: size.height * 0.98 + offset
                )

                // Left bloom
                RadialGradient(
                    colors: [
                        config.palette.secondary.opacity(0.8),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: base * 0.5
                )
                .frame(width: base * 1.0, height: base * 0.8)
                .position(
                    x: size.width * 0.2,
                    y: size.height * 0.96 - offset + offset2
                )

                // Right bloom
                RadialGradient(
                    colors: [
                        config.palette.tertiary.opacity(0.75),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: base * 0.5
                )
                .frame(width: base * 1.0, height: base * 0.8)
                .position(
                    x: size.width * 0.8,
                    y: size.height * 0.99 + offset2 * 0.6
                )
            }
            .blur(radius: base * 0.05)
        }
    }
}
