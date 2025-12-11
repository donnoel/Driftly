import SwiftUI

enum DriftMode: String, CaseIterable, Identifiable {
    case nebulaLake
    case cosmicTide
    case auroraVeil
    case abyssGlow
    case starlitMist
    case lunarDrift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nebulaLake:  return "Nebula Lake"
        case .cosmicTide:  return "Cosmic Tide"
        case .auroraVeil:  return "Aurora Veil"
        case .abyssGlow:   return "Abyss Glow"
        case .starlitMist: return "Starlit Mist"
        case .lunarDrift:  return "Lunar Drift"
        }
    }

    var config: DriftModeConfig {
        switch self {
        case .nebulaLake:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 40
            )
        case .cosmicTide:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 28
            )
        case .auroraVeil:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 36
            )
        case .abyssGlow:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 32
            )
        case .starlitMist:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 45
            )
        case .lunarDrift:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 38
            )
        }
    }
}

struct DriftModeConfig: Identifiable, Equatable {
    let id: DriftMode
    let displayName: String
    let cycleDuration: TimeInterval
}
