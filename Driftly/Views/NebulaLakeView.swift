import SwiftUI

struct NebulaLakeView: View {
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
            // Background uses palette
            LinearGradient(
                colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Nebula blobs use primary/secondary/tertiary
            nebulaLayer(phase: t)
                .blendMode(.screen)
                .opacity(0.88)

            // Low-frequency depth veil keeps the scene rich without noise.
            depthVeilLayer(phase: t)
                .blendMode(.screen)
                .opacity(0.44)

            starDustLayer(phase: t)
                .blendMode(.screen)
                .opacity(0.34)

            // Subtle edge falloff improves long-session comfort.
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.24)
                ],
                center: .center,
                startRadius: 120,
                endRadius: 760
            )
        }
        // Avoid forcing an offscreen composite for the full-scene stack.
    }

    private func currentPhase(for date: Date) -> Double {
        phaseController.phase(
            for: date,
            speed: speedMultiplier,
            cycleDuration: config.cycleDuration,
            paused: animationsPaused
        )
    }

    @ViewBuilder
    private func nebulaLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = min(size.width, size.height)
            let phase = t * .pi * 2

            let offset1 = CGPoint(
                x: size.width * (0.24 + 0.20 * CGFloat(sin(phase * 0.55))),
                y: size.height * (0.30 + 0.15 * CGFloat(cos(phase * 0.45)))
            )

            let offset2 = CGPoint(
                x: size.width * (0.70 + 0.14 * CGFloat(cos(phase * 0.50))),
                y: size.height * (0.64 + 0.18 * CGFloat(sin(phase * 0.42)))
            )

            let offset3 = CGPoint(
                x: size.width * (0.50 + 0.18 * CGFloat(sin(phase * 0.86))),
                y: size.height * (0.42 + 0.10 * CGFloat(sin(phase * 0.58)))
            )

            ZStack {
                // PRIMARY
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                config.palette.primary.opacity(0.78),
                                config.palette.backgroundBottom.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: base * 1.06
                        )
                    )
                    .frame(width: base * 1.48, height: base * 1.48)
                    .position(offset1)

                // SECONDARY
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                config.palette.secondary.opacity(0.76),
                                config.palette.backgroundBottom.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: base * 1.20
                        )
                    )
                    .frame(width: base * 1.84, height: base * 1.84)
                    .position(offset2)

                // TERTIARY
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                config.palette.tertiary.opacity(0.48),
                                config.palette.backgroundBottom.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: base * 0.94
                        )
                    )
                    .frame(width: base * 1.32, height: base * 1.32)
                    .position(offset3)
                    .blur(radius: base * 0.06)
            }
        }
    }

    @ViewBuilder
    private func depthVeilLayer(phase t: Double) -> some View {
        let phase = t * .pi * 2
        let centerA = UnitPoint(
            x: 0.50 + 0.10 * sin(phase * 0.24),
            y: 0.66 + 0.06 * cos(phase * 0.22)
        )
        let centerB = UnitPoint(
            x: 0.52 + 0.08 * cos(phase * 0.18),
            y: 0.74 + 0.06 * sin(phase * 0.20)
        )

        RadialGradient(
            colors: [
                config.palette.secondary.opacity(0.26),
                Color.clear
            ],
            center: centerA,
            startRadius: 0,
            endRadius: 420
        )
        .overlay(
            RadialGradient(
                colors: [
                    config.palette.primary.opacity(0.18),
                    Color.clear
                ],
                center: centerB,
                startRadius: 0,
                endRadius: 520
            )
        )
    }

    @ViewBuilder
    private func starDustLayer(phase t: Double) -> some View {
        let phase = t * .pi * 2
        RadialGradient(
            colors: [
                Color.white.opacity(0.15),
                Color.white.opacity(0.0)
            ],
            center: UnitPoint(
                x: 0.22 + 0.06 * cos(phase * 0.36),
                y: 0.12 + 0.05 * sin(phase * 0.30)
            ),
            startRadius: 0,
            endRadius: 320
        )
        .overlay(
            RadialGradient(
                colors: [
                    Color.white.opacity(0.09),
                    Color.white.opacity(0.0)
                ],
                center: UnitPoint(
                    x: 0.80 + 0.05 * sin(phase * 0.34),
                    y: 0.70 + 0.05 * cos(phase * 0.28)
                ),
                startRadius: 0,
                endRadius: 380
            )
        )
        // Keep the halo soft but cheaper than a wide blur
        .blur(radius: 0.45)
    }
}
