import SwiftUI

struct LunarDriftView: View {
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
        .compositingGroup()
    }

    private func normalizedPhase(for date: Date) -> Double {
        let raw = date.timeIntervalSinceReferenceDate * max(speedMultiplier, 0.1)
        let cycle = max(config.cycleDuration, 12)
        let wrapped = raw.truncatingRemainder(dividingBy: cycle)
        return wrapped / cycle // 0...1
    }

    // MARK: - Moon

    @ViewBuilder
    private func moonLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = min(size.width, size.height)

            let verticalDrift = CGFloat(sin(t * .pi * 2)) * base * 0.02
            let subtlePulse = 0.9 + 0.1 * sin(t * .pi * 2)

            ZStack {
                // Halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                config.palette.secondary.opacity(0.6 * subtlePulse),
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

                // Core moon
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
                    .blur(radius: base * 0.01)
            }
        }
    }

    // MARK: - Reflection

    @ViewBuilder
    private func reflectionLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = min(size.width, size.height)

            let wobble = CGFloat(sin(t * .pi * 2)) * base * 0.015

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
                    x: size.width * 0.5 + wobble * 0.2,
                    y: size.height * 0.72 + wobble * 0.35
                )
                .blur(radius: base * 0.18)
        }
    }

    // MARK: - Drift haze

    @ViewBuilder
    private func driftHazeLayer(phase t: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let base = min(size.width, size.height)

            let driftOffset = CGFloat(sin(t * .pi * 2)) * size.width * 0.08

            ZStack {
                RoundedRectangle(cornerRadius: base * 0.4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                config.palette.secondary.opacity(0.18),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size.width * 1.3, height: base * 0.22)
                    .position(
                        x: size.width * 0.5 + driftOffset,
                        y: size.height * 0.5
                    )

                RoundedRectangle(cornerRadius: base * 0.4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                config.palette.tertiary.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .frame(width: size.width * 1.2, height: base * 0.18)
                    .position(
                        x: size.width * 0.5 - driftOffset * 0.6,
                        y: size.height * 0.58
                    )
            }
            .blur(radius: base * 0.15)
        }
    }
}
