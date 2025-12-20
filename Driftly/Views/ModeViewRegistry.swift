import SwiftUI

/// Central registry for mapping `DriftMode` to its SwiftUI view builder.
enum ModeViewRegistry {
    static let builders: [DriftMode: (DriftModeConfig) -> AnyView] = [
        .nebulaLake: { AnyView(NebulaLakeView(config: $0)) },
        .cosmicTide: { AnyView(CosmicTideView(config: $0)) },
        .auroraVeil: { AnyView(AuroraVeilView(config: $0)) },
        .abyssGlow: { AnyView(AbyssGlowView(config: $0)) },
        .starlitMist: { AnyView(StarlitMistView(config: $0)) },
        .lunarDrift: { AnyView(LunarDriftView(config: $0)) },
        .solarBloom: { AnyView(SolarBloomView(config: $0)) },
        .plasmaReef: { AnyView(PlasmaReefView(config: $0)) },
        .velvetEclipse: { AnyView(VelvetEclipseView(config: $0)) },
        .neonKelp: { AnyView(NeonKelpView(config: $0)) },
        .emberDrift: { AnyView(EmberDriftView(config: $0)) },
        .pulseAurora: { AnyView(PulseAuroraView(config: $0)) },
        .vitalWave: { AnyView(VitalWaveView(config: $0)) },
        .echoBloom: { AnyView(EchoBloomView(config: $0)) },
        .cosmicHeart: { AnyView(CosmicHeartView(config: $0)) },
        .signalDrift: { AnyView(SignalDriftView(config: $0)) },
        .horizonPulse: { AnyView(HorizonPulseView(config: $0)) },
        .photonRain: { AnyView(PhotonRainView(config: $0)) },
        .gravityRings: { AnyView(GravityRingsView(config: $0)) },
        .driftGrid: { AnyView(DriftGridView(config: $0)) },
        .quietSignal: { AnyView(QuietSignalView(config: $0)) },
        .chromaticSpine: { AnyView(ChromaticSpineView(config: $0)) },
        .ribbonOrbit: { AnyView(RibbonOrbitView(config: $0)) },
        .inkTopography: { AnyView(InkTopographyView(config: $0)) },
        .prismShards: { AnyView(PrismShardsView(config: $0)) },
        .lissajousBloom: { AnyView(LissajousBloomView(config: $0)) },
        .meridianArcs: { AnyView(MeridianArcsView(config: $0)) },
        .spectralLoom: { AnyView(SpectralLoomView(config: $0)) },
        .voxelMirage: { AnyView(VoxelMirageView(config: $0)) },
        .haloInterference: { AnyView(HaloInterferenceView(config: $0)) }
    ]

    @ViewBuilder
    static func view(for mode: DriftMode) -> some View {
        if let builder = builders[mode] {
            builder(mode.config)
        } else {
            Color.black
        }
    }
}
