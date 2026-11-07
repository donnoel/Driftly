import SwiftUI

/// Exactly one resident, with long quiet stays and a continuous journey through neighboring cells.
enum VitalWaveResident {
    static let interval = 48.0
    static let slideStart = 32.0
    static let hopStart = 34.5
    static let arrival = 37.0
    enum Activity { case resting, sliding, hopping, settling }
    struct CellID: Equatable {
        let column: Int
        let row: Int
    }
    struct Layout: Hashable {
        let width: CGFloat
        let height: CGFloat
        let columns: Int
        let rows: Int
        init(size: CGSize) {
            width = size.width
            height = size.height
            let unit = VitalWaveSurface.unit(in: size)
            columns = max(1, Int(floor(size.width / unit)))
            rows = max(1, Int(floor(size.height / unit)))
        }
    }
    struct Route {
        let layout: Layout
        let cells: [CellID]
        let seed: UInt64

        init(size: CGSize, seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)) {
            let layout = Layout(size: size)
            self.layout = layout
            self.seed = seed
            var path = [CellID(column: min(1, layout.columns - 1), row: min(1, layout.rows - 1))]
            for visit in 0..<511 {
                let current = path.last!
                let previous = path.count > 1 ? path[path.count - 2] : nil
                let neighbors = [CellID(column: current.column - 1, row: current.row),
                                 CellID(column: current.column + 1, row: current.row),
                                 CellID(column: current.column, row: current.row - 1),
                                 CellID(column: current.column, row: current.row + 1)].filter {
                    $0.column >= 0 && $0.column < layout.columns && $0.row >= 0 && $0.row < layout.rows
                }
                let onward = neighbors.filter { $0 != previous }
                let choices = onward.isEmpty ? neighbors : onward
                path.append(choices.isEmpty ? current : choices[Int(VitalWaveResident.hash(seed &+ UInt64(visit)) % UInt64(choices.count))])
            }
            cells = path
        }

        func home(visit: Int) -> CellID {
            let length = (cells.count - 1) * 2
            let index = ((visit % length) + length) % length
            return cells[index < cells.count ? index : length - index]
        }
    }
    struct Pose {
        let source: CellID
        let target: CellID
        let occupiedCell: CellID?
        let foot: CGPoint
        let activity: Activity
        let age: Double
        let progress: Double
        let facing: Double
        let sleep: Double
    }
    static func radius(in size: CGSize) -> Double { min(14, max(6, VitalWaveSurface.unit(in: size) * 0.10)) }

    private static func hash(_ value: UInt64) -> UInt64 {
        var value = value &+ 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    static func perch(_ id: CellID, visit: Int, route: Route, size: CGSize, time: Double) -> CGPoint {
        let unit = VitalWaveSurface.unit(in: size)
        let cell = VitalWaveSurface.cell(column: id.column, row: id.row, unit: unit, time: time)
        let p = cell.corners
        let xAxis = CGPoint(x: (p[1].x + p[2].x - p[0].x - p[3].x) * 0.5,
                            y: (p[1].y + p[2].y - p[0].y - p[3].y) * 0.5)
        let yAxis = CGPoint(x: (p[2].x + p[3].x - p[0].x - p[1].x) * 0.5,
                            y: (p[2].y + p[3].y - p[0].y - p[1].y) * 0.5)
        let radius = radius(in: size)
        let xMargin = radius / max(1, hypot(xAxis.x, xAxis.y))
        let yMargin = radius / max(1, hypot(yAxis.x, yAxis.y))
        let xMin = -0.29 + 2.35 * xMargin, xMax = 0.29 - 1.4 * xMargin
        let yMin = -0.29 + 2.65 * yMargin, yMax = 0.29 - 0.3 * yMargin
        let key = route.seed &+ UInt64(bitPattern: Int64(visit)) &* 0x9E3779B97F4A7C15
        let xMix = Double(hash(key) >> 11) / 9_007_199_254_740_992
        let yMix = Double(hash(key &+ 0xA0761D6478BD642F) >> 11) / 9_007_199_254_740_992
        let x = xMin + (xMax - xMin) * xMix, y = yMin + (yMax - yMin) * yMix
        return CGPoint(x: cell.center.x + xAxis.x * x + yAxis.x * y,
                       y: cell.center.y + xAxis.y * x + yAxis.y * y)
    }

    static func pose(size: CGSize, time: Double, route: Route) -> Pose {
        let visit = Int(floor(time / interval))
        let age = time - Double(visit) * interval
        let start = Double(visit) * interval
        let source = route.home(visit: visit), target = route.home(visit: visit + 1)
        let unit = VitalWaveSurface.unit(in: size)
        let launchPerch = perch(source, visit: visit, route: route, size: size, time: start + hopStart)
        let landing = perch(target, visit: visit + 1, route: route, size: size, time: start + arrival)
        let dx = landing.x - launchPerch.x, dy = landing.y - launchPerch.y
        let distance = max(1, hypot(dx, dy))
        let launch = CGPoint(x: launchPerch.x + dx / distance * unit * 0.30,
                             y: launchPerch.y + dy / distance * unit * 0.30)
        let activity: Activity
        let occupied: CellID?
        let foot: CGPoint
        let progress: Double
        if age < slideStart {
            activity = .resting
            occupied = source
            foot = perch(source, visit: visit, route: route, size: size, time: time)
            progress = age / slideStart
        } else if age < hopStart {
            activity = .sliding
            occupied = nil
            progress = (age - slideStart) / (hopStart - slideStart)
            let mix = smooth(progress)
            let from = perch(source, visit: visit, route: route, size: size, time: start + slideStart)
            foot = CGPoint(x: from.x + (launch.x - from.x) * mix, y: from.y + (launch.y - from.y) * mix)
        } else if age < arrival {
            activity = .hopping
            occupied = nil
            progress = (age - hopStart) / (arrival - hopStart)
            let clearance = min(launch.y, landing.y) - radius(in: size) * 3.5 - 5
            let arc = max(0, min(unit * 0.29, clearance))
            foot = CGPoint(x: launch.x + (landing.x - launch.x) * progress,
                           y: launch.y + (landing.y - launch.y) * progress - 4 * arc * progress * (1 - progress))
        } else {
            activity = .settling
            occupied = target
            progress = (age - arrival) / (interval - arrival)
            foot = perch(target, visit: visit + 1, route: route, size: size, time: time)
        }
        let sleep = activity == .resting ? 1 - smooth((age - 27) / 3)
            : (activity == .settling ? smooth((age - arrival - 5) / 3) : 0)
        return Pose(source: source, target: target, occupiedCell: occupied, foot: foot,
                    activity: activity, age: age, progress: progress, facing: dx >= 0 ? 1 : -1, sleep: sleep)
    }

    static func deformation(for id: CellID, pose: Pose) -> Double {
        func spring(_ age: Double, duration: Double) -> Double {
            guard age >= 0, age < duration else { return 0 }
            return sin(age * 5.2) * exp(-age * 1.05) * (1 - smooth((age / duration - 0.65) / 0.35))
        }
        if id == pose.source {
            if pose.activity == .sliding { return 0.055 * pow(sin(.pi * pose.progress), 2) }
            if pose.activity == .hopping { return 0.05 * spring(pose.age - hopStart, duration: arrival - hopStart) }
        }
        if id == pose.target, pose.activity == .settling {
            return 0.075 * spring(pose.age - arrival, duration: 7)
        }
        return 0
    }

    static func smooth(_ value: Double) -> Double {
        let u = min(1, max(0, value))
        return u * u * (3 - 2 * u)
    }
}

enum VitalWaveResidentArtwork {
    static func draw(in context: GraphicsContext, pose: VitalWaveResident.Pose, size: CGSize, time: Double) {
        let r = VitalWaveResident.radius(in: size)
        let sleeping = pose.sleep
        let stretch = pose.activity == .hopping ? sin(.pi * pose.progress) : 0
        let settleAge = pose.age - VitalWaveResident.arrival
        let squash = pose.activity == .settling && settleAge < 0.9
            ? 0.14 * sin(.pi * settleAge / 0.9) : 0
        let breath = sleeping * 0.035 * sin(time * 0.65)
        var sprite = context
        sprite.translateBy(x: pose.foot.x, y: pose.foot.y)
        sprite.rotate(by: .radians(-0.12 * stretch + sleeping * 0.045 * sin(time * 0.28)))
        sprite.scaleBy(x: 1 + squash - stretch * 0.06 + breath,
                       y: 1 - squash + stretch * 0.10 - breath)
        let rose = Color(red: 0.98, green: 0.66, blue: 0.81)
        let pearl = Color(red: 1, green: 0.94, blue: 0.84)
        let lavender = Color(red: 0.71, green: 0.66, blue: 0.97)
        var tail = Path()
        tail.move(to: CGPoint(x: -r * 0.7, y: -r * 0.6))
        tail.addCurve(to: CGPoint(x: -r * 1.65, y: -r * (1.0 + 0.12 * sin(time * 0.6))),
                      control1: CGPoint(x: -r * 2.1, y: r * 0.2), control2: CGPoint(x: -r * 2.0, y: -r * 1.9))
        sprite.stroke(tail, with: .color(rose.opacity(0.82)), style: StrokeStyle(lineWidth: r * 0.18, lineCap: .round))
        // Small rounded ears and a soft curl of fur give her a cuddly, sleepy silhouette.
        for side in [-1.0, 1.0] {
            let sway = 0.08 * sin(time * 0.55 + side)
            sprite.fill(Path(ellipseIn: CGRect(x: r * (side * 0.75 - 0.32), y: -r * (1.9 + sway),
                                               width: r * 0.64, height: r * 0.84)),
                        with: .linearGradient(Gradient(colors: [rose, lavender]),
                            startPoint: CGPoint(x: 0, y: -r * 2), endPoint: CGPoint(x: 0, y: -r)))
            sprite.fill(Path(ellipseIn: CGRect(x: r * (side * 0.38 - 0.25), y: -r * 0.17,
                                               width: r * 0.5, height: r * 0.26)), with: .color(rose.opacity(0.9)))
        }
        sprite.fill(Path(ellipseIn: CGRect(x: -r * 0.94, y: -r * 1.92, width: r * 1.88, height: r * 1.87)),
                    with: .linearGradient(Gradient(colors: [pearl, Color(red: 0.78, green: 0.85, blue: 1), lavender]),
                        startPoint: CGPoint(x: -r * 0.5, y: -r * 1.9), endPoint: CGPoint(x: r * 0.7, y: 0)))
        for index in 0..<3 {
            sprite.fill(Path(ellipseIn: CGRect(x: r * (-0.48 + Double(index) * 0.27),
                                               y: -r * (2.05 + (index == 1 ? 0.12 : 0)),
                                               width: r * 0.5, height: r * 0.48)), with: .color(pearl.opacity(0.85)))
        }
        sprite.fill(Path(ellipseIn: CGRect(x: -r * 0.46, y: -r * 0.83, width: r * 0.92, height: r * 0.6)),
                    with: .color(pearl.opacity(0.65)))
        let ink = Color(red: 0.20, green: 0.13, blue: 0.29)
        for side in [-1.0, 1.0] {
            let x = side * r * 0.32
            let height = r * (0.23 * (1 - sleeping) + 0.025)
            sprite.fill(Path(ellipseIn: CGRect(x: x - r * 0.09, y: -r * 1.25, width: r * 0.18, height: height)),
                        with: .color(ink.opacity(0.9 * (1 - sleeping))))
            var eyelid = Path()
            eyelid.move(to: CGPoint(x: x - r * 0.13, y: -r * 1.16))
            eyelid.addQuadCurve(to: CGPoint(x: x + r * 0.13, y: -r * 1.16),
                                control: CGPoint(x: x, y: -r * 1.03))
            sprite.stroke(eyelid, with: .color(ink.opacity(sleeping * 0.85)),
                          style: StrokeStyle(lineWidth: max(0.7, r * 0.08), lineCap: .round))
            sprite.fill(Path(ellipseIn: CGRect(x: x - r * 0.14, y: -r * 0.99, width: r * 0.28, height: r * 0.14)),
                        with: .color(rose.opacity(0.62)))
        }
        var smile = Path()
        smile.move(to: CGPoint(x: -r * 0.13, y: -r * 0.99))
        smile.addQuadCurve(to: CGPoint(x: r * 0.13, y: -r * 0.99), control: CGPoint(x: 0, y: -r * 0.88))
        sprite.stroke(smile, with: .color(ink.opacity(0.62)),
                      style: StrokeStyle(lineWidth: max(0.65, r * 0.06), lineCap: .round))
    }
}
