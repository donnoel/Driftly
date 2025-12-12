import SwiftUI

struct NebulaLakeView: View {
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
                .opacity(0.95)

            starDustLayer(phase: t)
                .blendMode(.screen)
                .opacity(0.45)
        }
        .compositingGroup()
    }

    private func normalizedPhase(for date: Date) -> Double {
        let raw = date.timeIntervalSinceReferenceDate * max(speedMultiplier, 0.1)
        let wrapped = raw.truncatingRemainder(dividingBy: config.cycleDuration)
        return wrapped / config.cycleDuration
    }

    @ViewBuilder
    private func nebulaLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = min(size.width, size.height)

            let offset1 = CGPoint(
                x: size.width * (0.2 + 0.3 * CGFloat(sin(t * .pi * 2))),
                y: size.height * (0.3 + 0.2 * CGFloat(cos(t * .pi * 2)))
            )

            let offset2 = CGPoint(
                x: size.width * (0.7 + 0.2 * CGFloat(cos(t * .pi * 2))),
                y: size.height * (0.6 + 0.25 * CGFloat(sin(t * .pi * 2)))
            )

            let offset3 = CGPoint(
                x: size.width * (0.5 + 0.25 * CGFloat(sin(t * .pi * 4))),
                y: size.height * (0.4 + 0.15 * CGFloat(sin(t * .pi * 2)))
            )

            ZStack {
                // PRIMARY
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                config.palette.primary.opacity(0.9),
                                config.palette.backgroundBottom.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: base * 1.0
                        )
                    )
                    .frame(width: base * 1.4, height: base * 1.4)
                    .position(offset1)

                // SECONDARY
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                config.palette.secondary.opacity(0.9),
                                config.palette.backgroundBottom.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: base * 1.2
                        )
                    )
                    .frame(width: base * 1.7, height: base * 1.7)
                    .position(offset2)

                // TERTIARY
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                config.palette.tertiary.opacity(0.55),
                                config.palette.backgroundBottom.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: base * 0.9
                        )
                    )
                    .frame(width: base * 1.2, height: base * 1.2)
                    .position(offset3)
                    .blur(radius: base * 0.08)
            }
        }
    }

    @ViewBuilder
    private func starDustLayer(phase t: Double) -> some View {
        RadialGradient(
            colors: [
                Color.white.opacity(0.20),
                Color.white.opacity(0.0)
            ],
            center: UnitPoint(
                x: 0.2 + 0.1 * cos(t * .pi * 2),
                y: 0.1 + 0.1 * sin(t * .pi * 2)
            ),
            startRadius: 0,
            endRadius: 350
        )
        .overlay(
            RadialGradient(
                colors: [
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.0)
                ],
                center: UnitPoint(
                    x: 0.8 + 0.08 * sin(t * .pi * 2),
                    y: 0.7 + 0.08 * cos(t * .pi * 2)
                ),
                startRadius: 0,
                endRadius: 420
            )
        )
        .blur(radius: 1.5)
    }
}
