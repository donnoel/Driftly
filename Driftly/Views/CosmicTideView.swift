import SwiftUI

struct CosmicTideView: View {
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
            // Background from palette
            LinearGradient(
                colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            tideBandsLayer(phase: t)
                .blendMode(.screen)
                .opacity(0.9)

            shimmerLayer(phase: t)
                .blendMode(.screen)
                .opacity(0.55)
        }
        .compositingGroup()
    }

    private func normalizedPhase(for date: Date) -> Double {
        let raw = date.timeIntervalSinceReferenceDate * max(speedMultiplier, 0.1)
        let cycle = max(config.cycleDuration, 8)
        let wrapped = raw.truncatingRemainder(dividingBy: cycle)
        return wrapped / cycle
    }

    @ViewBuilder
    private func tideBandsLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = max(size.width, size.height)

            let verticalShift = CGFloat(sin(t * .pi * 2)) * base * 0.22
            let verticalShift2 = CGFloat(sin(t * .pi * 4 + .pi / 3)) * base * 0.08
            let horizontalShift = CGFloat(cos(t * .pi * 2)) * base * 0.12

            ZStack {
                // Top band – primary
                tideBand(
                    size: size,
                    base: base,
                    offsetY: base * 0.20 + verticalShift + verticalShift2,
                    color: config.palette.primary
                )

                // Middle band – secondary
                tideBand(
                    size: size,
                    base: base,
                    offsetY: base * 0.48 - verticalShift * 0.5 + verticalShift2 * 0.4,
                    color: config.palette.secondary
                )

                // Lower band – tertiary
                tideBand(
                    size: size,
                    base: base,
                    offsetY: base * 0.82 + verticalShift * 0.4 - verticalShift2 * 0.6,
                    color: config.palette.tertiary
                )
            }
            .offset(x: horizontalShift)
        }
    }

    private func tideBand(
        size: CGSize,
        base: CGFloat,
        offsetY: CGFloat,
        color: Color
    ) -> some View {
        RoundedRectangle(cornerRadius: base * 0.4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(0.9),
                        color.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size.width * 1.7, height: base * 0.55)
            .position(x: size.width / 2, y: offsetY)
            .blur(radius: base * 0.12)
    }

    @ViewBuilder
    private func shimmerLayer(phase t: Double) -> some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.05),
                Color.white.opacity(0.25),
                Color.white.opacity(0.05)
            ],
            startPoint: UnitPoint(
                x: 0 + 0.1 * sin(t * .pi * 2),
                y: 0.2 + 0.22 * sin(t * .pi * 2)
            ),
            endPoint: UnitPoint(
                x: 1 - 0.1 * cos(t * .pi * 2),
                y: 0.5 + 0.22 * cos(t * .pi * 2)
            )
        )
        .blur(radius: 2.6)
        .overlay(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.0)
                ],
                startPoint: UnitPoint(
                    x: 0.1,
                    y: 0.1 + 0.15 * sin(t * .pi * 3)
                ),
                endPoint: UnitPoint(
                    x: 0.9,
                    y: 0.4 + 0.15 * cos(t * .pi * 3)
                )
            )
            .blur(radius: 1.2)
        )
    }
}
