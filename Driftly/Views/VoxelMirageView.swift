import SwiftUI

struct VoxelMirageView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        if animationsPaused {
            staticBackground
        } else {
            TimelineView(.animation) { timeline in
                let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                let effectiveSpeed = max(0.25, speed) * (isLowPower ? 0.75 : 1.0)
                let t = timeline.date.timeIntervalSinceReferenceDate * effectiveSpeed

                GeometryReader { proxy in
                    let size = proxy.size

                    Canvas { context, _ in
                        // Lifted background for daytime visibility
                        context.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .linearGradient(
                                Gradient(colors: [
                                    config.palette.backgroundTop.opacity(1.0),
                                    config.palette.backgroundBottom.opacity(0.96)
                                ]),
                                startPoint: .zero,
                                endPoint: CGPoint(x: size.width, y: size.height)
                            )
                        )

                        // Soft bloom overlay
                        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                        context.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .radialGradient(
                                Gradient(colors: [
                                    config.palette.primary.opacity(0.22),
                                    config.palette.secondary.opacity(0.18),
                                    config.palette.tertiary.opacity(0.14),
                                    Color.clear
                                ]),
                                center: center,
                                startRadius: 0,
                                endRadius: max(size.width, size.height) * 1.05
                            )
                        )

                    let cols = isLowPower ? 14 : 18
                    let rows = isLowPower ? 22 : 30
                    let cellW = size.width / CGFloat(cols)
                    let cellH = size.height / CGFloat(rows)
                    let maxDimension = max(size.width, size.height)
                    let octaves = (isLowPower || maxDimension > 1200) ? 3 : 4

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
                                // Brighter voxel visibility
                                let alpha = 0.06 + 0.22 * CGFloat(n - 0.46)

                                context.fill(Path(rect), with: .color(col.opacity(alpha)))
                                if n > 0.78 {
                                    context.fill(Path(rect), with: .color(Color.white.opacity(0.05)))
                                }
                            }
                        }

                        // MARK: - Single moving bright red voxel
                        let window = isLowPower ? 7.0 : 5.0
                        let k0 = Int(floor(t / window))
                        let u = fract(t / window) // 0..1 within the current window

                        // Snap to an existing grid cell (no drifting)
                        let ix = Int(floor(hash01(k0, 991) * Double(cols)))
                        let iy = Int(floor(hash01(k0, 1991) * Double(rows)))

                        let rx = CGFloat(max(0, min(cols - 1, ix))) * cellW
                        let ry = CGFloat(max(0, min(rows - 1, iy))) * cellH

                        // "Pop" right after the jump: quick bloom + slight overscale that decays
                        let pop = 1.0 - smoothstep(min(1.0, u * 3.0)) // strong near u=0, fades by ~0.33

                        let baseRect = CGRect(x: rx, y: ry, width: cellW + 1, height: cellH + 1)

                        // Expand around the cell center for the pop effect
                        let cx = baseRect.midX
                        let cy = baseRect.midY
                        let scale = CGFloat(1.0 + 0.22 * pop)
                        let redRect = CGRect(
                            x: cx - (baseRect.width * 0.5 * scale),
                            y: cy - (baseRect.height * 0.5 * scale),
                            width: baseRect.width * scale,
                            height: baseRect.height * scale
                        )

                        let glowInset = -6.0 - 10.0 * pop
                        let glowRect = redRect.insetBy(dx: glowInset, dy: glowInset)

                        let red = Color(red: 1.00, green: 0.00, blue: 0.10)
                        context.fill(
                            Path(roundedRect: glowRect, cornerRadius: 12),
                            with: .color(red.opacity(0.16 + 0.18 * pop))
                        )
                        context.fill(
                            Path(roundedRect: redRect, cornerRadius: 10),
                            with: .color(red.opacity(0.88))
                        )
                        context.stroke(
                            Path(roundedRect: redRect, cornerRadius: 10),
                            with: .color(Color.white.opacity(0.16 + 0.10 * pop)),
                            lineWidth: 1.0
                        )
                    }
                    .blur(radius: 0.4)
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Helpers

    private var staticBackground: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [
                        config.palette.backgroundTop.opacity(1.0),
                        config.palette.backgroundBottom.opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        config.palette.primary.opacity(0.22),
                        config.palette.secondary.opacity(0.18),
                        config.palette.tertiary.opacity(0.14),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 1.05
                )
                .blendMode(.normal)
            }
            .ignoresSafeArea()
        }
    }

    private func fract(_ x: Double) -> Double { x - floor(x) }

    private func smoothstep(_ x: Double) -> Double {
        let t = max(0.0, min(1.0, x))
        return t * t * (3.0 - 2.0 * t)
    }

    // Deterministic hash -> 0..1
    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Double(n & 0x7fffffff) / 2147483647.0
    }
}
