import SwiftUI

struct VitalWaveView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            ZStack {
                DriftLiquidLampView(
                    palette: config.palette,
                    blobCount: 6,
                    blur: 52,
                    energy: 0.85,
                    speed: speed
                )

                // Soft, premium background glow (breathing + drifting)
                VitalWaveBackgroundGlow(palette: config.palette, t: t)
                    .blendMode(.screen)
                    .opacity(0.70)

                // Vital waveform: smooth most of the time, with occasional spike bursts
                VitalWaveSpikyLine(
                    color: config.palette.secondary,
                    baseAmplitude: 26,
                    spikeAmplitude: 86,
                    period: 10,
                    t: t
                )
                .blendMode(.screen)
                .opacity(0.38)
                .blur(radius: 1.4)

                // Premium random detail: drifting micro-glints
                VitalWaveGlints(
                    primary: config.palette.primary,
                    secondary: config.palette.tertiary,
                    t: t
                )
                .blendMode(.screen)
                .opacity(0.20)
            }
        }
    }
}


// MARK: - Vital Wave Enhancements

private struct VitalWaveBackgroundGlow: View {
    let palette: DriftPalette
    let t: Double

    var body: some View {
        GeometryReader { proxy in
            let s = proxy.size
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.primary.opacity(0.18),
                            palette.secondary.opacity(0.10),
                            palette.tertiary.opacity(0.06),
                            Color.clear
                        ],
                        center: UnitPoint(
                            x: 0.50 + 0.10 * sin(t * 0.05),
                            y: 0.52 + 0.12 * cos(t * 0.04)
                        ),
                        startRadius: 0,
                        endRadius: max(s.width, s.height) * 0.78
                    )
                )
                .ignoresSafeArea()
        }
    }
}

private struct VitalWaveSpikyLine: View {
    let color: Color
    let baseAmplitude: CGFloat
    let spikeAmplitude: CGFloat
    let period: Double
    let t: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            Canvas { context, _ in
                let midY = size.height * 0.52
                let width = size.width

                // Smooth "random" burst + spike position (prevents visible jumps between cycles)
                let window = 7.5
                let cycle0 = Int(floor(t / window))
                let u = fract(t / window) // 0..1 within window
                let s = smoothstep(u)      // smooth crossfade

                // Turn hash into a soft probability (0..1) instead of a hard on/off
                let p0 = smoothstep(0.70, 1.00, hash01(cycle0, 941))
                let p1 = smoothstep(0.70, 1.00, hash01(cycle0 + 1, 941))
                let burstStrength = lerp(p0, p1, s)

                // A gentle envelope that breathes during the window
                let envelope = 0.35 + 0.65 * (0.5 + 0.5 * sin(u * Double.pi * 2.0))
                let burstEnvelope = burstStrength * envelope

                let amp = baseAmplitude
                let spikeAmp = spikeAmplitude * CGFloat(pow(max(0.0, burstEnvelope), 1.6))

                // Smooth spike center across windows too
                let x0 = 0.20 + 0.62 * fract(0.11 * (Double(cycle0) * window) + 0.37 * hash01(cycle0, 177))
                let x1 = 0.20 + 0.62 * fract(0.11 * (Double(cycle0 + 1) * window) + 0.37 * hash01(cycle0 + 1, 177))
                let spikeCenter = lerp(x0, x1, s)

                var path = Path()
                path.move(to: CGPoint(x: 0, y: midY))

                let step: CGFloat = 3
                for x in stride(from: 0, through: width, by: step) {
                    let p = Double(x / max(width, 1))

                    // Base smooth wave
                    let base = sin((t / period + p) * Double.pi * 2.0) * 0.55
                        + cos((t / (period * 1.35) + p * 1.6) * Double.pi * 2.0) * 0.22

                    // Spike pulse: a narrow gaussian-ish bump that slides across
                    let spikeX = spikeCenter
                    let d = (p - spikeX)
                    let bump = exp(-pow(d * 18.0, 2.0))

                    let y = midY - (CGFloat(base) * amp) - (spikeAmp * CGFloat(bump))
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                // Glow underlay
                context.stroke(path, with: .color(color.opacity(0.14)), lineWidth: 10.0)
                context.stroke(path, with: .color(color.opacity(0.18)), lineWidth: 6.0)

                // Core line
                context.stroke(path, with: .color(color.opacity(0.32)), lineWidth: 1.8)
                context.stroke(path, with: .color(Color.white.opacity(0.09)), lineWidth: 0.9)
            }
            .ignoresSafeArea()
        }
    }

    private func fract(_ x: Double) -> Double { x - floor(x) }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    // Clamp then smoothstep
    private func smoothstep(_ x: Double) -> Double {
        let t = max(0.0, min(1.0, x))
        return t * t * (3.0 - 2.0 * t)
    }

    private func smoothstep(_ x: Double, _ y: Double, _ v: Double) -> Double {
        return smoothstep((v - x) / max(0.0001, (y - x)))
    }

    // Deterministic hash to 0..1
    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        let v = Double(n & 0x7fffffff) / 2147483647.0
        return v
    }
}

private struct VitalWaveGlints: View {
    let primary: Color
    let secondary: Color
    let t: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            Canvas { context, _ in
                let count = 90
                let w = max(size.width, 1)
                let h = max(size.height, 1)

                for i in 0..<count {
                    let u = Double(i) * 0.31
                    let x = CGFloat(fract(0.07 * u + 0.012 * t)) * w
                    let y = CGFloat(fract(0.11 * u + 0.009 * t + 0.2)) * h

                    // Occasional twinkle per particle
                    let tw = 0.5 + 0.5 * sin(t * (0.8 + 0.2 * hash01(i, 33)) + u)
                    let r = CGFloat(0.8 + 2.2 * hash01(i, 91))
                    let a = 0.01 + 0.05 * tw

                    let c = (i % 2 == 0) ? primary : secondary
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                        with: .color(c.opacity(a))
                    )
                }
            }
            .ignoresSafeArea()
        }
    }

    private func fract(_ x: Double) -> Double { x - floor(x) }

    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        let v = Double(n & 0x7fffffff) / 2147483647.0
        return v
    }
}
