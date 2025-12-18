import SwiftUI

struct SpectralLoomView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            SpectralLoomCanvas(config: config, date: date, speed: speed)
        }
    }

    private struct SpectralLoomCanvas: View {
        let config: DriftModeConfig
        let date: Date
        let speed: Double

        var body: some View {
            let s: Double = max(0.25, speed)
            let t: Double = date.timeIntervalSinceReferenceDate * s

            return GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    render(in: context, size: size, t: t)
                }
                .blur(radius: 0.40)
                .ignoresSafeArea()
            }
        }

        private func render(in context: GraphicsContext, size: CGSize, t: Double) {
            let rect = CGRect(origin: .zero, size: size)

            // Lifted background for daytime visibility
            context.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [
                        config.palette.backgroundTop.opacity(1.0),
                        config.palette.backgroundBottom.opacity(0.97)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            // Gentle vignette for perceived depth (keeps daytime visibility)
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            context.fill(
                Path(rect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.black.opacity(0.10),
                        Color.black.opacity(0.04),
                        Color.clear
                    ]),
                    center: center,
                    startRadius: min(size.width, size.height) * 0.15,
                    endRadius: max(size.width, size.height) * 0.85
                )
            )

            // Soft bloom overlay to brighten the scene while staying ambient
            context.fill(
                Path(rect),
                with: .radialGradient(
                    Gradient(colors: [
                        config.palette.primary.opacity(0.22),
                        config.palette.secondary.opacity(0.18),
                        config.palette.tertiary.opacity(0.14),
                        Color.clear
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 1.10
                )
            )

            // Adaptive strand count (keeps the look consistent across iPhone/iPad/tvOS)
            let strands: Int = min(120, max(56, Int(size.width / 12)))
            let step: Double = max(10.0, min(14.0, Double(size.height) / 120.0))

            // Strands look best with additive blending, but keep opacities conservative.
            var glow = context
            glow.blendMode = .plusLighter

            // Two depth layers: a softer back layer + a crisper front layer.
            for layer in 0..<2 {
                let depth: Double = (layer == 0) ? 0.72 : 1.0
                let layerSpeed: Double = (layer == 0) ? 0.80 : 1.0
                let layerPhase: Double = (layer == 0) ? 1.7 : 0.0
                let lineScale: Double = (layer == 0) ? 0.85 : 1.0
                let opacityScale: Double = (layer == 0) ? 0.78 : 1.0

                for i in 0..<strands {
                    let p: Double = Double(i) / Double(max(1, strands - 1))
                    let xBase: CGFloat = CGFloat(p) * size.width

                    // Slow global drift so the weave feels alive, not jittery.
                    let drift: CGFloat = CGFloat(sin(t * 0.06 * layerSpeed + p * 2.0 + layerPhase)) * size.width * 0.02

                    var path = Path()
                    path.move(to: CGPoint(x: xBase + drift, y: -32))

                    for y in stride(from: 0.0, through: Double(size.height) + 44.0, by: step) {
                        let yy: CGFloat = CGFloat(y)
                        let bend: Double =
                            (18.0 * depth) * sin(Double(yy) * 0.010 + t * 0.22 * layerSpeed + p * 6.0 + layerPhase) +
                            (8.0 * depth)  * cos(Double(yy) * 0.020 + t * 0.11 * layerSpeed + p * 8.0 + layerPhase)

                        path.addLine(to: CGPoint(x: xBase + drift + CGFloat(bend), y: yy))
                    }

                    let col: Color = strandColor(index: i, p: p, time: t)

                    // Luminous strand (layered glow -> crisp core)
                    glow.stroke(path, with: .color(col.opacity(0.16 * opacityScale)), lineWidth: CGFloat(9.0 * lineScale))
                    glow.stroke(path, with: .color(col.opacity(0.28 * opacityScale)), lineWidth: CGFloat(4.8 * lineScale))
                    glow.stroke(path, with: .color(col.opacity(0.46 * opacityScale)), lineWidth: CGFloat(2.1 * lineScale))
                    glow.stroke(path, with: .color(Color.white.opacity(0.12 * opacityScale)), lineWidth: CGFloat(1.0 * lineScale))
                }
            }

            // Animated glow sweep (subtle, adds depth)
            let sweepX: CGFloat = (size.width * 0.5) + CGFloat(sin(t * 0.12)) * size.width * 0.42
            let sweepRect = CGRect(x: sweepX - 170, y: 0, width: 340, height: size.height)
            context.fill(
                Path(sweepRect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.00),
                        Color.white.opacity(0.055),
                        Color.white.opacity(0.00)
                    ]),
                    startPoint: CGPoint(x: sweepRect.minX, y: 0),
                    endPoint: CGPoint(x: sweepRect.maxX, y: 0)
                )
            )
        }

        private func strandColor(index i: Int, p: Double, time t: Double) -> Color {
            // Gentle time-based vibe by modulating accent opacity (keeps palette identity)
            let wobble = 0.5 + 0.5 * sin(t * 0.08 + p * 3.0)

            // Accent strands (fun, still premium)
            if i % 13 == 0 { return Color(red: 1.00, green: 0.36, blue: 0.90).opacity(0.85 + 0.15 * wobble) } // hot pink
            if i % 19 == 0 { return Color(red: 1.00, green: 0.80, blue: 0.34).opacity(0.80 + 0.20 * wobble) } // warm yellow
            if i % 29 == 0 { return Color(red: 0.40, green: 0.84, blue: 1.00).opacity(0.82 + 0.18 * wobble) } // cyan

            switch i % 3 {
            case 0: return config.palette.primary
            case 1: return config.palette.secondary
            default: return config.palette.tertiary
            }
        }
    }
}
