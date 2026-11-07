import SwiftUI

struct VitalWaveView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PausableTimelineView(paused: animationsPaused || reduceMotion) { date in
            let time = date.timeIntervalSinceReferenceDate * max(0.25, speed)
            Canvas { context, size in
                let bounds = Path(CGRect(origin: .zero, size: size))
                context.fill(bounds, with: .linearGradient(
                    Gradient(colors: [config.palette.backgroundTop, Color(red: 0.018, green: 0.035, blue: 0.065),
                                      config.palette.backgroundBottom]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
                ))
                let unit = VitalWaveSurface.unit(in: size)
                let columns = Int(ceil(size.width / unit))
                let rows = Int(ceil(size.height / unit))
                for row in -1...rows {
                    for column in -1...columns {
                        drawCell(column: column, row: row, unit: unit, in: context, time: time)
                    }
                }
                context.fill(bounds, with: .radialGradient(
                    Gradient(colors: [.clear, .black.opacity(0.34)]),
                    center: CGPoint(x: size.width * 0.52, y: size.height * 0.46),
                    startRadius: min(size.width, size.height) * 0.22,
                    endRadius: max(size.width, size.height) * 0.80
                ))
            }
            .blur(radius: 0.65)
            .ignoresSafeArea()
        }
    }

    private func drawCell(column: Int, row: Int, unit: Double, in context: GraphicsContext, time: Double) {
        let cell = VitalWaveSurface.cell(column: column, row: row, unit: unit, time: time)
        let corners = cell.corners
        let center = cell.center
        let opening = 0.78 + 0.08 * cell.lift
        let points = corners.map { CGPoint(x: center.x + ($0.x - center.x) * opening,
                                          y: center.y + ($0.y - center.y) * opening) }
        func blend(_ a: CGPoint, _ b: CGPoint, _ mix: Double) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * mix, y: a.y + (b.y - a.y) * mix)
        }
        // Rounded, uneven cells leave dark channels between the moving opalescent surfaces.
        var membrane = Path()
        membrane.move(to: blend(points[0], points[1], 0.28))
        for corner in 1...4 {
            let index = corner % 4
            membrane.addLine(to: blend(points[index], points[(index + 3) % 4], 0.28))
            membrane.addQuadCurve(to: blend(points[index], points[(index + 1) % 4], 0.28), control: points[index])
        }
        membrane.closeSubpath()
        let phase = time * 0.022 + 0.65 * sin(Double(column) * 1.3 + Double(row) * 0.8)
        let tint = color(phase), edge = color(phase + 1.2)
        let start = blend(points[0], center, 0.15)
        let end = blend(points[2], center, 0.1)
        context.fill(membrane, with: .linearGradient(
            Gradient(stops: [
                .init(color: tint.opacity(0.10), location: 0),
                .init(color: tint.opacity(0.23 + cell.lift * 0.15), location: 0.34),
                .init(color: edge.opacity(0.32 + cell.lift * 0.16), location: 0.68),
                .init(color: edge.opacity(0.07), location: 1)
            ]), startPoint: start, endPoint: end
        ))
        context.stroke(membrane, with: .linearGradient(
            Gradient(colors: [edge.opacity(0.02), tint.opacity(0.20 + cell.lift * 0.12), .clear]),
            startPoint: start, endPoint: end
        ), style: StrokeStyle(lineWidth: max(0.7, unit * 0.007), lineJoin: .round))

        // An off-center fold catches the passing wave, like light under polished sea glass.
        let fold = CGPoint(x: center.x + unit * 0.12 * sin(cell.phase + time * 0.06),
                           y: center.y + unit * 0.08 * cos(cell.phase - time * 0.05))
        var facet = Path()
        facet.move(to: blend(points[0], points[1], 0.28))
        facet.addQuadCurve(to: blend(points[1], points[2], 0.58),
                           control: blend(points[1], center, 0.25))
        facet.addQuadCurve(to: blend(points[2], points[3], 0.58), control: fold)
        facet.addQuadCurve(to: blend(points[0], points[1], 0.28), control: blend(points[0], center, 0.30))
        context.fill(facet, with: .linearGradient(
            Gradient(colors: [Color.white.opacity(0.015), edge.opacity(0.05 + cell.lift * 0.12), .clear]),
            startPoint: points[0], endPoint: points[2]
        ))
        var lip = Path()
        lip.move(to: blend(points[0], points[1], 0.28))
        lip.addQuadCurve(to: blend(points[1], points[2], 0.35),
                         control: blend(points[1], center, 0.15 + 0.07 * cell.lift))
        context.stroke(lip, with: .linearGradient(
            Gradient(colors: [.clear, Color.white.opacity(0.07 + cell.lift * 0.12), .clear]),
            startPoint: points[0], endPoint: points[2]
        ), style: StrokeStyle(lineWidth: max(0.6, unit * 0.005), lineCap: .round))
    }

    private static let colors: [SIMD3<Double>] = [SIMD3(0.23, 0.82, 0.77), SIMD3(0.36, 0.60, 0.99),
                                                 SIMD3(0.78, 0.40, 0.91), SIMD3(1, 0.43, 0.51),
                                                 SIMD3(1, 0.73, 0.36)]
    private func color(_ phase: Double) -> Color {
        let whole = floor(phase)
        let index = ((Int(whole) % Self.colors.count) + Self.colors.count) % Self.colors.count
        let fraction = phase - whole
        let mix = fraction * fraction * (3 - 2 * fraction)
        let rgb = Self.colors[index] * (1 - mix) + Self.colors[(index + 1) % Self.colors.count] * mix
        return Color(red: rgb.x, green: rgb.y, blue: rgb.z)
    }
}

/// A bounded, continuously deforming mesh; neighboring cells share the same underlying corners.
enum VitalWaveSurface {
    struct Cell {
        let corners: [CGPoint]
        let center: CGPoint
        let phase: Double
        let lift: Double
    }
    static func unit(in size: CGSize) -> Double { max(60, min(size.width, size.height) * 0.24) }

    static func cell(column: Int, row: Int, unit: Double, time: Double) -> Cell {
        func vertex(_ x: Int, _ y: Int) -> CGPoint {
            let phase = Double(x) * 1.71 + Double(y) * 2.19
            return CGPoint(x: (Double(x) + 0.15 * sin(time * 0.055 + phase)) * unit,
                           y: (Double(y) + 0.14 * cos(time * 0.049 + phase * 1.31)) * unit)
        }
        let corners = [vertex(column, row), vertex(column + 1, row),
                       vertex(column + 1, row + 1), vertex(column, row + 1)]
        let center = CGPoint(x: corners.reduce(0) { $0 + $1.x } / 4,
                             y: corners.reduce(0) { $0 + $1.y } / 4)
        let phase = Double(column) * 0.72 + Double(row) * 0.93
        let tide = 0.5 + 0.5 * sin(Double(column) * 0.70 + Double(row) * 0.52 - time * 0.13)
        let lift = tide * tide * (3 - 2 * tide)
        return Cell(corners: corners, center: center, phase: phase, lift: lift)
    }
}
