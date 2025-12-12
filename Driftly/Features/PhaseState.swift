import Foundation

struct PhaseState {
    var frozenPhase: Double = 0
    var phaseOffset: Double = 0
}

func wrap01(_ value: Double) -> Double {
    let wrapped = value.truncatingRemainder(dividingBy: 1)
    return wrapped < 0 ? wrapped + 1 : wrapped
}
