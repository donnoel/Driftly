import SwiftUI

struct LunarDriftView: View {
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
            // Soft night-sky background
            LinearGradient(
                colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Main moon + halo
            moonLayer(phase: t)
                .blendMode(.screen)
                .opacity(0.95)

            // Reflection / ground glow
            reflectionLayer(phase: t)
                .blendMode(.screen)
                .opacity(0.75)

            // Horizontal drift haze
            driftHazeLayer(phase: t)
                .blendMode(.screen)
                .opacity(0.55)
        }
        // Allow the stack to render without forcing an offscreen composite.
    }

    private func currentPhase(for date: Date) -> Double {
        return phaseController.phase(
            for: date,
            speed: speedMultiplier,
            cycleDuration: max(config.cycleDuration, 12),
            paused: animationsPaused
        )
    }

    // MARK: - Moon

    @ViewBuilder
    private func moonLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = min(size.width, size.height)

            let verticalDrift = CGFloat(sin(t * .pi * 2)) * base * 0.08
            let subtlePulse = 0.75 + 0.25 * sin(t * .pi * 2)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                config.palette.secondary.opacity(0.7 * subtlePulse),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: base * 0.55
                        )
                    )
                    .frame(width: base * 0.9, height: base * 0.9)
                    .position(
                        x: size.width * 0.5,
                        y: size.height * (0.28 + verticalDrift / base)
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                config.palette.primary.opacity(0.95),
                                config.palette.primary.opacity(0.6),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: base * 0.35
                        )
                    )
                    .frame(width: base * 0.55, height: base * 0.55)
                    .position(
                        x: size.width * 0.5,
                        y: size.height * (0.28 + verticalDrift / base)
                    )
                    .blur(radius: base * 0.005)
            }
        }
    }

    // MARK: - Reflection

    @ViewBuilder
    private func reflectionLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = min(size.width, size.height)

            let wobble = CGFloat(sin(t * .pi * 2)) * base * 0.08

            RoundedRectangle(cornerRadius: base * 0.35, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            config.palette.tertiary.opacity(0.5),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size.width * 0.85, height: base * 0.28)
                .position(
                    x: size.width * 0.5 + wobble * 0.25,
                    y: size.height * 0.72 + wobble * 0.45
                )
                .blur(radius: base * 0.08)
        }
    }

    // MARK: - Drift haze

    @ViewBuilder
    private func driftHazeLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = min(size.width, size.height)

            let driftOffset = CGFloat(sin(t * .pi * 2)) * size.width * 0.22

            ZStack {
                RoundedRectangle(cornerRadius: base * 0.4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                config.palette.secondary.opacity(0.26),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size.width * 1.45, height: base * 0.26)
                    .position(
                        x: size.width * 0.5 + driftOffset,
                        y: size.height * 0.5
                    )

                RoundedRectangle(cornerRadius: base * 0.4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                config.palette.tertiary.opacity(0.22),
                                Color.clear
                            ],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .frame(width: size.width * 1.35, height: base * 0.22)
                    .position(
                        x: size.width * 0.5 - driftOffset * 0.7,
                        y: size.height * 0.58
                    )
            }
            .blur(radius: base * 0.06)
        }
    }
}
