import SwiftUI

// A reusable color palette for each mode
struct DriftPalette: Equatable {
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let backgroundTop: Color
    let backgroundBottom: Color
}

enum DriftMode: String, CaseIterable, Identifiable, Codable {
    case nebulaLake
    case cosmicTide
    case auroraVeil
    case abyssGlow
    case starlitMist
    case lunarDrift
    // Batch 1 (new)
    case solarBloom
    case plasmaReef
    case velvetEclipse
    case neonKelp
    case emberDrift
    // Batch 2 (new)
    case pulseAurora
    case vitalWave
    case echoBloom
    case cosmicHeart
    case signalDrift
    // Batch 3 (new)
    case horizonPulse
    case photonRain
    case gravityRings
    case driftGrid
    case quietSignal
    // Batch 4 (new)
    case chromaticSpine
    case ribbonOrbit
    case inkTopography
    case prismShards
    case lissajousBloom
    case meridianArcs
    case spectralLoom
    case voxelMirage
    case haloInterference

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nebulaLake:  return "Nebula Lake"
        case .cosmicTide:  return "Cosmic Tide"
        case .auroraVeil:  return "Aurora Veil"
        case .abyssGlow:   return "Abyss Glow"
        case .starlitMist: return "Starlit Mist"
        case .lunarDrift:  return "Lunar Drift"
        case .solarBloom:     return "Solar Bloom"
        case .plasmaReef:     return "Plasma Reef"
        case .velvetEclipse:  return "Velvet Eclipse"
        case .neonKelp:       return "Neon Kelp"
        case .emberDrift:     return "Ember Drift"
        case .pulseAurora:    return "Pulse Aurora"
        case .vitalWave:      return "Vital Wave"
        case .echoBloom:      return "Glow Bloom"
        case .cosmicHeart:    return "Cosmic Heart"
        case .signalDrift:    return "Signal Drift"
        case .horizonPulse:   return "Horizon Pulse"
        case .photonRain:     return "Photon Rain"
        case .gravityRings:   return "Gravity Rings"
        case .driftGrid:      return "Drift Grid"
        case .quietSignal:    return "Quiet Signal"
        case .chromaticSpine:    return "Chromatic Spine"
        case .ribbonOrbit:       return "Ribbon Orbit"
        case .inkTopography:     return "Ink Topography"
        case .prismShards:       return "Prism Shards"
        case .lissajousBloom:    return "Lissajous Bloom"
        case .meridianArcs:      return "Meridian Arcs"
        case .spectralLoom:      return "Spectral Loom"
        case .voxelMirage:       return "Voxel Mirage"
        case .haloInterference:  return "Halo Interference"
        }
    }

    var config: DriftModeConfig {
        switch self {

        case .nebulaLake:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 32,
                palette: DriftPalette(
                    primary:      Color(red: 0.15, green: 0.80, blue: 0.85),
                    secondary:    Color(red: 0.60, green: 0.35, blue: 1.00),
                    tertiary:     Color(red: 0.40, green: 0.80, blue: 1.00),
                    backgroundTop:    Color(red: 0.02, green: 0.03, blue: 0.09),
                    backgroundBottom: Color(red: 0.01, green: 0.02, blue: 0.05)
                )
            )

        case .cosmicTide:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 18,
                palette: DriftPalette(
                    primary:      Color(red: 0.85, green: 0.40, blue: 1.00),
                    secondary:    Color(red: 0.35, green: 0.75, blue: 1.00),
                    tertiary:     Color(red: 0.95, green: 0.55, blue: 0.95),
                    backgroundTop:    Color(red: 0.04, green: 0.01, blue: 0.10),
                    backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.06)
                )
            )

        case .auroraVeil:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 22,
                palette: DriftPalette(
                    primary:      Color(red: 0.10, green: 0.90, blue: 0.60),
                    secondary:    Color(red: 0.25, green: 0.45, blue: 1.00),
                    tertiary:     Color(red: 0.70, green: 0.95, blue: 0.80),
                    backgroundTop:    Color(red: 0.00, green: 0.02, blue: 0.07),
                    backgroundBottom: Color(red: 0.00, green: 0.05, blue: 0.10)
                )
            )

        case .abyssGlow:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 18,
                palette: DriftPalette(
                    primary:      Color(red: 0.20, green: 0.25, blue: 0.90),
                    secondary:    Color(red: 0.10, green: 0.50, blue: 1.00),
                    tertiary:     Color(red: 0.25, green: 0.80, blue: 0.90),
                    backgroundTop:    Color(red: 0.00, green: 0.00, blue: 0.02),
                    backgroundBottom: Color(red: 0.00, green: 0.00, blue: 0.10)
                )
            )

        case .starlitMist:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 24,
                palette: DriftPalette(
                    primary:      Color(red: 0.95, green: 0.95, blue: 1.00),
                    secondary:    Color(red: 0.55, green: 0.65, blue: 1.00),
                    tertiary:     Color(red: 0.75, green: 0.85, blue: 1.00),
                    backgroundTop:    Color(red: 0.02, green: 0.04, blue: 0.10),
                    backgroundBottom: Color(red: 0.00, green: 0.00, blue: 0.05)
                )
            )

        case .lunarDrift:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 22,
                palette: DriftPalette(
                    primary:      Color(red: 0.90, green: 0.90, blue: 1.00),
                    secondary:    Color(red: 0.60, green: 0.60, blue: 0.95),
                    tertiary:     Color(red: 0.80, green: 0.75, blue: 1.00),
                    backgroundTop:    Color(red: 0.05, green: 0.05, blue: 0.10),
                    backgroundBottom: Color(red: 0.02, green: 0.02, blue: 0.05)
                )
            )

        case .solarBloom:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 28,
                palette: DriftPalette(
                    primary:      Color(red: 1.00, green: 0.55, blue: 0.35),
                    secondary:    Color(red: 1.00, green: 0.30, blue: 0.70),
                    tertiary:     Color(red: 0.45, green: 0.95, blue: 0.88),
                    backgroundTop:    Color(red: 0.06, green: 0.02, blue: 0.10),
                    backgroundBottom: Color(red: 0.02, green: 0.01, blue: 0.06)
                )
            )

        case .plasmaReef:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 26,
                palette: DriftPalette(
                    primary:      Color(red: 0.25, green: 0.95, blue: 0.85),
                    secondary:    Color(red: 0.60, green: 0.40, blue: 0.98),
                    tertiary:     Color(red: 1.00, green: 0.55, blue: 0.60),
                    backgroundTop:    Color(red: 0.01, green: 0.06, blue: 0.10),
                    backgroundBottom: Color(red: 0.00, green: 0.02, blue: 0.07)
                )
            )

        case .velvetEclipse:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 34,
                palette: DriftPalette(
                    primary:      Color(red: 0.55, green: 0.30, blue: 0.98),
                    secondary:    Color(red: 0.18, green: 0.75, blue: 0.98),
                    tertiary:     Color(red: 0.95, green: 0.35, blue: 0.72),
                    backgroundTop:    Color(red: 0.03, green: 0.01, blue: 0.07),
                    backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.04)
                )
            )

        case .neonKelp:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 20,
                palette: DriftPalette(
                    primary:      Color(red: 0.40, green: 0.98, blue: 0.55),
                    secondary:    Color(red: 0.25, green: 0.85, blue: 0.98),
                    tertiary:     Color(red: 0.75, green: 0.45, blue: 0.98),
                    backgroundTop:    Color(red: 0.00, green: 0.05, blue: 0.10),
                    backgroundBottom: Color(red: 0.00, green: 0.02, blue: 0.06)
                )
            )

        case .emberDrift:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 30,
                palette: DriftPalette(
                    primary:      Color(red: 1.00, green: 0.42, blue: 0.20),
                    secondary:    Color(red: 1.00, green: 0.70, blue: 0.30),
                    tertiary:     Color(red: 0.95, green: 0.25, blue: 0.55),
                    backgroundTop:    Color(red: 0.08, green: 0.02, blue: 0.05),
                    backgroundBottom: Color(red: 0.03, green: 0.01, blue: 0.04)
                )
            )

        case .pulseAurora:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 28,
                palette: DriftPalette(
                    primary:      Color(red: 0.35, green: 0.95, blue: 0.88),
                    secondary:    Color(red: 0.82, green: 0.40, blue: 1.00),
                    tertiary:     Color(red: 0.40, green: 0.70, blue: 1.00),
                    backgroundTop:    Color(red: 0.02, green: 0.03, blue: 0.09),
                    backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.06)
                )
            )

        case .vitalWave:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 22,
                palette: DriftPalette(
                    primary:      Color(red: 0.25, green: 0.95, blue: 0.85),
                    secondary:    Color(red: 0.55, green: 0.55, blue: 1.00),
                    tertiary:     Color(red: 1.00, green: 0.55, blue: 0.85),
                    backgroundTop:    Color(red: 0.01, green: 0.05, blue: 0.12),
                    backgroundBottom: Color(red: 0.00, green: 0.01, blue: 0.07)
                )
            )

        case .echoBloom:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 34,
                palette: DriftPalette(
                    primary:      Color(red: 0.75, green: 0.45, blue: 1.00),
                    secondary:    Color(red: 0.35, green: 0.80, blue: 1.00),
                    tertiary:     Color(red: 1.00, green: 0.55, blue: 0.60),
                    backgroundTop:    Color(red: 0.03, green: 0.02, blue: 0.08),
                    backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.05)
                )
            )

        case .cosmicHeart:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 20,
                palette: DriftPalette(
                    primary:      Color(red: 1.00, green: 0.45, blue: 0.78),
                    secondary:    Color(red: 0.35, green: 0.85, blue: 1.00),
                    tertiary:     Color(red: 0.85, green: 0.85, blue: 1.00),
                    backgroundTop:    Color(red: 0.04, green: 0.01, blue: 0.10),
                    backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.06)
                )
            )

        case .signalDrift:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 26,
                palette: DriftPalette(
                    primary:      Color(red: 0.40, green: 0.98, blue: 0.55),
                    secondary:    Color(red: 0.25, green: 0.85, blue: 0.98),
                    tertiary:     Color(red: 0.75, green: 0.45, blue: 0.98),
                    backgroundTop:    Color(red: 0.00, green: 0.05, blue: 0.10),
                    backgroundBottom: Color(red: 0.00, green: 0.02, blue: 0.06)
                )
            )

        case .horizonPulse:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 30,
                palette: DriftPalette(
                    primary:      Color(red: 0.55, green: 0.75, blue: 1.00),
                    secondary:    Color(red: 0.85, green: 0.85, blue: 1.00),
                    tertiary:     Color(red: 0.35, green: 0.55, blue: 0.95),
                    backgroundTop:    Color(red: 0.02, green: 0.03, blue: 0.08),
                    backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.05)
                )
            )

        case .photonRain:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 18,
                palette: DriftPalette(
                    primary:      Color(red: 0.45, green: 0.95, blue: 0.90),
                    secondary:    Color(red: 0.30, green: 0.60, blue: 1.00),
                    tertiary:     Color(red: 0.85, green: 0.95, blue: 1.00),
                    backgroundTop:    Color(red: 0.00, green: 0.02, blue: 0.06),
                    backgroundBottom: Color(red: 0.00, green: 0.00, blue: 0.03)
                )
            )

        case .gravityRings:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 36,
                palette: DriftPalette(
                    primary:      Color(red: 0.75, green: 0.80, blue: 1.00),
                    secondary:    Color(red: 0.45, green: 0.55, blue: 0.95),
                    tertiary:     Color(red: 0.95, green: 0.95, blue: 1.00),
                    backgroundTop:    Color(red: 0.03, green: 0.03, blue: 0.09),
                    backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.05)
                )
            )

        case .driftGrid:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 26,
                palette: DriftPalette(
                    primary:      Color(red: 0.55, green: 0.85, blue: 0.95),
                    secondary:    Color(red: 0.35, green: 0.65, blue: 0.90),
                    tertiary:     Color(red: 0.85, green: 0.95, blue: 1.00),
                    backgroundTop:    Color(red: 0.01, green: 0.03, blue: 0.08),
                    backgroundBottom: Color(red: 0.00, green: 0.01, blue: 0.04)
                )
            )

        case .quietSignal:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 40,
                palette: DriftPalette(
                    primary:      Color(red: 0.85, green: 0.90, blue: 1.00),
                    secondary:    Color(red: 0.65, green: 0.70, blue: 0.95),
                    tertiary:     Color(red: 0.95, green: 0.95, blue: 1.00),
                    backgroundTop:    Color(red: 0.02, green: 0.02, blue: 0.06),
                    backgroundBottom: Color(red: 0.00, green: 0.00, blue: 0.03)
                )
            )

        case .chromaticSpine:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 34,
                palette: DriftPalette(
                    primary:      Color(red: 0.35, green: 0.95, blue: 0.88),
                    secondary:    Color(red: 0.82, green: 0.40, blue: 1.00),
                    tertiary:     Color(red: 0.55, green: 0.75, blue: 1.00),
                    backgroundTop:    Color(red: 0.02, green: 0.03, blue: 0.08),
                    backgroundBottom: Color(red: 0.00, green: 0.01, blue: 0.04)
                )
            )

        case .ribbonOrbit:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 30,
                palette: DriftPalette(
                    primary:      Color(red: 0.75, green: 0.45, blue: 1.00),
                    secondary:    Color(red: 0.25, green: 0.85, blue: 0.98),
                    tertiary:     Color(red: 1.00, green: 0.55, blue: 0.85),
                    backgroundTop:    Color(red: 0.02, green: 0.02, blue: 0.07),
                    backgroundBottom: Color(red: 0.00, green: 0.00, blue: 0.03)
                )
            )

        case .inkTopography:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 40,
                palette: DriftPalette(
                    primary:      Color(red: 0.85, green: 0.90, blue: 1.00),
                    secondary:    Color(red: 0.65, green: 0.70, blue: 0.95),
                    tertiary:     Color(red: 0.95, green: 0.55, blue: 0.60),
                    backgroundTop:    Color(red: 0.02, green: 0.03, blue: 0.08),
                    backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.05)
                )
            )

        case .prismShards:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 26,
                palette: DriftPalette(
                    primary:      Color(red: 0.55, green: 0.85, blue: 0.95),
                    secondary:    Color(red: 0.75, green: 0.45, blue: 1.00),
                    tertiary:     Color(red: 1.00, green: 0.55, blue: 0.60),
                    backgroundTop:    Color(red: 0.03, green: 0.01, blue: 0.08),
                    backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.04)
                )
            )

        case .lissajousBloom:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 32,
                palette: DriftPalette(
                    primary:      Color(red: 0.35, green: 0.80, blue: 1.00),
                    secondary:    Color(red: 0.85, green: 0.40, blue: 1.00),
                    tertiary:     Color(red: 0.35, green: 0.95, blue: 0.88),
                    backgroundTop:    Color(red: 0.02, green: 0.02, blue: 0.06),
                    backgroundBottom: Color(red: 0.00, green: 0.00, blue: 0.03)
                )
            )

        case .meridianArcs:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 36,
                palette: DriftPalette(
                    primary:      Color(red: 0.55, green: 0.75, blue: 1.00),
                    secondary:    Color(red: 0.45, green: 0.95, blue: 0.90),
                    tertiary:     Color(red: 0.95, green: 0.95, blue: 1.00),
                    backgroundTop:    Color(red: 0.01, green: 0.02, blue: 0.06),
                    backgroundBottom: Color(red: 0.00, green: 0.00, blue: 0.03)
                )
            )

        case .spectralLoom:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 28,
                palette: DriftPalette(
                    primary:      Color(red: 0.40, green: 0.98, blue: 0.55),
                    secondary:    Color(red: 0.25, green: 0.85, blue: 0.98),
                    tertiary:     Color(red: 0.75, green: 0.45, blue: 0.98),
                    backgroundTop:    Color(red: 0.00, green: 0.04, blue: 0.08),
                    backgroundBottom: Color(red: 0.00, green: 0.01, blue: 0.04)
                )
            )

        case .voxelMirage:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 24,
                palette: DriftPalette(
                    primary:      Color(red: 0.85, green: 0.95, blue: 1.00),
                    secondary:    Color(red: 0.55, green: 0.65, blue: 1.00),
                    tertiary:     Color(red: 0.25, green: 0.95, blue: 0.85),
                    backgroundTop:    Color(red: 0.02, green: 0.04, blue: 0.10),
                    backgroundBottom: Color(red: 0.00, green: 0.00, blue: 0.05)
                )
            )

        case .haloInterference:
            return DriftModeConfig(
                id: self,
                displayName: displayName,
                cycleDuration: 42,
                palette: DriftPalette(
                    primary:      Color(red: 0.35, green: 0.85, blue: 1.00),
                    secondary:    Color(red: 1.00, green: 0.55, blue: 0.85),
                    tertiary:     Color(red: 0.75, green: 0.80, blue: 1.00),
                    backgroundTop:    Color(red: 0.02, green: 0.01, blue: 0.08),
                    backgroundBottom: Color(red: 0.00, green: 0.00, blue: 0.03)
                )
            )
        }
    }
}

struct DriftModeConfig: Identifiable, Equatable {
    let id: DriftMode
    let displayName: String
    let cycleDuration: TimeInterval
    let palette: DriftPalette
}
