import SwiftUI

struct DriftModePickerView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .inactive

    var body: some View {
        #if os(tvOS)
        tvWindow
        #else
        iosPicker
        #endif
    }

    // MARK: - iOS (unchanged behavior)
#if !os(tvOS)
    private var iosPicker: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(engine.modePickerModes) { mode in
                        let isFavorite = engine.favoriteModes.contains(mode)
                        ModeRow(
                            mode: mode,
                            isSelected: mode == engine.currentMode,
                            isFavorite: isFavorite,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.45)) {
                                    engine.currentMode = mode
                                }
                                dismiss()
                            },
                            favoriteAction: {
                                engine.toggleFavorite(mode)
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.black)
                    }
                    .onMove { indices, newOffset in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            engine.reorderModes(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("modePickerSheet")
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Select Mode")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .accessibilityIdentifier("modePickerEditButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
#endif

    // MARK: - tvOS windowed panel (no Done button)

    private var tvWindow: some View {
        ZStack {
            Color.black.opacity(0.70).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Select Mode")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("Press Menu to close")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.65))
                }

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(engine.modePickerModes) { mode in
                            tvRow(for: mode)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(36)
            .frame(maxWidth: 1040, maxHeight: 760)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.50), radius: 40, x: 0, y: 18)
            .padding(.horizontal, 40)
        }
        .preferredColorScheme(.dark)
    }

#if os(tvOS)
private func tvRow(for mode: DriftMode) -> some View {
    TvModeRow(
        mode: mode,
        isSelected: mode == engine.currentMode,
        isFavorite: engine.favoriteModes.contains(mode),
        onToggleFavorite: { engine.toggleFavorite(mode) },
        onSelect: {
            withAnimation(.easeInOut(duration: 0.45)) {
                engine.currentMode = mode
            }
            dismiss()
        }
    )
}
#else
private func tvRow(for mode: DriftMode) -> some View {
    EmptyView()
}
#endif

#if os(tvOS)
    private struct TvModeRow: View {
        let mode: DriftMode
        let isSelected: Bool
        let isFavorite: Bool
        let onToggleFavorite: () -> Void
        let onSelect: () -> Void

        var body: some View {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isFavorite ? Color.yellow : Color.white.opacity(0.75))
                        .frame(width: 54, height: 54)
                }
                .buttonStyle(.bordered)
                .tint(Color.white.opacity(0.12))
                .accessibilityLabel(isFavorite ? "Unfavorite" : "Favorite")

                Button(action: onSelect) {
                    HStack(spacing: 10) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                        }
                        Text(isSelected ? "Selected" : "Select")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .frame(minWidth: 140, minHeight: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(isSelected ? Color.white.opacity(0.20) : Color.white.opacity(0.15))
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.10), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
        }
    }
#endif
}

// MARK: - Existing row view (as in your codebase)
#if !os(tvOS)
private struct ModeRow: View {
    let mode: DriftMode
    let isSelected: Bool
    let isFavorite: Bool
    let onTap: () -> Void
    let favoriteAction: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Spacer()

                Button(action: favoriteAction) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isFavorite ? .yellow : .white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Unfavorite" : "Favorite")
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
                    .fill(Color.white.opacity(isSelected ? 0.10 : 0.06))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("modeRow-\(mode.rawValue)")
    }
}
#endif
