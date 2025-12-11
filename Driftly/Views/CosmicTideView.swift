import SwiftUI

struct CosmicTideView: View {
    let config: DriftModeConfig

    var body: some View {
        TimelineView(.animation) { context in
            let t = normalizedPhase(for: context.date)

            ZStack {
                // Warmer deep background with hints of magenta
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.01, blue: 0.10),
                        Color(red: 0.10, green: 0.02, blue: 0.22),
                        Color(red: 0.01, green: 0.01, blue: 0.06)
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
        let cycleDuration = max(config.cycleDuration, 8)
        let wrapped = raw.truncatingRemainder(dividingBy: cycleDuration)
        return wrapped / cycleDuration
    }

    @ViewBuilder
    private func tideBandsLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = max(size.width, size.height)

            let verticalShift = CGFloat(sin(t * .pi * 2)) * base * 0.1
            let horizontalShift = CGFloat(cos(t * .pi * 2)) * base * 0.05

            ZStack {
                tideBand(
                    size: size,
                    base: base,
                    offsetY: base * 0.15 + verticalShift,
                    colors: [
                        Color(red: 0.8, green: 0.45, blue: 1.0).opacity(0.85),
                        Color(red: 0.25, green: 0.05, blue: 0.5).opacity(0.0)
                    ]
                )

                tideBand(
                    size: size,
                    base: base,
                    offsetY: base * 0.45 - verticalShift * 0.8,
                    colors: [
                        Color(red: 0.35, green: 0.75, blue: 1.0).opacity(0.8),
                        Color(red: 0.05, green: 0.10, blue: 0.30).opacity(0.0)
                    ]
                )

                tideBand(
                    size: size,
                    base: base,
                    offsetY: base * 0.75 + verticalShift * 0.6,
                    colors: [
                        Color(red: 0.9, green: 0.6, blue: 0.9).opacity(0.55),
                        Color(red: 0.20, green: 0.05, blue: 0.25).opacity(0.0)
                    ]
                )
            }
            .offset(x: horizontalShift)
        }
    }

    private func tideBand(
        size: CGSize,
        base: CGFloat,
        offsetY: CGFloat,
        colors: [Color]
    ) -> some View {
        RoundedRectangle(cornerRadius: base * 0.4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size.width * 1.6, height: base * 0.55)
            .position(x: size.width / 2, y: offsetY)
            .blur(radius: base * 0.12)
    }

    @ViewBuilder
    private func shimmerLayer(phase t: Double) -> some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.18),
                Color.white.opacity(0.0)
            ],
            startPoint: UnitPoint(x: 0, y: 0.2 + 0.15 * sin(t * .pi * 2)),
            endPoint: UnitPoint(x: 1, y: 0.4 + 0.15 * cos(t * .pi * 2))
        )
        .blur(radius: 1.5)
    }
}
