import CoreGraphics
import Testing
@testable import Driftly

@MainActor
struct RibbonOrbitMotionTests {
    @Test func colorWrapStaysContinuousAtLargeAndNegativePaletteBoundaries() {
        for phase in [-24.0, -6.0, 0.0, 6.0, 24.0, 24_000_000.0, 48_000_000.0] {
            let center = RibbonOrbitColor.rgb(phase: phase)
            for sample in [phase.nextDown, phase, phase.nextUp] {
                let rgb = RibbonOrbitColor.rgb(phase: sample)
                for component in 0..<3 {
                    #expect(rgb[component].isFinite && rgb[component] >= 0 && rgb[component] <= 1)
                    #expect(abs(rgb[component] - center[component]) < 0.000_001)
                }
            }
        }
        for sample in 0...600 {
            let phase = Double(sample) * 0.01
            let a = RibbonOrbitColor.rgb(phase: phase)
            let b = RibbonOrbitColor.rgb(phase: phase + 6)
            for component in 0..<3 { #expect(abs(a[component] - b[component]) < 0.000_001) }
        }
    }

    @Test func ribbonReassemblesWithoutEndpointGapsAndSeparatesIntoPieces() {
        let size = CGSize(width: 1376, height: 1032)
        for cycle in 0...3 {
            let rest = Double(cycle) * 64
            for piece in 0..<RibbonOrbitMotion.pieceCount {
                #expect(RibbonOrbitMotion.separation(piece: piece, time: rest) == 0)
                let end = RibbonOrbitMotion.point(piece: piece, progress: 1, size: size, time: rest)
                let start = RibbonOrbitMotion.point(piece: (piece + 1) % 8, progress: 0, size: size, time: rest)
                #expect(hypot(end.x - start.x, end.y - start.y) < 0.000_001)
                #expect(RibbonOrbitMotion.separation(piece: piece, time: rest + 32) > 0.95)
            }
        }
    }

    @Test func piecesStayVisibleAndMoveContinuouslyThroughSeveralCycles() {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 1032, height: 1376),
                     CGSize(width: 1376, height: 1032), CGSize(width: 1920, height: 1080)] {
            for sample in 0...768 {
                let time = Double(sample) * 0.25
                for piece in 0..<8 {
                    for progress in [0.0, 0.25, 0.5, 0.75, 1.0] {
                        let point = RibbonOrbitMotion.point(piece: piece, progress: progress, size: size, time: time)
                        let next = RibbonOrbitMotion.point(piece: piece, progress: progress, size: size, time: time + 0.001)
                        let margin = min(size.width, size.height) * 0.02
                        #expect(point.x > margin && point.x < size.width - margin)
                        #expect(point.y > margin && point.y < size.height - margin)
                        #expect(hypot(next.x - point.x, next.y - point.y) < max(size.width, size.height) * 0.001)
                    }
                }
            }
        }
    }
}
