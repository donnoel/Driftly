import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DriftModePickerView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .inactive
#if os(tvOS)
    @State private var showFavoritesOnly: Bool = false
    @FocusState private var focusedMode: DriftMode?
#endif

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

#if os(tvOS)
    // MARK: - tvOS (Apple-style screen)

    private var tvWindow: some View {
        let favorites = engine.modePickerModes.filter { engine.favoriteModes.contains($0) }
        let nonFavorites = engine.modePickerModes.filter { !engine.favoriteModes.contains($0) }

        return ZStack {
            Color.black.ignoresSafeArea()

            NavigationStack {
                List {
                    // Filter row
                    Section {
                        Picker("Filter", selection: $showFavoritesOnly) {
                            Text("All").tag(false)
                            Text("Favorites").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 6)
                    }

                    if showFavoritesOnly {
                        Section {
                            ForEach(favorites) { mode in
                                tvModeRow(mode)
                            }
                        } header: {
                            Text("Favorites")
                        } footer: {
                            Text("Tip: Press Play/Pause to add or remove a favorite.")
                        }
                    } else {
                        if !favorites.isEmpty {
                            Section {
                                ForEach(favorites) { mode in
                                    tvModeRow(mode)
                                }
                            } header: {
                                Text("Favorites")
                            } footer: {
                                Text("Tip: Press Play/Pause to add or remove a favorite.")
                            }
                        }

                        Section {
                            ForEach(nonFavorites) { mode in
                                tvModeRow(mode)
                            }
                        } header: {
                            Text("All Modes")
                        }
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 72)
                .navigationTitle("Select Mode")
                .tint(.white)
                .onAppear {
                    // Keep List backgrounds consistently dark on tvOS for legibility.
                    UITableView.appearance().backgroundColor = .black
                    UITableViewCell.appearance().backgroundColor = .black
                }
            }
        }
        .onPlayPauseCommand {
            // tvOS-native secondary action: toggle favorite on the currently focused row.
            if let focusedMode {
                engine.toggleFavorite(focusedMode)
            }
        }
        .onExitCommand { dismiss() }
        .preferredColorScheme(.dark)
    }

    private func tvModeRow(_ mode: DriftMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.45)) {
                engine.currentMode = mode
            }
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Text(mode.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if engine.favoriteModes.contains(mode) {
                    Image(systemName: "star.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.yellow.opacity(0.92))
                        .accessibilityLabel("Favorite")
                }

                if mode == engine.currentMode {
                    Image(systemName: "checkmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .accessibilityLabel("Selected")
                }
            }
            .padding(.vertical, 8)
        }
        .focused($focusedMode, equals: mode)
        // Keep favorites available without adding a second focusable control in the row.
        .contextMenu {
            Button {
                engine.toggleFavorite(mode)
            } label: {
                Label(
                    engine.favoriteModes.contains(mode) ? "Remove Favorite" : "Add Favorite",
                    systemImage: engine.favoriteModes.contains(mode) ? "star.slash" : "star"
                )
            }
        }
        .accessibilityIdentifier("mode-\(mode.rawValue)")
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
