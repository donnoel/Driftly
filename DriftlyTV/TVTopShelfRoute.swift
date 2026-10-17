import Foundation

enum TVTopShelfRoute: Equatable {
    case play
    case display

    init?(url: URL) {
        switch url.absoluteString {
        case "driftly-tv://aurora-veil/play": self = .play
        case "driftly-tv://aurora-veil/display": self = .display
        default: return nil
        }
    }
}
