import CoreGraphics
import SwiftUI
import Testing
@testable import Driftly

@MainActor
struct VitalWaveResidentTests {
    private let sizes = [CGSize(width: 393, height: 852), CGSize(width: 1032, height: 1376),
                         CGSize(width: 1376, height: 1032), CGSize(width: 1920, height: 1080)]

    @Test func singleResidentRestsInsideOneCellAndVisitsOnlyNeighbors() {
        for size in sizes {
            let route = VitalWaveResident.Route(size: size, seed: 93_173)
            let unit = VitalWaveSurface.unit(in: size)
            for visit in 0..<80 {
                let source = route.home(visit: visit)
                let target = route.home(visit: visit + 1)
                #expect(abs(source.column - target.column) + abs(source.row - target.row) == 1)
                for age in [0.0, 12, 26, 39, 47] {
                    let time = Double(visit) * VitalWaveResident.interval + age
                    let pose = VitalWaveResident.pose(size: size, time: time, route: route)
                    let id = age < VitalWaveResident.slideStart ? source : target
                    #expect(pose.occupiedCell == id)
                    let cell = VitalWaveSurface.cell(column: id.column, row: id.row, unit: unit, time: time)
                    let perch = VitalWaveResident.perch(id, visit: age < 32 ? visit : visit + 1,
                                                        route: route, size: size, time: time)
                    #expect(hypot(pose.foot.x - perch.x, pose.foot.y - perch.y) < 0.000_001)
                    let r = VitalWaveResident.radius(in: size) * 1.08
                    let membrane = cell.membrane(wobble: VitalWaveResident.deformation(for: id, pose: pose))
                    for offset in [CGPoint(x: -1.9, y: -0.65), CGPoint(x: -0.95, y: -1.2),
                                   CGPoint(x: 0.95, y: -1), CGPoint(x: 0, y: -2.4),
                                   CGPoint(x: -0.6, y: -2.1), CGPoint(x: 0.8, y: -2), .zero] {
                        #expect(membrane.contains(CGPoint(x: pose.foot.x + offset.x * r,
                                                         y: pose.foot.y + offset.y * r)),
                                "Resident must fit within the rounded cell at visit \(visit), \(size)")
                    }
                }
                let sleeping = VitalWaveResident.pose(size: size, time: Double(visit) * 48 + 12, route: route)
                #expect(sleeping.sleep == 1)
                let flight = VitalWaveResident.pose(size: size, time: Double(visit) * 48 + 35.5, route: route)
                #expect(flight.occupiedCell == nil && flight.activity == .hopping)
            }
        }
    }

    @Test func slideFlightLandingAndLongRestStayContinuousAndVisible() {
        for size in sizes {
            let route = VitalWaveResident.Route(size: size, seed: 93_173)
            let r = VitalWaveResident.radius(in: size)
            for visit in 0..<36 {
                let start = Double(visit) * 48
                for boundary in [32.0, 34.5, 37, 48] {
                    let a = VitalWaveResident.pose(size: size, time: start + boundary - 0.000_01, route: route)
                    let b = VitalWaveResident.pose(size: size, time: start + boundary + 0.000_01, route: route)
                    #expect(hypot(a.foot.x - b.foot.x, a.foot.y - b.foot.y) < 0.02)
                    #expect(abs(a.sleep - b.sleep) < 0.001)
                }
                for sample in 0...96 {
                    let pose = VitalWaveResident.pose(size: size, time: start + Double(sample) * 0.5, route: route)
                    #expect(pose.foot.x > r * 2.4 && pose.foot.x < size.width - r * 2.4)
                    #expect(pose.foot.y > r * 3.4 && pose.foot.y < size.height - r)
                }
                let a = VitalWaveResident.pose(size: size, time: start + 35, route: route).foot
                let b = VitalWaveResident.pose(size: size, time: start + 35.5, route: route).foot
                let c = VitalWaveResident.pose(size: size, time: start + 36, route: route).foot
                #expect(abs(c.x - 2 * b.x + a.x) < 0.000_001)
                #expect(c.y - 2 * b.y + a.y > 0)
            }
        }
    }

    @Test func onlyTouchedCellsWobbleAndReturnToRest() {
        let size = CGSize(width: 1376, height: 1032)
        let route = VitalWaveResident.Route(size: size, seed: 93_173)
        for age in [31.0, 33, 35, 37.5, 39, 44.5, 47.9] {
            let pose = VitalWaveResident.pose(size: size, time: age, route: route)
            for row in 0..<4 {
                for column in 0..<5 {
                    let id = VitalWaveResident.CellID(column: column, row: row)
                    let wobble = VitalWaveResident.deformation(for: id, pose: pose)
                    #expect(abs(wobble) < 0.08)
                    if id != pose.source && id != pose.target { #expect(wobble == 0) }
                    if age >= 44.5 || age < 32 { #expect(wobble == 0) }
                }
            }
        }
    }

    @Test func choicesVaryAcrossDirectionsAndAcrossTheInsideOfEachCell() {
        let size = CGSize(width: 1376, height: 1032)
        let route = VitalWaveResident.Route(size: size, seed: 93_173)
        let another = VitalWaveResident.Route(size: size, seed: 93_174)
        #expect(route.cells != another.cells)
        var directions = Set<String>()
        var xs: [Double] = [], ys: [Double] = []
        let unit = VitalWaveSurface.unit(in: size)
        for visit in 0..<100 {
            let id = route.home(visit: visit), target = route.home(visit: visit + 1)
            directions.insert("\(target.column - id.column),\(target.row - id.row)")
            let time = Double(visit) * 48 + 10
            let p = VitalWaveResident.perch(id, visit: visit, route: route, size: size, time: time)
            let cell = VitalWaveSurface.cell(column: id.column, row: id.row, unit: unit, time: time)
            xs.append((p.x - cell.center.x) / unit)
            ys.append((p.y - cell.center.y) / unit)
        }
        #expect(directions.count == 4)
        #expect(xs.max()! - xs.min()! > 0.30)
        #expect(ys.max()! - ys.min()! > 0.30)
    }
}
