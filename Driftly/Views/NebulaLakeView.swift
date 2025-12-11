import SwiftUI

struct NebulaLakeView: View {
    // 40s cycle, matching your spec
    private let cycleDuration: TimeInterval = 40

    var body: some View {
        TimelineView(.animation) { context in
            let t = normalizedPhase(for: context.date)

            ZStack {
                // Deep background
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.03, blue: 0.09),
                        Color(red: 0.03, green: 0.05, blue: 0.16),
                        Color(red: 0.01, green: 0.02, blue: 0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(0.98)

                // Soft nebula blobs
                nebulaLayer(phase: t)
                    .blendMode(.screen)
                    .opacity(0.95)

                // Subtle star dust
                starDustLayer(phase: t)
                    .blendMode(.screen)
                    .opacity(0.45)
            }
            .compositingGroup()
        }
    }

    private func normalizedPhase(for date: Date) -> Double {
        let raw = date.timeIntervalSinceReferenceDate
        let wrapped = raw.truncatingRemainder(dividingBy: cycleDuration)
        return wrapped / cycleDuration // 0...1
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
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.15, green: 0.8, blue: 0.85).opacity(0.9),
                                Color(red: 0.05, green: 0.15, blue: 0.25).opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: base * 0.9
                        )
                    )
                    .frame(width: base * 1.4, height: base * 1.4)
                    .position(offset1)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.6, green: 0.35, blue: 1.0).opacity(0.9),
                                Color(red: 0.15, green: 0.05, blue: 0.3).opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: base * 1.1
                        )
                    )
                    .frame(width: base * 1.7, height: base * 1.7)
                    .position(offset2)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.55),
                                Color(red: 0.15, green: 0.2, blue: 0.4).opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: base * 0.8
                        )
                    )
                    .frame(width: base * 1.1, height: base * 1.1)
                    .position(offset3)
                    .blur(radius: base * 0.08)
            }
        }
    }

    @ViewBuilder
    private func starDustLayer(phase t: Double) -> some View {
        // Super-cheap faux stardust: layered gradients that slowly drift
        RadialGradient(
            colors: [
                Color.white.opacity(0.22),
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
                    Color.white.opacity(0.15),
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
        .overlay(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.4)
        )
        .blur(radius: 1.0)
    }
}
