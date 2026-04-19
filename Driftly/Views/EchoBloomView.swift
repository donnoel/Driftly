import SwiftUI

struct EchoBloomView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        ZStack {
            DriftLiquidLampView(
                palette: config.palette,
                blobCount: 4,
                blur: 60,
                energy: 0.60,
                speed: speed
            )

            HorizonWaveGlowOverlay(palette: config.palette, speed: speed)
        }
    }
}

// MARK: - Horizon + Waves (Echo Bloom)

private struct HorizonWaveGlowOverlay: View {
    let palette: DriftPalette
    let speed: Double

    var body: some View {
        HorizonWaveGlowTimeline(palette: palette, speed: speed)
            .compositingGroup()
            .blur(radius: 0.55)
            .blendMode(.screen)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

}

private struct HorizonWaveGlowTimeline: View {
    let palette: DriftPalette
    let speed: Double
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let raw: Double = date.timeIntervalSinceReferenceDate
            let speedFactor: Double = max(0.25, speed) * 0.075
            let t: Double = raw * speedFactor
            HorizonWaveGlowCanvas(palette: palette, t: t)
        }
    }
}

private struct HorizonWaveGlowCanvas: View {
    let palette: DriftPalette
    let t: Double

    var body: some View {
        Canvas { context, size in
            let horizonY = size.height * 0.58

            // Warm horizon glow (deep red -> ember -> rose)
            let deepRed = Color(red: 0.85, green: 0.06, blue: 0.22)
            let ember = Color(red: 1.00, green: 0.36, blue: 0.18)
            let rose = Color(red: 1.00, green: 0.20, blue: 0.62)

            drawGlowBand(in: &context, size: size, horizonY: horizonY, deepRed: deepRed, ember: ember, rose: rose)
            drawHorizonLine(in: &context, size: size, horizonY: horizonY, deepRed: deepRed, ember: ember, rose: rose)
            drawWaveBands(in: &context, size: size, horizonY: horizonY, t: t, deepRed: deepRed, ember: ember, rose: rose)
            drawSparkles(in: &context, size: size, horizonY: horizonY, t: t, ember: ember, rose: rose)
        }
    }

    private func drawGlowBand(
        in context: inout GraphicsContext,
        size: CGSize,
        horizonY: CGFloat,
        deepRed: Color,
        ember: Color,
        rose: Color
    ) {
        let glowRect = CGRect(
            x: 0,
            y: horizonY - size.height * 0.28,
            width: size.width,
            height: size.height * 0.56
        )

        let grad = Gradient(colors: [
            Color.clear,
            deepRed.opacity(0.10),
            ember.opacity(0.12),
            rose.opacity(0.08),
            Color.clear
        ])

        context.fill(
            Path(glowRect),
            with: .linearGradient(
                grad,
                startPoint: CGPoint(x: 0, y: glowRect.minY),
                endPoint: CGPoint(x: 0, y: glowRect.maxY)
            )
        )
    }

    private func drawHorizonLine(
        in context: inout GraphicsContext,
        size: CGSize,
        horizonY: CGFloat,
        deepRed: Color,
        ember: Color,
        rose: Color
    ) {
        let breath = 0.5 + 0.5 * sin(t * 0.55)
        let lineRect = CGRect(x: -20, y: horizonY - 1.0, width: size.width + 40, height: 2.0)

        let grad = Gradient(colors: [
            rose.opacity(0.05),
            ember.opacity(0.18 + 0.10 * breath),
            deepRed.opacity(0.10)
        ])

        context.fill(
            Path(lineRect),
            with: .linearGradient(
                grad,
                startPoint: CGPoint(x: 0, y: horizonY),
                endPoint: CGPoint(x: size.width, y: horizonY)
            )
        )
    }

    private func drawWaveBands(
        in context: inout GraphicsContext,
        size: CGSize,
        horizonY: CGFloat,
        t: Double,
        deepRed: Color,
        ember: Color,
        rose: Color
    ) {
        let waveBands = 9
        let steps = 180

        for b in 0..<waveBands {
            let p = Double(b) / Double(max(1, waveBands - 1))

            let path = wavePath(
                bandIndex: b,
                bands: waveBands,
                steps: steps,
                size: size,
                horizonY: horizonY,
                t: t
            )

            let bandCol: Color = {
                if b == 0 { return ember }
                if b == 1 { return rose }
                return deepRed
            }()

            let aCore = 0.09 + 0.10 * (1.0 - p)
            let aGlow = 0.05 + 0.06 * (1.0 - p)

            context.stroke(path, with: .color(bandCol.opacity(aGlow)), lineWidth: 10.0 + 10.0 * p)
            context.stroke(path, with: .color(bandCol.opacity(aCore)), lineWidth: 2.4 + 1.4 * p)
            context.stroke(path, with: .color(Color.white.opacity(0.04 + 0.04 * (1.0 - p))), lineWidth: 1.0)
        }
    }

    private func wavePath(
        bandIndex b: Int,
        bands: Int,
        steps: Int,
        size: CGSize,
        horizonY: CGFloat,
        t: Double
    ) -> Path {
        let p = Double(b) / Double(max(1, bands - 1))
        let yBase = horizonY + CGFloat(p) * (size.height * 0.42)
        let amp = (10.0 + 26.0 * p) * (0.65 + 0.35 * (0.5 + 0.5 * sin(t * 0.22 + p * 3.0)))

        let f1 = 1.2 + 1.6 * p
        let f2 = 2.1 + 2.8 * (1.0 - p)
        let sp1 = 0.55 + 0.25 * p
        let sp2 = 0.40 + 0.20 * (1.0 - p)

        var path = Path()
        for s in 0...steps {
            let u = Double(s) / Double(steps)
            let x = CGFloat(u) * size.width

            let w1 = sin((u * Double.pi * 2.0 * f1) + t * sp1 + p * 2.2)
            let w2 = cos((u * Double.pi * 2.0 * f2) - t * sp2 + p * 1.4)
            let w = 0.72 * w1 + 0.28 * w2

            let skew = 0.18 * sin(t * 0.10 + u * 4.0)
            let y = yBase + CGFloat(w) * CGFloat(amp) + CGFloat(skew) * CGFloat(amp) * 0.18

            if s == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }

    private func drawSparkles(
        in context: inout GraphicsContext,
        size: CGSize,
        horizonY: CGFloat,
        t: Double,
        ember: Color,
        rose: Color
    ) {
        let sparkleCount = Int((size.width * size.height / 60_000).clamped(to: 18...54))

        for i in 0..<sparkleCount {
            let r1 = hash01(i, 911)
            let r2 = hash01(i, 947)
            let r3 = hash01(i, 971)

            let x = CGFloat(r1) * size.width
            let y = horizonY - 60 + CGFloat(r2) * 140
            let tw = 0.5 + 0.5 * sin(t * (0.35 + 0.55 * r3) + Double(i) * 1.1)
            let s = 0.8 + 2.6 * r3
            let a = (0.015 + 0.05 * tw) * (0.5 + 0.5 * r3)

            let col = (i % 3 == 0) ? ember : ((i % 3 == 1) ? rose : Color.white)
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                with: .color(col.opacity(a))
            )
        }
    }

    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Double(n & 0x7fffffff) / 2147483647.0
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
