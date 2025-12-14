import SwiftUI

struct PhotonRainView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        TimelineView(.animation) { timeline in
            let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            let effectiveSpeed = speed * (isLowPower ? 0.75 : 1.0)
            let dropCount = isLowPower ? 56 : 80

            if animationsPaused {
                Color.clear
                    .background(config.palette.backgroundBottom)
                    .ignoresSafeArea()
            } else {
                let t = timeline.date.timeIntervalSinceReferenceDate * effectiveSpeed

                Canvas { context, size in
                    for i in 0..<dropCount {
                        let x = CGFloat(i) / CGFloat(dropCount) * size.width
                        let y = (CGFloat(t * 30 + Double(i * 40))
                                 .truncatingRemainder(dividingBy: size.height))

                        let rect = CGRect(x: x, y: y, width: 1.2, height: 28)
                        context.fill(
                            Path(rect),
                            with: .color(config.palette.primary.opacity(0.35))
                        )
                    }
                }
                .background(config.palette.backgroundBottom)
                .ignoresSafeArea()
            }
        }
    }
}
