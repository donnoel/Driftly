import SwiftUI

// A reusable color palette for each mode
struct DriftPalette: Equatable {
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let backgroundTop: Color
    let backgroundBottom: Color
}

enum DriftMode: String, CaseIterable, Identifiable {
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
        }
    }
}

struct DriftModeConfig: Identifiable, Equatable {
    let id: DriftMode
    let displayName: String
    let cycleDuration: TimeInterval
    let palette: DriftPalette
}
