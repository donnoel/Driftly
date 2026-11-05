import SwiftUI

struct DriftGridView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            scene(raw: date.timeIntervalSinceReferenceDate)
        }
    }

    // MARK: - Helpers

    private func scene(raw: Double) -> some View {
        let s = max(0.25, speed)
        let t = raw * s * 0.15
        let playTime = raw * s

        return Canvas { context, size in
            // Brighter backdrop (still ambient)
            let bgRect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(bgRect),
                with: .linearGradient(
                    Gradient(colors: [
                        config.palette.backgroundTop.opacity(0.98),
                        config.palette.backgroundBottom.opacity(0.92)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            let step: CGFloat = 44
            let lineCount = max(2, Int(ceil(size.width / step)) + 1)

            // Subtle global brightness lift for the grid
            let baseAlpha: Double = 0.22

            // Draw lines with occasional color variation
            for i in 0..<lineCount {
                let x = CGFloat(i) * step

                // More movement: bend the line with a y-dependent wave (no longer just a straight segment)
                let phase = Double(i) * 0.55
                let drift = 8.0 * sin(t * 0.18 + phase * 0.7)

                // Two wave components so it feels organic (like a soft current through a grid)
                let wA = 12.0
                let wB = 7.0
                let fA = 1.05
                let fB = 0.72

                var path = Path()
                let segments = 14
                for s in 0...segments {
                    let u = CGFloat(s) / CGFloat(segments) // 0..1 down the screen
                    let y = size.height * u

                    // Wave varies with y so the line actually bends
                    let wyA = sin((t * fA) + Double(u) * 6.0 + phase)
                    let wyB = cos((t * fB) + Double(u) * 10.0 + phase * 0.8)
                    let offset = drift + (wA * wyA) + (wB * wyB)

                    let pt = CGPoint(x: x + CGFloat(offset), y: y)
                    if s == 0 {
                        path.move(to: pt)
                    } else {
                        path.addLine(to: pt)
                    }
                }

                // Choose a color lane pattern (mostly primary, some secondary/tertiary, plus accents)
                let laneKind = (i % 9)
                let col: Color
                switch laneKind {
                case 2, 7:
                    col = config.palette.secondary
                case 4:
                    col = config.palette.tertiary
                case 1, 8:
                    col = Color(red: 1.00, green: 0.26, blue: 0.38) // red accent
                case 3:
                    col = Color(red: 1.00, green: 0.88, blue: 0.34) // yellow accent
                case 5:
                    col = Color(red: 1.00, green: 0.40, blue: 0.82) // pink accent
                default:
                    col = config.palette.primary
                }

                // Slight per-line opacity modulation so the grid reads better
                let a = baseAlpha + 0.10 * (0.5 + 0.5 * sin(t * 0.35 + Double(i) * 0.8))

                // Layered stroke for a nicer glow/contrast
                context.stroke(path, with: .color(col.opacity(a * 0.55)), lineWidth: 2.0)
                context.stroke(path, with: .color(col.opacity(a)), lineWidth: 0.9)
                context.stroke(path, with: .color(Color.white.opacity(0.06)), lineWidth: 0.6)
            }

            // MARK: - Glowing orb traveling between two adjacent lines

            // Pick a changing pair of adjacent lines every ~6 seconds (deterministic but feels random)
            let window = 6.0
            let k0 = Int(floor(playTime / window))
            let u = (playTime / window) - floor(playTime / window) // 0..1
            let fade = smoothstep(u)

            let i0 = hash01(k0, 911) * Double(lineCount - 2)
            let i1 = hash01(k0 + 1, 911) * Double(lineCount - 2)
            let laneF = lerp(i0, i1, fade) // continuous (no snapping)

            // Move down the screen smoothly; fade near wrap so the reset is invisible
            let travel = Double(size.height + 120)
            let v = (playTime * 14.0 / max(1.0, travel)) + 0.42
            let vf = v - floor(v) // 0..1
            let y = CGFloat(vf * travel) - 60
            let bob = CGFloat(18 * sin(playTime * 0.7 + laneF))

            // Fade in/out near the wrap point to hide the single-frame jump
            let edge = min(vf, 1.0 - vf) * 2.0 // 0 at edges, 1 mid
            let orbFade = smoothstep(edge)

            // Interpolate between adjacent lines (back and forth), but keep position continuous
            let between = 0.5 + 0.5 * sin(playTime * 0.6 + laneF * 0.4)
            let x = (CGFloat(laneF) + CGFloat(between)) * step

            // Make it follow the line wave a bit so it feels attached to the grid
            let attachWave = CGFloat(10.0 * sin(t * 0.9 + laneF * 0.55)
                + 6.0 * cos(t * 0.6 + laneF * 0.33))

            let xClamped = min(max(x, 0), CGFloat(lineCount - 1) * step)
            let center = CGPoint(x: xClamped + attachWave * 0.55, y: y + bob)

            let laneI = Int(floor(laneF))
            let orbColor: Color = {
                switch (k0 + laneI) % 4 {
                case 0: return config.palette.secondary
                case 1: return config.palette.tertiary
                case 2: return config.palette.primary
                default: return Color.white
                }
            }()

            let pulse = 0.5 + 0.5 * sin(playTime * 1.05 + laneF * 0.35)
            let sizePulse = CGFloat(0.85 + 0.45 * pulse) // 0.85..1.30

            let r: CGFloat = 12 * sizePulse
            if !reduceMotion {
                drawCompanion(in: context, size: size, time: playTime, gridTime: t,
                              leader: center, radius: r, fade: orbFade, step: step, lineCount: lineCount)
            }
            let glowR: CGFloat = 56 * (0.90 + 0.35 * sizePulse)
            let glow = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [
                    orbColor.opacity((0.24) * orbFade),
                    orbColor.opacity((0.10) * orbFade),
                    Color.clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: glowR
            )

            context.fill(Path(ellipseIn: CGRect(x: center.x - glowR, y: center.y - glowR, width: glowR * 2, height: glowR * 2)), with: glow)
            context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(orbColor.opacity(0.35 * orbFade)))
            context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(Color.white.opacity(0.12 * orbFade)), lineWidth: 1.0)
        }
        .ignoresSafeArea()
    }

    /// A warmer, smaller companion trades places with the cool orb, then ducks into a strand.
    private func drawCompanion(
        in context: GraphicsContext,
        size: CGSize,
        time: Double,
        gridTime: Double,
        leader: CGPoint,
        radius: CGFloat,
        fade: Double,
        step: CGFloat,
        lineCount: Int
    ) {
        let phase = time * 0.32
        let hiding = pow(max(0, sin(phase * 0.65)), 6)
        let margin: CGFloat = 24
        let base = min(size.width, size.height)
        let reach = base * CGFloat(0.10 + 0.23 * (0.5 + 0.5 * sin(phase * 0.43)))
        let playX = leader.x + reach * CGFloat(cos(phase))
        let y = leader.y + reach * CGFloat(0.78 * sin(phase) + 0.12 * sin(phase * 0.7))
        // Ease between hiding strands at their midpoint, keeping the path continuous.
        let lanePosition = min(Double(lineCount - 1), max(0, Double(playX / step)))
        let laneBase = floor(lanePosition)
        let lane = laneBase + smoothstep((lanePosition - laneBase - 0.35) / 0.30)
        let lanePhase = lane * 0.55
        let heightFraction = Double(y / max(1, size.height))
        let strandX = CGFloat(lane) * step + CGFloat(
            8 * sin(gridTime * 0.18 + lanePhase * 0.7)
            + 12 * sin(gridTime * 1.05 + heightFraction * 6 + lanePhase)
            + 7 * cos(gridTime * 0.72 + heightFraction * 10 + lanePhase * 0.8)
        )
        let x = playX + (strandX - playX) * CGFloat(hiding * 0.55)
        // A soft boundary keeps the wide orbit on screen without hitting a hard edge stop.
        let halfWidth = max(1, size.width * 0.5 - margin)
        let boundedX = size.width * 0.5 + halfWidth * CGFloat(tanh(Double((x - size.width * 0.5) / halfWidth)))
        let center = CGPoint(x: boundedX, y: y)
        let visibility = fade * (1 - 0.72 * hiding)
        let r = radius * CGFloat(0.98 - 0.18 * hiding)
        let color = Color(red: 1.0, green: 0.51, blue: 0.43)
        let glowRadius = r * 4.5

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - glowRadius, y: center.y - glowRadius,
                                  width: glowRadius * 2, height: glowRadius * 2)),
            with: .radialGradient(
                Gradient(colors: [color.opacity(0.20 * visibility), color.opacity(0.05 * visibility), .clear]),
                center: center, startRadius: 0, endRadius: glowRadius
            )
        )
        // Five soft petals give the companion a silhouette of her own.
        var flower = Path()
        let turn = time * 0.18 + 0.15 * sin(phase)
        for point in 0...50 {
            let angle = Double(point) * .pi * 2 / 50
            let petalRadius = r * CGFloat(0.85 + 0.23 * cos(angle * 5))
            let position = CGPoint(x: center.x + petalRadius * CGFloat(cos(angle + turn)),
                                   y: center.y + petalRadius * CGFloat(sin(angle + turn)))
            if point == 0 { flower.move(to: position) } else { flower.addLine(to: position) }
        }
        flower.closeSubpath()
        context.fill(flower, with: .radialGradient(
            Gradient(colors: [Color(red: 1, green: 0.84, blue: 0.65).opacity(0.62 * visibility),
                              color.opacity(0.46 * visibility), color.opacity(0.12 * visibility)]),
            center: CGPoint(x: center.x - r * 0.3, y: center.y - r * 0.35),
            startRadius: 0, endRadius: r * 1.6
        ))
        context.stroke(flower, with: .color(color.opacity(0.30 * visibility)), lineWidth: 0.8)
        let pearl = CGRect(x: center.x - r * 0.36, y: center.y - r * 0.36, width: r * 0.72, height: r * 0.72)
        context.fill(Path(ellipseIn: pearl), with: .color(Color(red: 1, green: 0.88, blue: 0.74).opacity(0.48 * visibility)))
        var ribbon = Path()
        ribbon.move(to: CGPoint(x: center.x - r * 0.7, y: center.y + r * 0.45))
        ribbon.addCurve(to: CGPoint(x: center.x - r * 2.1, y: center.y + r * CGFloat(0.7 + 0.3 * sin(phase))),
                        control1: CGPoint(x: center.x - r, y: center.y + r * 1.5),
                        control2: CGPoint(x: center.x - r * 1.6, y: center.y - r * 0.1))
        context.stroke(ribbon, with: .color(color.opacity(0.35 * visibility)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    private func smoothstep(_ x: Double) -> Double {
        let t = max(0.0, min(1.0, x))
        return t * t * (3.0 - 2.0 * t)
    }

    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Double(n & 0x7fffffff) / 2147483647.0
    }
}
