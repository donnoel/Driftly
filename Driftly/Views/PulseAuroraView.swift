import SwiftUI

struct PulseAuroraView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        ZStack {
            DriftLiquidLampView(
                palette: config.palette,
                blobCount: 7,
                blur: 64,
                energy: 0.48,
                speed: speed * 0.55
            )

            SleepingCatsOverlay(palette: config.palette, speed: speed)
        }
    }
}

// MARK: - Sleeping Cats Overlay

private struct SleepingCatsOverlay: View {
    let palette: DriftPalette
    let speed: Double
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let raw = date.timeIntervalSinceReferenceDate
            let t = raw * max(0.25, speed) * 0.06 // very slow

            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

                // Soft breath glow (like a sleepy room)
                let breath = 0.5 + 0.5 * sin(t * 0.85)
                context.fill(
                    Path(rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            palette.secondary.opacity(0.08 + 0.06 * breath),
                            palette.primary.opacity(0.05 + 0.04 * breath),
                            Color.clear
                        ]),
                        center: center,
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 0.85
                    )
                )

                // A few soft "pillow" shapes that drift like sleeping cats
                let count = 5
                for i in 0..<count {
                    let r1 = hash01(i, 31)
                    let r2 = hash01(i, 67)
                    let r3 = hash01(i, 101)

                    let baseX = size.width * (0.18 + 0.64 * CGFloat(r1))
                    let baseY = size.height * (0.22 + 0.56 * CGFloat(r2))

                    // Very slow drift; each one has its own lazy path
                    let dx = CGFloat(18.0 * sin(t * (0.18 + 0.06 * r2) + Double(i) * 1.1))
                    let dy = CGFloat(14.0 * cos(t * (0.16 + 0.05 * r1) + Double(i) * 0.9))

                    // Gentle purr pulse (slower than breath, slight phase offsets)
                    let purr = 0.5 + 0.5 * sin(t * (1.00 + 0.15 * r3) + Double(i) * 0.7)

                    let w = min(size.width, size.height) * (0.32 + 0.10 * CGFloat(r2))
                    let h = w * (0.58 + 0.18 * CGFloat(r3))

                    // Slight squash/stretch like slow breathing
                    let sx = 1.0 + 0.05 * CGFloat(purr)
                    let sy = 1.0 - 0.04 * CGFloat(purr)

                    let cx = baseX + dx
                    let cy = baseY + dy

                    let blobRect = CGRect(
                        x: cx - (w * 0.5 * sx),
                        y: cy - (h * 0.5 * sy),
                        width: w * sx,
                        height: h * sy
                    )

                    let col: Color = {
                        // Softer bedtime palette — mostly cool, with rare warm accents
                        if i == 0 { return palette.tertiary }
                        if i == 3 { return palette.secondary }
                        return palette.primary
                    }()

                    // Layered softness: glow -> body -> highlight
                    context.fill(Path(ellipseIn: blobRect.insetBy(dx: -18, dy: -18)),
                                 with: .color(col.opacity(0.05 + 0.06 * Double(purr))))
                    context.fill(Path(ellipseIn: blobRect),
                                 with: .color(col.opacity(0.06 + 0.08 * Double(purr))))

                    // Tiny highlight crescent to imply plush depth
                    let hi = blobRect.insetBy(dx: w * 0.22, dy: h * 0.22)
                    let cres = Path(ellipseIn: CGRect(x: hi.minX, y: hi.minY, width: hi.width * 0.65, height: hi.height * 0.55))
                    context.fill(cres, with: .color(Color.white.opacity(0.03 + 0.03 * Double(purr))))
                }

                // A few tiny sparkles that fade in/out slowly (quiet night vibes)
                let sparkleCount = 24
                for i in 0..<sparkleCount {
                    let r1 = hash01(i, 401)
                    let r2 = hash01(i, 433)
                    let r3 = hash01(i, 467)

                    let x = CGFloat(r1) * size.width
                    let y = CGFloat(r2) * size.height

                    let tw = 0.5 + 0.5 * sin(t * (0.45 + 0.35 * r3) + Double(i) * 0.9)
                    let a = (r3 > 0.82) ? (0.02 + 0.06 * tw) : (0.008 + 0.02 * tw)

                    let s = 0.8 + 2.2 * r3
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                                 with: .color(Color.white.opacity(a)))
                }
            }
        }
        .compositingGroup()
        .blur(radius: 0.45)
        .blendMode(.screen)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Double(n & 0x7fffffff) / 2147483647.0
    }
}
