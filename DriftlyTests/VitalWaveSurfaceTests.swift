import CoreGraphics
import Testing
@testable import Driftly

@MainActor
struct VitalWaveSurfaceTests {
    @Test func neighboringCellsShareCornersAndStayConvexAcrossAspectRatios() {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 1376, height: 1032),
                     CGSize(width: 1032, height: 1376), CGSize(width: 1920, height: 1080)] {
            let unit = VitalWaveSurface.unit(in: size)
            for sample in 0...30 {
                let time = Double(sample) * 6
                for row in -1...Int(ceil(size.height / unit)) {
                    for column in -1...Int(ceil(size.width / unit)) {
                        let cell = VitalWaveSurface.cell(column: column, row: row, unit: unit, time: time)
                        let right = VitalWaveSurface.cell(column: column + 1, row: row, unit: unit, time: time)
                        let below = VitalWaveSurface.cell(column: column, row: row + 1, unit: unit, time: time)
                        #expect(cell.corners[1] == right.corners[0] && cell.corners[2] == right.corners[3])
                        #expect(cell.corners[2] == below.corners[1] && cell.corners[3] == below.corners[0])
                        for index in 0..<4 {
                            let a = cell.corners[index], b = cell.corners[(index + 1) % 4], c = cell.corners[(index + 2) % 4]
                            #expect((b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x) > unit * unit * 0.1)
                        }
                    }
                }
            }
        }
    }

    @Test func tideAndMeshMoveContinuouslyWithoutResets() {
        for sample in 0...600 {
            let time = Double(sample) * 0.5
            for row in -1...6 {
                for column in -1...9 {
                    let a = VitalWaveSurface.cell(column: column, row: row, unit: 200, time: time)
                    let b = VitalWaveSurface.cell(column: column, row: row, unit: 200, time: time + 0.001)
                    #expect(a.lift >= 0 && a.lift <= 1 && abs(a.lift - b.lift) < 0.001)
                    #expect(hypot(a.center.x - b.center.x, a.center.y - b.center.y) < 0.01)
                }
            }
        }
    }
}
