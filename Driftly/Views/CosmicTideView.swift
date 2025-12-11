import SwiftUI

struct CosmicTideView: View {
    let config: DriftModeConfig

    var body: some View {
        TimelineView(.animation) { context in
            let t = normalizedPhase(for: context.date)

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
    }

    private func normalizedPhase(for date: Date) -> Double {
        let raw = date.timeIntervalSinceReferenceDate
        let cycle = max(config.cycleDuration, 8)
        let wrapped = raw.truncatingRemainder(dividingBy: cycle)
        return wrapped / cycle
    }

    @ViewBuilder
    private func tideBandsLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = max(size.width, size.height)

            let verticalShift = CGFloat(sin(t * .pi * 2)) * base * 0.10
            let horizontalShift = CGFloat(cos(t * .pi * 2)) * base * 0.06

            ZStack {
                // Top band – primary
                tideBand(
                    size: size,
                    base: base,
                    offsetY: base * 0.20 + verticalShift,
                    color: config.palette.primary
                )

                // Middle band – secondary
                tideBand(
                    size: size,
                    base: base,
                    offsetY: base * 0.50 - verticalShift * 0.7,
                    color: config.palette.secondary
                )

                // Lower band – tertiary
                tideBand(
                    size: size,
                    base: base,
                    offsetY: base * 0.80 + verticalShift * 0.5,
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
                Color.white.opacity(0.0),
                Color.white.opacity(0.20),
                Color.white.opacity(0.0)
            ],
            startPoint: UnitPoint(
                x: 0,
                y: 0.25 + 0.15 * sin(t * .pi * 2)
            ),
            endPoint: UnitPoint(
                x: 1,
                y: 0.45 + 0.15 * cos(t * .pi * 2)
            )
        )
        .blur(radius: 1.8)
    }
}
