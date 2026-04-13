import Foundation

enum DriftModeBrowseSection: String, CaseIterable, Identifiable {
    case signature
    case secondary
    case labs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signature:
            return "Signature"
        case .secondary:
            return "Secondary"
        case .labs:
            return "Labs"
        }
    }

    var subtitle: String {
        switch self {
        case .signature:
            return "Core Driftly experiences."
        case .secondary:
            return "Polished alternates."
        case .labs:
            return "Experimental and extra modes."
        }
    }
}

struct DriftModePresentation: Identifiable, Equatable {
    let mode: DriftMode
    let section: DriftModeBrowseSection
    let descriptor: String

    var id: DriftMode { mode }
}

enum DriftModePresentationCatalog {
    static let signatureModes: [DriftMode] = [
        .auroraVeil,
        .lunarDrift,
        .velvetEclipse,
        .nebulaLake,
        .starlitMist,
        .cosmicTide,
        .gravityRings,
        .ribbonOrbit,
        .meridianArcs,
        .quietSignal
    ]

    static let secondaryModes: [DriftMode] = [
        .solarBloom,
        .emberDrift,
        .pulseAurora,
        .photonRain
    ]

    private static let curatedModes = Set(signatureModes + secondaryModes)

    static func section(for mode: DriftMode) -> DriftModeBrowseSection {
        if signatureModes.contains(mode) {
            return .signature
        }
        if secondaryModes.contains(mode) {
            return .secondary
        }
        return .labs
    }

    static func descriptor(for mode: DriftMode) -> String {
        switch mode {
        case .auroraVeil:
            return "Silk aurora ribbons."
        case .lunarDrift:
            return "Moonlit, slow phase drift."
        case .velvetEclipse:
            return "Deep gradient eclipse bloom."
        case .nebulaLake:
            return "Glassy nebula calm."
        case .starlitMist:
            return "Soft starfield haze."
        case .cosmicTide:
            return "Color tide pulse."
        case .gravityRings:
            return "Orbital ring resonance."
        case .ribbonOrbit:
            return "Layered orbital ribbons."
        case .meridianArcs:
            return "Arc sweeps and contour flow."
        case .quietSignal:
            return "Low-noise signal shimmer."
        case .solarBloom:
            return "Warm spectrum bloom."
        case .emberDrift:
            return "Ember trails and glow."
        case .pulseAurora:
            return "Rhythmic aurora pulse."
        case .photonRain:
            return "Luminous streak rainfall."
        case .abyssGlow:
            return "Experimental depth glow."
        case .plasmaReef:
            return "Experimental plasma reef."
        case .neonKelp:
            return "Experimental kelp motion."
        case .vitalWave:
            return "Experimental energy wave."
        case .echoBloom:
            return "Experimental bloom echoes."
        case .cosmicHeart:
            return "Experimental heart pulse."
        case .signalDrift:
            return "Experimental signal weave."
        case .horizonPulse:
            return "Experimental horizon pulse."
        case .driftGrid:
            return "Experimental grid drift."
        case .chromaticSpine:
            return "Experimental chroma spine."
        case .inkTopography:
            return "Experimental fluid contours."
        case .prismShards:
            return "Experimental prism shards."
        case .lissajousBloom:
            return "Experimental harmonic bloom."
        case .spectralLoom:
            return "Experimental spectral weave."
        case .voxelMirage:
            return "Experimental voxel mirage."
        case .haloInterference:
            return "Experimental halo field."
        }
    }

    static func presentations(
        from orderedModes: [DriftMode],
        section: DriftModeBrowseSection
    ) -> [DriftModePresentation] {
        modes(in: orderedModes, section: section).map {
            DriftModePresentation(
                mode: $0,
                section: section,
                descriptor: descriptor(for: $0)
            )
        }
    }

    private static func modes(
        in orderedModes: [DriftMode],
        section: DriftModeBrowseSection
    ) -> [DriftMode] {
        let available = Set(orderedModes)
        switch section {
        case .signature:
            return signatureModes.filter { available.contains($0) }
        case .secondary:
            return secondaryModes.filter { available.contains($0) }
        case .labs:
            return orderedModes.filter { !curatedModes.contains($0) }
        }
    }
}
