import CoreGraphics
import Testing
@testable import Driftly

@MainActor
struct CausticSilkScoreTests {
    @Test func notesAndPairedHeadsStayOnTheFlowingStaffAndInsideTheScreen() {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 1032, height: 1376),
                     CGSize(width: 1376, height: 1032), CGSize(width: 1920, height: 1080)] {
            for sample in 0...90 {
                let time = Double(sample) * 2
                for index in 0..<16 {
                    let note = CausticSilkScore.note(index: index, size: size, time: time)
                    let exact = CausticSilkScore.point(u: note.u, lane: note.lane, size: size, time: time)
                    #expect(hypot(note.head.x - exact.x, note.head.y - exact.y) < 0.000_001)
                    for head in [note.head, note.secondHead] {
                        let onStaff = CausticSilkScore.point(atX: head.x, lane: note.lane, size: size, time: time)
                        #expect(hypot(head.x - onStaff.x, head.y - onStaff.y) < 0.002)
                        let upper = CausticSilkScore.point(atX: head.x, lane: 0, size: size, time: time)
                        let lower = CausticSilkScore.point(atX: head.x, lane: 8, size: size, time: time)
                        #expect(head.y >= upper.y && head.y <= lower.y)
                        #expect(head.x > note.unit * 1.5 && head.x < size.width - note.unit * 3.5)
                        #expect(head.y > note.unit * 6.8 && head.y < size.height - note.unit * 1.3,
                                "Glyph needs headroom at \(size), note \(index), time \(time)")
                    }
                }
            }
        }
    }

    @Test func everyVoiceClimbsAndDescendsWithContinuousPitchChanges() {
        let size = CGSize(width: 1376, height: 1032)
        for index in 0..<16 {
            var rising = false, falling = false
            var previous = CausticSilkScore.note(index: index, size: size, time: 0).lane
            for sample in 1...700 {
                let time = Double(sample) * 0.1
                let lane = CausticSilkScore.note(index: index, size: size, time: time).lane
                #expect(lane >= 2 && lane <= 7)
                #expect(abs(lane - previous) < 0.06)
                rising = rising || lane > previous + 0.001
                falling = falling || lane < previous - 0.001
                previous = lane
            }
            #expect(rising && falling)
            for step in 0...12 {
                let time = (Double(step) - Double(index) * 0.67) * (5.2 + Double(index % 4) * 0.45)
                let a = CausticSilkScore.note(index: index, size: size, time: time - 0.000_01)
                let b = CausticSilkScore.note(index: index, size: size, time: time + 0.000_01)
                #expect(hypot(a.head.x - b.head.x, a.head.y - b.head.y) < 0.01)
            }
        }
    }
}
