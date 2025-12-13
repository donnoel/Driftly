import SwiftUI

struct DriftModePickerView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(engine.allModes) { mode in
                        let isFavorite = engine.favoriteModes.contains(mode)
                        ModeRow(
                            mode: mode,
                            isSelected: mode == engine.currentMode,
                            favoriteAction: {
                                engine.toggleFavorite(mode)
                            },
                            isFavorite: isFavorite,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.45)) {
                                    engine.currentMode = mode
                                }
                                dismiss()
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Select Mode")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ModeRow: View {
    let mode: DriftMode
    let isSelected: Bool
    let favoriteAction: () -> Void
    let isFavorite: Bool
    let onTap: () -> Void

    private var config: DriftModeConfig {
        mode.config
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Thumbnail
                ModeThumbnail(palette: config.palette)

                VStack(alignment: .leading, spacing: 4) {
                    Text(config.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Button(action: favoriteAction) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isFavorite ? .yellow : .white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("favorite-\(mode.rawValue)")

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        Color.white.opacity(isSelected ? 0.08 : 0.03)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                Color.white.opacity(isSelected ? 0.35 : 0.08),
                                lineWidth: isSelected ? 1.2 : 0.6
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("modeRow-\(mode.rawValue)")
    }

    private var description: String {
        switch mode {
        case .nebulaLake:
            return "Calm cosmic water glow"
        case .cosmicTide:
            return "Flowing color wave bands"
        case .auroraVeil:
            return "Curtains of aurora light"
        case .abyssGlow:
            return "Deep-ocean shafts and vents"
        case .starlitMist:
            return "Soft starfield and mist"
        case .lunarDrift:
            return "Moonlight and gentle haze"
        case .solarBloom:
            return "Warm solar petals and soft glow"
        case .plasmaReef:
            return "Neon reef currents and plasma fog"
        case .velvetEclipse:
            return "Deep velvet shadows with electric edges"
        case .neonKelp:
            return "Lush neon greens drifting in blue"
        case .emberDrift:
            return "Smoldering embers in slow motion"
        case .pulseAurora:
            return "Gentle aurora with a living pulse"
        case .vitalWave:
            return "Slow biological wave motion"
        case .echoBloom:
            return "Blooming light with rhythmic echoes"
        case .cosmicHeart:
            return "A calm, cosmic heartbeat"
        case .signalDrift:
            return "Soft signal waves drifting through space"
        case .horizonPulse:
            return "Slow cinematic horizon bands"
        case .photonRain:
            return "Endless falling light streaks"
        case .gravityRings:
            return "Breathing concentric energy rings"
        case .driftGrid:
            return "Warped spatial light grid"
        case .quietSignal:
            return "Minimal waveform and noise field"
        }
    }
}

private struct ModeThumbnail: View {
    let palette: DriftPalette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.backgroundTop,
                            palette.backgroundBottom
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.primary.opacity(0.95),
                            palette.secondary.opacity(0.8),
                            palette.tertiary.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(3)
                .blur(radius: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        }
        .frame(width: 52, height: 36)
        .compositingGroup()
        .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3)
    }
}
