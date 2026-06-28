import SwiftUI

struct CausticSilkView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    render(in: context, size: size, time: t)
                }
                .ignoresSafeArea()
            }
        }
    }

    private func render(in context: GraphicsContext, size: CGSize, time t: Double) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.tertiary.opacity(0.14),
                    config.palette.primary.opacity(0.08),
                    Color.clear
                ]),
                center: CGPoint(x: size.width * 0.48, y: size.height * 0.45),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.95
            )
        )

        var glow = context
        glow.blendMode = .plusLighter

        drawCausticCells(
            in: &glow,
            size: size,
            time: t,
            count: lineCount(for: size, divisor: 46, minimum: 24, maximum: 42)
        )
        drawCausticFamily(
            in: &glow,
            size: size,
            time: t,
            family: 2,
            count: lineCount(for: size, divisor: 94, minimum: 5, maximum: 10)
        )

        drawGlints(in: &glow, size: size, time: t)
        drawVignette(in: context, size: size)
    }

    private func drawCausticCells(
        in context: inout GraphicsContext,
        size: CGSize,
        time t: Double,
        count: Int
    ) {
        let base = min(size.width, size.height)

        for index in 0..<count {
            let rx = DriftNoise.hash(index, 7, seed: 1200)
            let ry = DriftNoise.hash(index, 11, seed: 1200)
            let phase = Double(index) * 0.83
            let center = CGPoint(
                x: size.width * CGFloat(rx) + CGFloat(20.0 * sin(t * 0.035 + phase)),
                y: size.height * CGFloat(ry) + CGFloat(24.0 * cos(t * 0.030 + phase * 1.2))
            )
            let width = base * CGFloat(0.12 + 0.18 * DriftNoise.hash(index, 19, seed: 1200))
            let height = width * CGFloat(0.12 + 0.16 * DriftNoise.hash(index, 23, seed: 1200))
            let angle = CGFloat(Double.pi * DriftNoise.hash(index, 31, seed: 1200) + t * 0.018)
            let pulse = 0.5 + 0.5 * sin(t * 0.20 + phase)

            var cell = Path(ellipseIn: CGRect(
                x: -width * 0.5,
                y: -height * 0.5,
                width: width,
                height: height
            ))
            cell = cell.applying(
                CGAffineTransform(translationX: center.x, y: center.y)
                    .rotated(by: angle)
            )

            let color = causticColor(index: index, family: 0)
            context.stroke(cell, with: .color(color.opacity(0.05 + 0.08 * pulse)), lineWidth: 7.0)
            context.stroke(cell, with: .color(color.opacity(0.12 + 0.12 * pulse)), lineWidth: 2.0)
            context.stroke(cell, with: .color(Color.white.opacity(0.035 + 0.055 * pulse)), lineWidth: 0.75)
        }
    }

    private func drawCausticFamily(
        in context: inout GraphicsContext,
        size: CGSize,
        time t: Double,
        family: Int,
        count: Int
    ) {
        let steps = 86
        let phaseOffset = Double(family) * 1.73

        for index in 0..<count {
            let p = (Double(index) + 0.5) / Double(count)
            let seed = family * 97 + index * 13
            let drift = 0.5 + 0.5 * sin(t * (0.035 + 0.006 * Double(family)) + p * 5.4)
            let thickness = CGFloat(0.65 + 1.05 * DriftNoise.hash(index, family + 3, seed: seed))
            let brightness = 0.08 + 0.20 * drift
            let color = causticColor(index: index, family: family).opacity(brightness)

            var path = Path()
            for step in 0...steps {
                let u = Double(step) / Double(steps)
                let point = causticPoint(
                    u: u,
                    p: p,
                    size: size,
                    time: t,
                    family: family,
                    seed: seed,
                    phaseOffset: phaseOffset
                )

                if step == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            context.stroke(path, with: .color(color.opacity(0.24)), lineWidth: thickness * 5.0)
            context.stroke(path, with: .color(color.opacity(0.52)), lineWidth: thickness * 2.0)
            context.stroke(path, with: .color(Color.white.opacity(0.08 + 0.05 * drift)), lineWidth: max(0.5, thickness * 0.55))
        }
    }

    private func causticPoint(
        u: Double,
        p: Double,
        size: CGSize,
        time t: Double,
        family: Int,
        seed: Int,
        phaseOffset: Double
    ) -> CGPoint {
        let baseAmplitude = min(size.width, size.height) * CGFloat(0.030 + 0.020 * DriftNoise.hash(family, 4, seed: seed))
        let waveA = sin(u * Double.pi * 2.0 * (1.15 + Double(family) * 0.18) + t * 0.12 + p * 7.0 + phaseOffset)
        let waveB = cos(u * Double.pi * 2.0 * (2.30 + Double(family) * 0.12) - t * 0.075 + p * 4.0)
        let offset = baseAmplitude * CGFloat(waveA + 0.55 * waveB)

        switch family {
        case 0:
            return CGPoint(
                x: size.width * CGFloat(u),
                y: size.height * CGFloat(p) + offset
            )
        case 1:
            return CGPoint(
                x: size.width * CGFloat(p) + offset,
                y: size.height * CGFloat(u)
            )
        default:
            let diagonal = CGFloat(u)
            let sweep = CGFloat(p - 0.5) * size.width * 0.72
            return CGPoint(
                x: size.width * diagonal + sweep + offset,
                y: size.height * CGFloat(1.0 - u) + offset * 0.55
            )
        }
    }

    private func drawGlints(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let glints = min(42, max(18, Int(size.width / 22)))

        for index in 0..<glints {
            let x = size.width * CGFloat(DriftNoise.hash(index, 2, seed: 700))
            let y = size.height * CGFloat(DriftNoise.hash(index, 5, seed: 700))
            let pulse = max(0.0, sin(t * 0.42 + Double(index) * 1.9))
            let radius = CGFloat(1.4 + 4.8 * pulse * DriftNoise.hash(index, 8, seed: 700))
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)

            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.16 * pulse),
                        config.palette.secondary.opacity(0.10 * pulse),
                        Color.clear
                    ]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: max(radius, 1)
                )
            )
        }
    }

    private func drawVignette(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.26)
                ]),
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                startRadius: min(size.width, size.height) * 0.20,
                endRadius: max(size.width, size.height) * 0.76
            )
        )
    }

    private func causticColor(index: Int, family: Int) -> Color {
        if index % 11 == 0 { return config.palette.secondary }
        if index % 7 == 0 { return config.palette.tertiary }
        return family == 1 ? config.palette.primary : Color.white
    }

    private func lineCount(for size: CGSize, divisor: CGFloat, minimum: Int, maximum: Int) -> Int {
        min(maximum, max(minimum, Int(max(size.width, size.height) / divisor)))
    }
}

struct ObsidianMonolithView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    render(in: context, size: size, time: t)
                }
                .ignoresSafeArea()
            }
        }
    }

    private func render(in context: GraphicsContext, size: CGSize, time t: Double) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.tertiary.opacity(0.12),
                    config.palette.primary.opacity(0.05),
                    Color.clear
                ]),
                center: CGPoint(x: size.width * 0.54, y: size.height * 0.40),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.85
            )
        )

        var glass = context
        glass.blendMode = .plusLighter

        let count = min(9, max(6, Int(size.width / 170)))
        for index in 0..<count {
            drawPanel(index: index, count: count, in: &glass, size: size, time: t)
        }

        drawFloorReflection(in: &glass, size: size, time: t)
        drawVignette(in: context, size: size)
    }

    private func drawPanel(
        index: Int,
        count: Int,
        in context: inout GraphicsContext,
        size: CGSize,
        time t: Double
    ) {
        let p = Double(index) / Double(max(1, count - 1))
        let depth = 0.72 + 0.28 * DriftNoise.hash(index, 3, seed: 250)
        let panelHeight = size.height * CGFloat(0.58 + 0.28 * depth)
        let panelWidth = size.width * CGFloat(0.085 + 0.045 * DriftNoise.hash(index, 6, seed: 250))
        let centerX = size.width * CGFloat(0.10 + 0.80 * p)
        let driftX = size.width * CGFloat(0.018 * sin(t * 0.045 + Double(index) * 1.27))
        let centerY = size.height * CGFloat(0.48 + 0.035 * cos(t * 0.035 + Double(index)))
        let skew = panelWidth * CGFloat(-0.24 + 0.48 * DriftNoise.hash(index, 9, seed: 250))

        let topY = centerY - panelHeight * 0.52
        let bottomY = centerY + panelHeight * 0.52
        let x = centerX + driftX
        let leftTop = CGPoint(x: x - panelWidth * 0.50 + skew, y: topY)
        let rightTop = CGPoint(x: x + panelWidth * 0.50 + skew * 0.55, y: topY)
        let rightBottom = CGPoint(x: x + panelWidth * 0.62 - skew * 0.22, y: bottomY)
        let leftBottom = CGPoint(x: x - panelWidth * 0.62 - skew * 0.48, y: bottomY)

        var panel = Path()
        panel.move(to: leftTop)
        panel.addLine(to: rightTop)
        panel.addLine(to: rightBottom)
        panel.addLine(to: leftBottom)
        panel.closeSubpath()

        let pulse = 0.5 + 0.5 * sin(t * 0.16 + Double(index) * 0.91)
        let fillOpacity = 0.035 + 0.035 * pulse
        context.fill(
            panel,
            with: .linearGradient(
                Gradient(colors: [
                    config.palette.secondary.opacity(fillOpacity),
                    Color.white.opacity(0.026),
                    config.palette.primary.opacity(fillOpacity * 0.72)
                ]),
                startPoint: leftTop,
                endPoint: rightBottom
            )
        )

        let edgeColor = index % 3 == 0 ? config.palette.primary : config.palette.secondary
        context.stroke(panel, with: .color(edgeColor.opacity(0.10 + 0.08 * pulse)), lineWidth: 5.5)
        context.stroke(panel, with: .color(Color.white.opacity(0.075 + 0.04 * pulse)), lineWidth: 1.2)

        var leadingEdge = Path()
        leadingEdge.move(to: leftTop)
        leadingEdge.addLine(to: leftBottom)
        context.stroke(leadingEdge, with: .color(config.palette.primary.opacity(0.18 + 0.12 * pulse)), lineWidth: 1.5)

        if index % 2 == 0 {
            var glint = Path()
            let glintX = x + panelWidth * CGFloat(-0.22 + 0.44 * pulse)
            glint.move(to: CGPoint(x: glintX + skew * 0.3, y: topY + panelHeight * 0.12))
            glint.addLine(to: CGPoint(x: glintX - skew * 0.2, y: bottomY - panelHeight * 0.14))
            context.stroke(glint, with: .color(Color.white.opacity(0.08 + 0.08 * pulse)), lineWidth: 1.1)
        }
    }

    private func drawFloorReflection(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let center = CGPoint(x: size.width * 0.52, y: size.height * 0.82)
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - size.width * 0.36,
                y: center.y - size.height * 0.06,
                width: size.width * 0.72,
                height: size.height * 0.12
            )),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.primary.opacity(0.10 + 0.04 * sin(t * 0.08)),
                    config.palette.secondary.opacity(0.05),
                    Color.clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: size.width * 0.38
            )
        )
    }

    private func drawVignette(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.34)
                ]),
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                startRadius: min(size.width, size.height) * 0.18,
                endRadius: max(size.width, size.height) * 0.78
            )
        )
    }
}

struct LumenVaultView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    render(in: context, size: size, time: t)
                }
                .ignoresSafeArea()
            }
        }
    }

    private func render(in context: GraphicsContext, size: CGSize, time t: Double) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        drawLightShafts(in: context, size: size, time: t)

        var glow = context
        glow.blendMode = .plusLighter
        drawVaultArches(in: &glow, size: size, time: t)
        drawApertureGlow(in: &glow, size: size, time: t)
        drawVignette(in: context, size: size)
    }

    private func drawLightShafts(in context: GraphicsContext, size: CGSize, time t: Double) {
        let count = 5
        for index in 0..<count {
            let p = Double(index) / Double(max(1, count - 1))
            let phase = t * 0.035 + p * 2.4
            let centerX = size.width * CGFloat(0.22 + 0.56 * p + 0.035 * sin(phase))
            let topWidth = size.width * CGFloat(0.04 + 0.02 * DriftNoise.hash(index, 4, seed: 900))
            let bottomWidth = size.width * CGFloat(0.18 + 0.06 * DriftNoise.hash(index, 6, seed: 900))

            var shaft = Path()
            shaft.move(to: CGPoint(x: centerX - topWidth, y: 0))
            shaft.addLine(to: CGPoint(x: centerX + topWidth, y: 0))
            shaft.addLine(to: CGPoint(x: centerX + bottomWidth, y: size.height))
            shaft.addLine(to: CGPoint(x: centerX - bottomWidth, y: size.height))
            shaft.closeSubpath()

            context.fill(
                shaft,
                with: .linearGradient(
                    Gradient(colors: [
                        config.palette.primary.opacity(0.06),
                        config.palette.secondary.opacity(0.018),
                        Color.clear
                    ]),
                    startPoint: CGPoint(x: centerX, y: 0),
                    endPoint: CGPoint(x: centerX, y: size.height)
                )
            )
        }
    }

    private func drawVaultArches(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let archCount = min(14, max(8, Int(size.height / 86)))
        let centerX = size.width * 0.5
        let bottomY = size.height * 0.88

        for index in 0..<archCount {
            let p = Double(index) / Double(max(1, archCount - 1))
            let width = size.width * CGFloat(0.24 + 0.74 * p)
            let height = size.height * CGFloat(0.18 + 0.54 * p)
            let lift = size.height * CGFloat(0.024 * sin(t * 0.065 + p * 4.0))
            let arch = archPath(
                centerX: centerX,
                bottomY: bottomY + lift,
                width: width,
                height: height
            )

            let shimmer = 0.5 + 0.5 * sin(t * 0.14 + p * 5.6)
            let color = index % 3 == 0 ? config.palette.primary : (index % 3 == 1 ? config.palette.secondary : config.palette.tertiary)

            context.stroke(arch, with: .color(color.opacity(0.09 + 0.06 * shimmer)), lineWidth: 8.0)
            context.stroke(arch, with: .color(color.opacity(0.18 + 0.08 * shimmer)), lineWidth: 2.4)
            context.stroke(arch, with: .color(Color.white.opacity(0.07 + 0.05 * shimmer)), lineWidth: 0.9)
        }
    }

    private func drawApertureGlow(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let center = CGPoint(
            x: size.width * (0.50 + 0.03 * sin(t * 0.045)),
            y: size.height * (0.34 + 0.025 * cos(t * 0.05))
        )
        let radius = min(size.width, size.height) * CGFloat(0.12 + 0.018 * sin(t * 0.09))

        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.primary.opacity(0.20),
                    config.palette.secondary.opacity(0.08),
                    Color.clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    private func archPath(centerX: CGFloat, bottomY: CGFloat, width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let left = CGPoint(x: centerX - width * 0.5, y: bottomY)
        let right = CGPoint(x: centerX + width * 0.5, y: bottomY)
        let apex = CGPoint(x: centerX, y: bottomY - height)

        path.move(to: left)
        path.addCurve(
            to: apex,
            control1: CGPoint(x: left.x, y: bottomY - height * 0.50),
            control2: CGPoint(x: centerX - width * 0.28, y: apex.y)
        )
        path.addCurve(
            to: right,
            control1: CGPoint(x: centerX + width * 0.28, y: apex.y),
            control2: CGPoint(x: right.x, y: bottomY - height * 0.50)
        )
        return path
    }

    private func drawVignette(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.30)
                ]),
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.48),
                startRadius: min(size.width, size.height) * 0.22,
                endRadius: max(size.width, size.height) * 0.82
            )
        )
    }
}
