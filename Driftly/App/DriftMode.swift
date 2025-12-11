import Foundation

enum DriftMode: String, CaseIterable, Identifiable {
    case nebulaLake
    case // placeholder for future modes
         cosmicTide
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
}
