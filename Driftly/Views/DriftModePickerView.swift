import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DriftModePickerView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .inactive
    @State private var isSceneEditorPresented = false
    @State private var sceneEditorSelection: Set<DriftMode> = []
    @State private var sceneEditorName: String = ""
    @State private var editingSceneID: UUID?
#if os(tvOS)
    @State private var showFavoritesOnly: Bool = false
    @FocusState private var focusedMode: DriftMode?
#endif

    @ViewBuilder
    private var scenesSection: some View {
        Section("Scenes") {
            if engine.availableScenes.isEmpty {
                Text("Capture a set of modes and settings as a Scene.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(engine.availableScenes) { scene in
                    SceneRow(
                        scene: scene,
                        isActive: engine.activeSceneID == scene.id,
                        onActivate: { engine.activateScene(id: scene.id) },
                        onEdit: { beginEditing(scene) },
                        onDelete: { engine.deleteScene(id: scene.id) }
                    )
                }
            }

            Button {
                beginNewScene()
            } label: {
                Label("New Scene", systemImage: "plus")
            }
            .accessibilityIdentifier("newSceneButton")
        }
    }

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
                scenesSection

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
                    ShareLink(item: AppShare.appStoreURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("modePickerShareButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isSceneEditorPresented) {
            SceneEditorView(
                name: $sceneEditorName,
                selection: $sceneEditorSelection,
                allModes: engine.modePickerModes,
                isEditing: editingSceneID != nil,
                onSave: {
                    let ordered = engine.modeDisplayOrder.filter { sceneEditorSelection.contains($0) }
                    if let editingSceneID {
                        engine.updateScene(id: editingSceneID, name: sceneEditorName, modeIDs: ordered)
                        if engine.activeSceneID == editingSceneID {
                            engine.activateScene(id: editingSceneID)
                        }
                    } else {
                        engine.createScene(name: sceneEditorName, modeIDs: ordered)
                    }
                    isSceneEditorPresented = false
                    editingSceneID = nil
                },
                onCancel: {
                    isSceneEditorPresented = false
                    editingSceneID = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
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
                    if !engine.availableScenes.isEmpty {
                        Section("Scenes") {
                            ForEach(engine.availableScenes) { scene in
                                Button {
                                    engine.activateScene(id: scene.id)
                                } label: {
                                    HStack {
                                        Text(scene.name)
                                            .font(.title3.weight(.semibold))
                                        Spacer()
                                        if engine.activeSceneID == scene.id {
                                            Image(systemName: "checkmark")
                                                .font(.title3.weight(.semibold))
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }

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
                FocusAdaptiveText(text: mode.displayName)
                    .font(.title3.weight(.semibold))

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

    private struct FocusAdaptiveText: View {
        let text: String
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Text(text)
                .foregroundStyle(isFocused ? Color.black : Color.white)
        }
    }
#endif

    private func beginNewScene() {
        sceneEditorName = "Scene \(engine.availableScenes.count + 1)"
        sceneEditorSelection = Set(engine.modeDisplayOrder)
        editingSceneID = nil
        isSceneEditorPresented = true
    }

    private func beginEditing(_ scene: DriftScene) {
        sceneEditorName = scene.name
        sceneEditorSelection = Set(scene.modeIDs)
        editingSceneID = scene.id
        isSceneEditorPresented = true
    }
}

// MARK: - Existing row view (as in your codebase)
#if !os(tvOS)
private struct SceneEditorView: View {
    @Binding var name: String
    @Binding var selection: Set<DriftMode>
    let allModes: [DriftMode]
    let isEditing: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    private func binding(for mode: DriftMode) -> Binding<Bool> {
        Binding {
            selection.contains(mode)
        } set: { newValue in
            if newValue {
                selection.insert(mode)
            } else {
                selection.remove(mode)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Scene name", text: $name)
                }

                Section("Modes") {
                    ForEach(allModes) { mode in
                        Toggle(mode.displayName, isOn: binding(for: mode))
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Scene" : "New Scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selection.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SceneRow: View {
    let scene: DriftScene
    let isActive: Bool
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            onActivate()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.name)
                        .font(.headline)
                    Text("\(scene.modeIDs.count) modes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }
}

private struct ModeRow: View {
    let mode: DriftMode
    let isSelected: Bool
    let isFavorite: Bool
    let onTap: () -> Void
    let favoriteAction: () -> Void

    var body: some View {
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
            .buttonStyle(.borderless)
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
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityIdentifier("modeRow-\(mode.rawValue)")
    }
}
#endif
