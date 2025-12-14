import SwiftUI

struct VoxelMirageView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        TimelineView(.animation) { timeline in
            let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            let effectiveSpeed = max(0.25, speed) * (isLowPower ? 0.75 : 1.0)
            let t = timeline.date.timeIntervalSinceReferenceDate * effectiveSpeed

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: size.height)
                        )
                    )

                    guard !animationsPaused else { return }

                    let cols = isLowPower ? 14 : 18
                    let rows = isLowPower ? 22 : 30
                    let cellW = size.width / CGFloat(cols)
                    let cellH = size.height / CGFloat(rows)
                    let octaves = isLowPower ? 3 : 4

                    for y in 0..<rows {
                        for x in 0..<cols {
                            let nx = Double(x) / Double(cols)
                            let ny = Double(y) / Double(rows)
                            let n = DriftNoise.fbm(
                                x: nx * 2.0 + t * 0.02,
                                y: ny * 2.5 + t * 0.02,
                                seed: 77,
                                octaves: octaves
                            )

                            if n < 0.46 { continue }

                            let rect = CGRect(
                                x: CGFloat(x) * cellW,
                                y: CGFloat(y) * cellH,
                                width: cellW + 1,
                                height: cellH + 1
                            )

                            let pick = (x + y) % 3
                            let col: Color = pick == 0 ? config.palette.primary : (pick == 1 ? config.palette.secondary : config.palette.tertiary)
                            let alpha = 0.03 + 0.10 * CGFloat(n - 0.46)

                            context.fill(Path(rect), with: .color(col.opacity(alpha)))
                        }
                    }
                }
                .blur(radius: 0.6)
            }
            .ignoresSafeArea()
        }
    }
}
