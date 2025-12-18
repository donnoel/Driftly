import SwiftUI

struct DriftGridView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        if animationsPaused {
            scene(raw: 0)
        } else {
            TimelineView(.animation) { timeline in
                scene(raw: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    // MARK: - Helpers

    private func scene(raw: Double) -> some View {
        let s = max(0.25, speed)
        let t = raw * s * 0.15

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
            let k0 = Int(floor(raw / window))
            let u = (raw / window) - floor(raw / window) // 0..1
            let fade = smoothstep(u)

            let i0 = hash01(k0, 911) * Double(lineCount - 2)
            let i1 = hash01(k0 + 1, 911) * Double(lineCount - 2)
            let laneF = lerp(i0, i1, fade) // continuous (no snapping)

            // Move down the screen smoothly; fade near wrap so the reset is invisible
            let travel = Double(size.height + 120)
            let v = (raw * 14.0 / max(1.0, travel))
            let vf = v - floor(v) // 0..1
            let y = CGFloat(vf * travel) - 60
            let bob = CGFloat(18 * sin(raw * 0.7 + laneF))

            // Fade in/out near the wrap point to hide the single-frame jump
            let edge = min(vf, 1.0 - vf) * 2.0 // 0 at edges, 1 mid
            let orbFade = smoothstep(edge)

            // Interpolate between adjacent lines (back and forth), but keep position continuous
            let between = 0.5 + 0.5 * sin(raw * 0.6 + laneF * 0.4)
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

            let pulse = 0.5 + 0.5 * sin(raw * 1.05 + laneF * 0.35)
            let sizePulse = CGFloat(0.85 + 0.45 * pulse) // 0.85..1.30

            let r: CGFloat = 12 * sizePulse
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
