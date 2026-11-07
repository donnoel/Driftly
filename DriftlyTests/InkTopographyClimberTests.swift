import CoreGraphics
import Testing
@testable import Driftly

@MainActor
struct InkTopographyClimberTests {
    private let sizes = [CGSize(width: 393, height: 852), CGSize(width: 852, height: 393),
                         CGSize(width: 1032, height: 1376), CGSize(width: 1376, height: 1032),
                         CGSize(width: 1920, height: 1080)]

    @Test func journeyContainsSetbacksSummitDanceWalkAndReturnToTheBottom() {
        let stages = InkTopographyClimber.stages
        #expect(stages.first?.source.band == 17)
        #expect(stages.filter { $0.activity == .slip }.count == 2)
        let dance = stages.firstIndex { $0.activity == .dance }!
        #expect(stages[dance].source.band == 0)
        #expect(stages[dance + 1].activity == .walk)
        #expect(stages[dance + 2].activity == .drop)
        #expect(stages[dance + 2].target.band == 17)
        #expect(stages.last?.target.x == stages.first?.source.x)
        #expect(stages.filter { $0.activity == .hop }.contains { abs($0.target.x - $0.source.x) > 0.18 })
        #expect(InkTopographyClimber.cycleDuration > 100)
    }

    @Test func feetRemainOnMovingContoursWhileRestingDancingAndWalking() {
        for size in sizes {
            for stage in InkTopographyClimber.stages where [.rest, .dance, .walk].contains(stage.activity) {
                for u in [0.1, 0.5, 0.9] {
                    let time = stage.start + stage.duration * u
                    let pose = InkTopographyClimber.pose(size: size, time: time, octaves: 4)
                    let surface = InkTopographySurface.y(x: pose.foot.x, band: stage.source.band,
                                                        size: size, time: time, octaves: 4)
                    #expect(abs(pose.foot.y - surface) < 0.000_001)
                }
            }
        }
    }

    @Test func everyStageAndCycleJoinIsContinuousAndTheSpriteStaysOnScreen() {
        for size in sizes {
            let radius = InkTopographyClimber.radius(in: size)
            for cycle in 0...1 {
                let offset = Double(cycle) * InkTopographyClimber.cycleDuration
                for stage in InkTopographyClimber.stages {
                    let time = stage.end + offset
                    let a = InkTopographyClimber.pose(size: size, time: time - 0.000_01, octaves: 4)
                    let b = InkTopographyClimber.pose(size: size, time: time + 0.000_01, octaves: 4)
                    #expect(hypot(a.foot.x - b.foot.x, a.foot.y - b.foot.y) < 0.03)
                }
            }
            for sample in 0...700 {
                let time = Double(sample) * InkTopographyClimber.cycleDuration / 350
                let p = InkTopographyClimber.pose(size: size, time: time, octaves: 4).foot
                #expect(p.x > radius * 3 && p.x < size.width - radius * 3)
                #expect(p.y > radius * 3.6 && p.y < size.height - radius)
            }
        }
    }

    @Test func summitOpensBeforeTheFallAndTheBottomRemainsSolid() {
        let stage = InkTopographyClimber.stages.first { $0.activity == .drop }!
        for size in sizes {
            let time = stage.start + 0.65
            let pose = InkTopographyClimber.pose(size: size, time: time, octaves: 4)
            let gap = InkTopographyClimber.gap(band: 0, pose: pose, size: size, time: time, octaves: 4)
            #expect(gap?.contains(pose.foot.x) == true)
            #expect((gap?.upperBound ?? 0) - (gap?.lowerBound ?? 0) > InkTopographyClimber.radius(in: size) * 3)
            #expect(InkTopographyClimber.gap(band: 17, pose: pose, size: size, time: time, octaves: 4) == nil)
            // Free fall starts with zero vertical velocity and accelerates downward.
            let positions = [1.8, 2.8, 3.8].map {
                InkTopographyClimber.pose(size: size, time: stage.start + $0, octaves: 4).foot.y
            }
            #expect(positions[2] - positions[1] > positions[1] - positions[0])
        }
    }
}
