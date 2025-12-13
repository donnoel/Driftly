import SwiftUI

struct DriftLiquidLampView: View {
    let palette: DriftPalette
    let blobCount: Int
    let blur: CGFloat
    let energy: Double
    let speed: Double

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * max(0.25, speed) * 0.18

            GeometryReader { proxy in
                let size = proxy.size

                ZStack {
                    LinearGradient(
                        colors: [palette.backgroundTop, palette.backgroundBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    // Liquid blobs
                    ForEach(0..<blobCount, id: \.self) { i in
                        blob(i: i, t: t, in: size)
                            .blendMode(.screen)
                            .blur(radius: blur)
                            .opacity(0.95)
                    }

                    // Soft “milk” wash to unify
                    Rectangle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.00)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 520
                            )
                        )
                        .blendMode(.overlay)
                        .ignoresSafeArea()
                }
                .compositingGroup()
            }
        }
    }

    private func blob(i: Int, t: Double, in size: CGSize) -> some View {
        let phase = Double(i) * 1.7
        let wobble = (sin(t + phase) + cos(t * 0.9 + phase * 0.7)) * 0.5

        // Position
        let x = 0.5 + 0.28 * sin(t * (0.6 + 0.04 * Double(i)) + phase)
        let y = 0.5 + 0.24 * cos(t * (0.55 + 0.03 * Double(i)) + phase * 1.1)

        // Size
        let base = 260.0 + 42.0 * Double(i % 3)
        let blobSize = base * (0.86 + 0.18 * (0.5 + 0.5 * sin(t * 0.7 + phase)))

        // Color pick
        let c: Color = {
            switch i % 3 {
            case 0: return palette.primary
            case 1: return palette.secondary
            default: return palette.tertiary
            }
        }()

        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        c.opacity(0.95),
                        c.opacity(0.15),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: blobSize * 0.62
                )
            )
            .scaleEffect(0.85 + CGFloat(0.25 * energy) * CGFloat(0.5 + 0.5 * wobble))
            .position(
                x: CGFloat(x) * size.width,
                y: CGFloat(y) * size.height
            )
    }
}
