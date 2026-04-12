import SwiftUI
import Combine
import Foundation

protocol UbiquitousKeyValueStoring: AnyObject {
    func array(forKey: String) -> [Any]?
    func data(forKey: String) -> Data?
    func set(_ value: Any?, forKey: String)
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: UbiquitousKeyValueStoring {}

private enum DriftlyDefaultsKey {
    static let currentMode           = "driftly.currentMode"
    static let animationSpeed        = "driftly.animationSpeed"
    static let respectReduceMotion   = "driftly.respectReduceMotion"
    static let preventAutoLock       = "driftly.preventAutoLock"
    static let isChromeVisible       = "driftly.isChromeVisible"
    static let brightness            = "driftly.brightness"
    static let autoDriftEnabled      = "driftly.autoDriftEnabled"
    static let autoDriftIntervalMins = "driftly.autoDriftIntervalMins"
    static let autoDriftShuffle      = "driftly.autoDriftShuffle"
    static let favoriteModes         = "driftly.favoriteModes"
    static let modeDisplayOrder      = "driftly.modeDisplayOrder"
    static let labsFeaturesEnabled   = "driftly.labsFeaturesEnabled"
    static let clockEnabled          = "driftly.clockEnabled"
    static let autoDriftSource       = "driftly.autoDriftSource"
    static let scenes                = "driftly.scenes"
    static let activeSceneID         = "driftly.activeSceneID"
    static let legacyAutoDriftFavoritesOnly = "driftly.autoDriftFavoritesOnly"
}

struct DriftSceneSettings: Codable, Equatable {
    var brightness: Double
    var animationSpeed: Double
    var clockEnabled: Bool
    var preventAutoLock: Bool
    var autoDriftEnabled: Bool
    var autoDriftIntervalMinutes: Int
    var autoDriftShuffleEnabled: Bool
}

struct DriftScene: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var modeIDs: [DriftMode]
    var lastModeID: DriftMode?
    var settings: DriftSceneSettings
    var updatedAt: Date
    var deletedAt: Date?
}

enum AutoDriftSource: Equatable, Hashable {
    case all
    case favorites
    case scene(UUID)
}

extension AutoDriftSource: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case id
    }

    private enum Kind: String, Codable {
        case all
        case favorites
        case scene
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .all:
            self = .all
        case .favorites:
            self = .favorites
        case .scene:
            let id = try container.decode(UUID.self, forKey: .id)
            self = .scene(id)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all:
            try container.encode(Kind.all, forKey: .type)
        case .favorites:
            try container.encode(Kind.favorites, forKey: .type)
        case .scene(let id):
            try container.encode(Kind.scene, forKey: .type)
            try container.encode(id, forKey: .id)
        }
    }
}

final class DriftlyEngine: ObservableObject {
    // MARK: - Published state

    private let defaults: UserDefaults
    private let ubiquitousStore: UbiquitousKeyValueStoring?
    private let ubiquitousQueue = DispatchQueue(label: "com.driftly.ubiquitous", qos: .utility)
    private var ubiquitousObserver: NSObjectProtocol?
    private var applyingCloudFavorites = false
    private var applyingCloudScenes = false
    private var applyingScene = false
    private var scenesCloudPushWorkItem: DispatchWorkItem?
    private var scenesPersistWorkItem: DispatchWorkItem?
    private var isInitializing = true
    private let persistenceQueue = DispatchQueue(label: "com.driftly.persistence", qos: .utility)
    private static let isTvOSPlatform: Bool = {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }()

    @Published var currentMode: DriftMode {
        didSet {
            persistCurrentMode()
            updateActiveSceneFromState(updateMode: true, updateSettings: false)
        }
    }

    @Published var isChromeVisible: Bool {
        didSet { persistChromeVisibility() }
    }

    /// 1.0 = normal speed, 0.5 = slower, 1.5 = faster
    @Published var animationSpeed: Double {
        didSet {
            persistAnimationSpeed()
            updateActiveSceneFromState()
        }
    }

    /// Whether to honor the system Reduce Motion setting for animation speed scaling.
    @Published var respectSystemReduceMotion: Bool {
        didSet {
            persistRespectReduceMotion()
        }
    }

    /// When true, Driftly will try to prevent auto-lock while active
    @Published var preventAutoLock: Bool {
        didSet {
            persistPreventAutoLock()
            updateActiveSceneFromState()
        }
    }

    /// 0.2 (dim) ... 1.0 (full brightness)
    @Published private var brightnessStorage: Double
    var brightness: Double {
        get { brightnessStorage }
        set { applyBrightness(newValue) }
    }

    /// Feature gate for experimental toggles (per-device)
    @Published var labsFeaturesEnabled: Bool {
        didSet {
            guard !isInitializing else { return }
            persistLabsFeaturesEnabled()
            enforceAutoDriftConstraints()
        }
    }

    /// Auto-drift: whether Driftly should automatically change modes
    @Published var autoDriftEnabled: Bool {
        didSet {
            if autoDriftEnabled && !isAutoDriftAllowed {
                autoDriftEnabled = false
                return
            }
            persistAutoDriftEnabled()
            updateActiveSceneFromState()
        }
    }

    /// Whether auto-drift should use a shuffled order.
    @Published var autoDriftShuffleEnabled: Bool {
        didSet {
            persistAutoDriftShuffle()
            updateActiveSceneFromState()
        }
    }

    /// Auto-drift interval in minutes
    @Published var autoDriftIntervalMinutes: Int {
        didSet {
            persistAutoDriftInterval()
            updateActiveSceneFromState()
        }
    }

    /// Auto-drift source (all, favorites, or an active scene)
    @Published var autoDriftSource: AutoDriftSource {
        didSet {
            guard !isInitializing else { return }
            let validated = Self.validated(source: autoDriftSource, scenes: scenes)
            if validated != autoDriftSource {
                autoDriftSource = validated
                return
            }
            shuffleQueue.removeAll()
            persistAutoDriftSource()
        }
    }

    /// Favorited modes (set of raw values)
    @Published var favoriteModes: Set<DriftMode> {
        didSet { persistFavorites() }
    }

    /// When set, Driftly will fade out once this time is reached (not persisted across launches)
    @Published var sleepTimerEndDate: Date? = nil
    /// Whether to show the clock overlay
    @Published var clockEnabled: Bool {
        didSet {
            persistClockEnabled()
            updateActiveSceneFromState()
        }
    }

    var allModes: [DriftMode] {
        DriftMode.allCases
    }

    /// User-selected ordering for the mode picker UI (does not affect core mode list)
    @Published var modeDisplayOrder: [DriftMode] {
        didSet { persistModeDisplayOrder() }
    }

    /// User-defined scenes (playlists) with captured settings
    @Published var scenes: [DriftScene] {
        didSet {
            guard !isInitializing else { return }
            persistScenes()
            autoDriftSource = Self.validated(source: autoDriftSource, scenes: scenes)
            if let activeSceneID, scene(withID: activeSceneID) == nil {
                self.activeSceneID = nil
            }
        }
    }

    /// Currently active scene ID (nil when not using a scene)
    @Published var activeSceneID: UUID? {
        didSet {
            if activeSceneID == nil, case .scene = autoDriftSource {
                autoDriftSource = .all
            }
            persistActiveSceneID()
        }
    }

    // Non-persisted shuffle queue to ensure we traverse each candidate once before repeating.
    private var shuffleQueue: [DriftMode] = []

    var modePickerModes: [DriftMode] {
        modeDisplayOrder
    }

    // MARK: - Ubiquitous store helpers

    private func syncUbiquitousStoreAsync() {
        guard let ubiquitousStore else { return }
        if ubiquitousStore is NSUbiquitousKeyValueStore {
            ubiquitousQueue.async {
                _ = ubiquitousStore.synchronize()
            }
        } else {
            _ = ubiquitousStore.synchronize()
        }
    }

    private func writeToUbiquitousStoreAsync(_ work: @escaping (UbiquitousKeyValueStoring) -> Void) {
        guard let ubiquitousStore else { return }
        if ubiquitousStore is NSUbiquitousKeyValueStore {
            ubiquitousQueue.async {
                work(ubiquitousStore)
                _ = ubiquitousStore.synchronize()
            }
        } else {
            work(ubiquitousStore)
            _ = ubiquitousStore.synchronize()
        }
    }

    // MARK: - Init

    init(
        defaults: UserDefaults = .standard,
        ubiquitousStore: UbiquitousKeyValueStoring? = NSUbiquitousKeyValueStore.default
    ) {
        self.defaults = defaults
        self.ubiquitousStore = ubiquitousStore

        // currentMode
        if let raw = defaults.string(forKey: DriftlyDefaultsKey.currentMode),
           let mode = DriftMode(rawValue: raw) {
            currentMode = mode
        } else {
            currentMode = .nebulaLake
        }

        // isChromeVisible (default: true)
        if defaults.object(forKey: DriftlyDefaultsKey.isChromeVisible) != nil {
            isChromeVisible = defaults.bool(forKey: DriftlyDefaultsKey.isChromeVisible)
        } else {
            isChromeVisible = true
        }

        // animationSpeed (default: 0.6 = Gentle)
        let storedSpeed = defaults.double(forKey: DriftlyDefaultsKey.animationSpeed)
        let rawSpeed = storedSpeed == 0 ? 0.6 : storedSpeed
        // Clamp in case of legacy/corrupted values.
        animationSpeed = min(1.8, max(0.5, rawSpeed))

        // respectSystemReduceMotion (default: true)
        if defaults.object(forKey: DriftlyDefaultsKey.respectReduceMotion) != nil {
            respectSystemReduceMotion = defaults.bool(forKey: DriftlyDefaultsKey.respectReduceMotion)
        } else {
            respectSystemReduceMotion = true
        }

        // preventAutoLock (default: false)
        if defaults.object(forKey: DriftlyDefaultsKey.preventAutoLock) != nil {
            preventAutoLock = defaults.bool(forKey: DriftlyDefaultsKey.preventAutoLock)
        } else {
            preventAutoLock = false
        }

        // brightness (default: 1.0)
        let storedBrightness = defaults.double(forKey: DriftlyDefaultsKey.brightness)
        let initialBrightness = storedBrightness == 0 ? 1.0 : storedBrightness
        brightnessStorage = Self.clampBrightness(initialBrightness)

        // Labs features (default: false)
        if defaults.object(forKey: DriftlyDefaultsKey.labsFeaturesEnabled) != nil {
            labsFeaturesEnabled = defaults.bool(forKey: DriftlyDefaultsKey.labsFeaturesEnabled)
        } else {
            labsFeaturesEnabled = false
        }

        // autoDriftEnabled (default: false)
        if defaults.object(forKey: DriftlyDefaultsKey.autoDriftEnabled) != nil {
            autoDriftEnabled = defaults.bool(forKey: DriftlyDefaultsKey.autoDriftEnabled)
        } else {
            autoDriftEnabled = false
        }

        // autoDriftShuffleEnabled (default: false)
        if defaults.object(forKey: DriftlyDefaultsKey.autoDriftShuffle) != nil {
            autoDriftShuffleEnabled = defaults.bool(forKey: DriftlyDefaultsKey.autoDriftShuffle)
        } else {
            autoDriftShuffleEnabled = false
        }

        // autoDriftIntervalMinutes (default: 15)
        let storedInterval = defaults.integer(forKey: DriftlyDefaultsKey.autoDriftIntervalMins)
        if storedInterval == 0 {
            autoDriftIntervalMinutes = 15
        } else {
            autoDriftIntervalMinutes = max(1, storedInterval)
        }

        // favorites (default: empty)
        let storedFavorites: Set<DriftMode>
        if let stored = defaults.array(forKey: DriftlyDefaultsKey.favoriteModes) as? [String] {
            storedFavorites = Set(stored.compactMap(DriftMode.init(rawValue:)))
        } else {
            storedFavorites = []
        }
        favoriteModes = Self.initialFavorites(
            localFavorites: storedFavorites,
            ubiquitousStore: ubiquitousStore,
            defaults: defaults
        )

        // scenes (default: none)
        let storedScenes: [DriftScene]
        if let data = defaults.data(forKey: DriftlyDefaultsKey.scenes),
           let decoded = Self.decodeScenes(from: data) {
            storedScenes = decoded
        } else {
            storedScenes = []
        }
        let resolvedScenes = Self.initialScenes(
            localScenes: storedScenes,
            ubiquitousStore: ubiquitousStore,
            defaults: defaults
        )
        scenes = resolvedScenes

        // active scene (default: none)
        let storedActiveScene: UUID?
        if let rawID = defaults.string(forKey: DriftlyDefaultsKey.activeSceneID),
           let uuid = UUID(uuidString: rawID),
           resolvedScenes.contains(where: { $0.id == uuid && $0.deletedAt == nil }) {
            storedActiveScene = uuid
        } else {
            storedActiveScene = nil
        }
        activeSceneID = storedActiveScene

        // auto drift source (default: all), migrate old favorites-only toggle if present
        let storedSource: AutoDriftSource
        if let data = defaults.data(forKey: DriftlyDefaultsKey.autoDriftSource),
           let decoded = try? JSONDecoder().decode(AutoDriftSource.self, from: data) {
            storedSource = decoded
        } else if defaults.object(forKey: DriftlyDefaultsKey.legacyAutoDriftFavoritesOnly) != nil,
                  defaults.bool(forKey: DriftlyDefaultsKey.legacyAutoDriftFavoritesOnly) {
            storedSource = .favorites
        } else {
            storedSource = .all
        }
        autoDriftSource = storedSource

        // clock overlay (default: false)
        if defaults.object(forKey: DriftlyDefaultsKey.clockEnabled) != nil {
            clockEnabled = defaults.bool(forKey: DriftlyDefaultsKey.clockEnabled)
        } else {
            clockEnabled = false
        }

        // mode display order (default: all modes in their defined order)
        if let stored = defaults.array(forKey: DriftlyDefaultsKey.modeDisplayOrder) as? [String] {
            let storedModes = stored.compactMap(DriftMode.init(rawValue:))
            // Keep any new modes that shipped after the stored list
            let missing = DriftMode.allCases.filter { !storedModes.contains($0) }
            modeDisplayOrder = storedModes + missing
        } else {
            modeDisplayOrder = DriftMode.allCases
        }

        enforceAutoDriftConstraints()
        isInitializing = false

        // Re-validate the source now that initialization is complete.
        autoDriftSource = Self.validated(source: autoDriftSource, scenes: scenes)

        if let sceneID = activeSceneID,
           let scene = scenes.first(where: { $0.id == sceneID && $0.deletedAt == nil }) {
            applyScene(scene, setAutoDriftSource: autoDriftSource != .scene(sceneID))
        }

        startObservingUbiquitousStore()
        syncUbiquitousStoreAsync()
    }

    deinit {
        if let ubiquitousObserver {
            NotificationCenter.default.removeObserver(ubiquitousObserver)
        }
        scenesCloudPushWorkItem?.cancel()
        scenesPersistWorkItem?.cancel()
    }

    // MARK: - Public API

    func goToNextMode() {
        let modes = allModes
        guard let index = modes.firstIndex(of: currentMode) else {
            currentMode = modes.first ?? .nebulaLake
            return
        }
        let nextIndex = modes.index(after: index)
        currentMode = nextIndex < modes.endIndex ? modes[nextIndex] : modes.first ?? .nebulaLake
    }

    /// minutes = nil → turn timer off (not persisted)
    func setSleepTimer(minutes: Int?) {
        if let minutes {
            sleepTimerEndDate = Date().addingTimeInterval(Double(minutes) * 60.0)
        } else {
            sleepTimerEndDate = nil
        }
    }

    private func applyBrightness(_ value: Double) {
        let clamped = Self.clampBrightness(value)
        guard clamped != brightnessStorage else { return }
        brightnessStorage = clamped
        persistBrightness()
        updateActiveSceneFromState()
    }

    // MARK: - Persistence

    private func persistCurrentMode() {
        defaults.set(currentMode.rawValue, forKey: DriftlyDefaultsKey.currentMode)
    }

    var isAutoDriftAllowed: Bool {
        labsFeaturesEnabled
    }

    var isAutoDriftOperational: Bool {
        autoDriftEnabled && isAutoDriftAllowed
    }

    private func enforceAutoDriftConstraints() {
        if autoDriftEnabled && !isAutoDriftAllowed {
            autoDriftEnabled = false
        }
    }

    func shouldAutoDrift(
        now: Date,
        lastChange: Date,
        sleepTimerHasExpired: Bool
    ) -> Bool {
        guard isAutoDriftOperational, !sleepTimerHasExpired else { return false }

        let intervalMinutes = max(1, autoDriftIntervalMinutes)
        let intervalSeconds = Double(intervalMinutes * 60)
        let elapsed = now.timeIntervalSince(lastChange)

        return elapsed >= intervalSeconds
    }

    func nextAutoDriftMode(after current: DriftMode) -> DriftMode {
        let interval = DriftProfiling.begin(
            DriftProfiling.Signpost.autoDriftSelect,
            message: "source=\(autoDriftSourceName(autoDriftSource)) current=\(current.rawValue) shuffle=\(autoDriftShuffleEnabled)"
        )
        var selectedMode = current
        defer {
            DriftProfiling.end(
                DriftProfiling.Signpost.autoDriftSelect,
                interval,
                message: "source=\(autoDriftSourceName(autoDriftSource)) current=\(current.rawValue) selected=\(selectedMode.rawValue) shuffle=\(autoDriftShuffleEnabled)"
            )
        }

        if autoDriftShuffleEnabled {
            let pool = shuffleCandidatePool(current: current)
            selectedMode = nextShuffledMode(from: pool, current: current)
            return selectedMode
        }

        let modes = autoDriftCandidates(startingAt: current)
        guard let idx = modes.firstIndex(of: current) else {
            selectedMode = modes.first ?? .nebulaLake
            return selectedMode
        }

        let nextIndex = modes.index(after: idx)
        selectedMode = nextIndex < modes.endIndex ? modes[nextIndex] : modes.first ?? .nebulaLake
        return selectedMode
    }

    /// Returns the next auto-drift mode without advancing the shuffle queue.
    func peekNextAutoDriftMode(after current: DriftMode) -> DriftMode {
        if autoDriftShuffleEnabled {
            let pool = shuffleCandidatePool(current: current)
            return peekShuffledMode(from: pool, current: current)
        }

        let modes = autoDriftCandidates(startingAt: current)
        guard let idx = modes.firstIndex(of: current) else { return modes.first ?? .nebulaLake }

        let nextIndex = modes.index(after: idx)
        return nextIndex < modes.endIndex ? modes[nextIndex] : modes.first ?? .nebulaLake
    }

    func toggleFavorite(_ mode: DriftMode) {
        if favoriteModes.contains(mode) {
            favoriteModes.remove(mode)
        } else {
            favoriteModes.insert(mode)
        }
    }

    func reorderModes(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        modeDisplayOrder.move(fromOffsets: offsets, toOffset: destination)
    }

    var availableScenes: [DriftScene] {
        scenes
            .filter { $0.deletedAt == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @discardableResult
    func createScene(name: String, modeIDs: [DriftMode]) -> DriftScene {
        let normalizedModes = normalizedModeIDs(modeIDs)
        let scene = DriftScene(
            id: UUID(),
            name: name,
            modeIDs: normalizedModes.isEmpty ? modeDisplayOrder : normalizedModes,
            lastModeID: normalizedModes.contains(currentMode) ? currentMode : normalizedModes.first ?? currentMode,
            settings: currentSceneSettings(),
            updatedAt: Date(),
            deletedAt: nil
        )
        upsertScene(scene)
        applyScene(scene)
        return scene
    }

    func updateScene(id: UUID, name: String? = nil, modeIDs: [DriftMode]? = nil) {
        guard var scene = scene(withID: id, includeDeleted: true) else { return }
        if let name {
            scene.name = name
        }
        if let modeIDs {
            let normalized = normalizedModeIDs(modeIDs)
            scene.modeIDs = normalized.isEmpty ? scene.modeIDs : normalized
            if let last = scene.lastModeID, !scene.modeIDs.contains(last) {
                scene.lastModeID = scene.modeIDs.first
            }
        }
        scene.updatedAt = Date()
        upsertScene(scene)
    }

    func deleteScene(id: UUID) {
        guard var scene = scene(withID: id, includeDeleted: true) else { return }
        scene.deletedAt = Date()
        scene.updatedAt = Date()
        upsertScene(scene)
        if activeSceneID == id {
            activeSceneID = nil
            if case .scene = autoDriftSource {
                autoDriftSource = .all
            }
        }
    }

    func activateScene(id: UUID) {
        guard let scene = scene(withID: id) else { return }
        applyScene(scene)
    }

    private func applyScene(_ scene: DriftScene, setAutoDriftSource: Bool = true) {
        guard scene.deletedAt == nil else { return }
        var mutableScene = scene
        let targetMode: DriftMode = {
            if let last = scene.lastModeID, scene.modeIDs.contains(last) {
                return last
            }
            if let first = scene.modeIDs.first {
                return first
            }
            return currentMode
        }()
        let previousMode = currentMode
        let interval = DriftProfiling.begin(
            DriftProfiling.Signpost.sceneApply,
            message: "sceneID=\(scene.id.uuidString) from=\(previousMode.rawValue) target=\(targetMode.rawValue)"
        )
        defer {
            DriftProfiling.end(
                DriftProfiling.Signpost.sceneApply,
                interval,
                message: "sceneID=\(scene.id.uuidString) from=\(previousMode.rawValue) to=\(currentMode.rawValue)"
            )
        }

        applyingScene = true
        activeSceneID = scene.id
        brightness = Self.clampBrightness(scene.settings.brightness)
        animationSpeed = scene.settings.animationSpeed
        clockEnabled = scene.settings.clockEnabled
        preventAutoLock = scene.settings.preventAutoLock
        autoDriftEnabled = scene.settings.autoDriftEnabled
        autoDriftIntervalMinutes = max(1, scene.settings.autoDriftIntervalMinutes)
        autoDriftShuffleEnabled = scene.settings.autoDriftShuffleEnabled
        currentMode = targetMode
        applyingScene = false

        mutableScene.lastModeID = targetMode
        mutableScene.settings = currentSceneSettings()
        mutableScene.updatedAt = Date()
        upsertScene(mutableScene)

        if setAutoDriftSource {
            autoDriftSource = .scene(scene.id)
        }

        DriftProfiling.event(
            DriftProfiling.Signpost.modeTransition,
            message: "source=sceneActivation sceneID=\(scene.id.uuidString) from=\(previousMode.rawValue) to=\(currentMode.rawValue)"
        )
    }

    private func scene(withID id: UUID, includeDeleted: Bool = false) -> DriftScene? {
        scenes.first(where: { $0.id == id && (includeDeleted || $0.deletedAt == nil) })
    }

    private func upsertScene(_ scene: DriftScene) {
        if let idx = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[idx] = scene
        } else {
            scenes.append(scene)
        }
    }

    private func normalizedModeIDs(_ modes: [DriftMode]) -> [DriftMode] {
        var seen = Set<DriftMode>()
        var result: [DriftMode] = []
        for mode in modes {
            if DriftMode.allCases.contains(mode), !seen.contains(mode) {
                seen.insert(mode)
                result.append(mode)
            }
        }
        return result
    }

    private func currentSceneSettings() -> DriftSceneSettings {
        DriftSceneSettings(
            brightness: brightness,
            animationSpeed: animationSpeed,
            clockEnabled: clockEnabled,
            preventAutoLock: preventAutoLock,
            autoDriftEnabled: autoDriftEnabled,
            autoDriftIntervalMinutes: autoDriftIntervalMinutes,
            autoDriftShuffleEnabled: autoDriftShuffleEnabled
        )
    }

    private func updateActiveSceneFromState(updateMode: Bool = false, updateSettings: Bool = true) {
        guard !applyingScene else { return }
        guard let activeSceneID, var scene = scene(withID: activeSceneID, includeDeleted: true) else { return }
        var didChange = false
        if updateSettings {
            let settings = currentSceneSettings()
            if settings != scene.settings {
                scene.settings = settings
                didChange = true
            }
        }
        if updateMode {
            if scene.lastModeID != currentMode {
                scene.lastModeID = currentMode
                didChange = true
            }
        }
        if didChange {
            scene.updatedAt = Date()
            upsertScene(scene)
        }
    }

    private func autoDriftCandidates(startingAt current: DriftMode) -> [DriftMode] {
        switch autoDriftSource {
        case .all:
            return allModes
        case .favorites:
            let favoritesList = favoriteModes.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return favoritesList.isEmpty ? allModes : favoritesList
        case .scene(let id):
            guard let scene = scene(withID: id), scene.deletedAt == nil else {
                return allModes
            }
            let modes = scene.modeIDs.filter { mode in DriftMode.allCases.contains(mode) }
            return modes.isEmpty ? allModes : modes
        }
    }

    private func shuffleCandidatePool(current: DriftMode) -> [DriftMode] {
        autoDriftCandidates(startingAt: current)
    }

    private func nextShuffledMode(from candidates: [DriftMode], current: DriftMode) -> DriftMode {
        guard !candidates.isEmpty else { return current }

        shuffleQueue = preparedShuffleQueue(candidates: candidates, current: current)
        return shuffleQueue.isEmpty ? current : shuffleQueue.removeFirst()
    }

    private func peekShuffledMode(from candidates: [DriftMode], current: DriftMode) -> DriftMode {
        guard !candidates.isEmpty else { return current }

        let queue = preparedShuffleQueue(candidates: candidates, current: current)
        return queue.first ?? current
    }

    private func preparedShuffleQueue(candidates: [DriftMode], current: DriftMode) -> [DriftMode] {
        let candidateSet = Set(candidates)
        // Prune any stale entries and never keep the current mode in the queue.
        var queue = shuffleQueue.filter { candidateSet.contains($0) && $0 != current }

        if queue.isEmpty {
            queue = candidates.filter { $0 != current }.shuffled()
        }

        return queue
    }

    private func persistAnimationSpeed() {
        defaults.set(animationSpeed, forKey: DriftlyDefaultsKey.animationSpeed)
    }

    private func persistRespectReduceMotion() {
        defaults.set(respectSystemReduceMotion, forKey: DriftlyDefaultsKey.respectReduceMotion)
    }

    private func persistPreventAutoLock() {
        defaults.set(preventAutoLock, forKey: DriftlyDefaultsKey.preventAutoLock)
    }

    private func persistChromeVisibility() {
        defaults.set(isChromeVisible, forKey: DriftlyDefaultsKey.isChromeVisible)
    }

    private func persistBrightness() {
        let value = brightness
        persistenceQueue.async { [weak defaults] in
            defaults?.set(value, forKey: DriftlyDefaultsKey.brightness)
        }
    }

    private func persistLabsFeaturesEnabled() {
        defaults.set(labsFeaturesEnabled, forKey: DriftlyDefaultsKey.labsFeaturesEnabled)
    }

    private func persistAutoDriftEnabled() {
        defaults.set(autoDriftEnabled, forKey: DriftlyDefaultsKey.autoDriftEnabled)
    }

    private func persistAutoDriftShuffle() {
        defaults.set(autoDriftShuffleEnabled, forKey: DriftlyDefaultsKey.autoDriftShuffle)
    }

    private func persistAutoDriftInterval() {
        defaults.set(autoDriftIntervalMinutes, forKey: DriftlyDefaultsKey.autoDriftIntervalMins)
    }

    private func persistFavorites() {
        let rawValues = favoriteModes.map(\.rawValue)
        defaults.set(rawValues, forKey: DriftlyDefaultsKey.favoriteModes)
        pushFavoritesToCloud(favoriteModes)
    }

    private func persistAutoDriftSource() {
        let data = try? JSONEncoder().encode(autoDriftSource)
        defaults.set(data, forKey: DriftlyDefaultsKey.autoDriftSource)
    }

    private func persistModeDisplayOrder() {
        let rawValues = modeDisplayOrder.map(\.rawValue)
        defaults.set(rawValues, forKey: DriftlyDefaultsKey.modeDisplayOrder)
    }

    private func persistClockEnabled() {
        defaults.set(clockEnabled, forKey: DriftlyDefaultsKey.clockEnabled)
    }

    private static func initialFavorites(
        localFavorites: Set<DriftMode>,
        ubiquitousStore: UbiquitousKeyValueStoring?,
        defaults: UserDefaults
    ) -> Set<DriftMode> {
        if let rawValues = ubiquitousStore?.array(forKey: DriftlyDefaultsKey.favoriteModes) as? [String] {
            let cloudFavorites = Set(rawValues.compactMap(DriftMode.init(rawValue:)))
            defaults.set(rawValues, forKey: DriftlyDefaultsKey.favoriteModes)
            return cloudFavorites
        } else {
            let rawValues = localFavorites.map(\.rawValue)
            ubiquitousStore?.set(rawValues, forKey: DriftlyDefaultsKey.favoriteModes)
            if let ubiquitousStore {
                if ubiquitousStore is NSUbiquitousKeyValueStore {
                    DispatchQueue.global(qos: .utility).async {
                        _ = ubiquitousStore.synchronize()
                    }
                } else {
                    _ = ubiquitousStore.synchronize()
                }
            }
            return localFavorites
        }
    }

    private static func initialScenes(
        localScenes: [DriftScene],
        ubiquitousStore: UbiquitousKeyValueStoring?,
        defaults: UserDefaults
    ) -> [DriftScene] {
        guard let ubiquitousStore else { return localScenes }

        if let data = ubiquitousStore.data(forKey: DriftlyDefaultsKey.scenes),
           let cloudScenes = decodeScenes(from: data) {
            let merged = mergeScenes(local: localScenes, cloud: cloudScenes)
            if let mergedData = try? JSONEncoder().encode(merged) {
                defaults.set(mergedData, forKey: DriftlyDefaultsKey.scenes)
                // Push the merged result back to iCloud so other devices converge immediately.
                ubiquitousStore.set(mergedData, forKey: DriftlyDefaultsKey.scenes)
                if ubiquitousStore is NSUbiquitousKeyValueStore {
                    DispatchQueue.global(qos: .utility).async {
                        _ = ubiquitousStore.synchronize()
                    }
                } else {
                    _ = ubiquitousStore.synchronize()
                }
            }
            return merged
        } else {
            if let data = try? JSONEncoder().encode(localScenes) {
                ubiquitousStore.set(data, forKey: DriftlyDefaultsKey.scenes)
                if ubiquitousStore is NSUbiquitousKeyValueStore {
                    DispatchQueue.global(qos: .utility).async {
                        _ = ubiquitousStore.synchronize()
                    }
                } else {
                    _ = ubiquitousStore.synchronize()
                }
            }
            return localScenes
        }
    }

    private func loadCloudFavorites() -> Set<DriftMode>? {
        guard let rawValues = ubiquitousStore?.array(forKey: DriftlyDefaultsKey.favoriteModes) as? [String] else {
            return nil
        }
        let favorites = Set(rawValues.compactMap(DriftMode.init(rawValue:)))
        return favorites
    }

    private func persistScenes() {
        guard !applyingCloudScenes else { return }
        scenesPersistWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            persistenceQueue.async { [weak self] in
                guard let self else { return }
                let data = try? JSONEncoder().encode(self.scenes)
                self.defaults.set(data, forKey: DriftlyDefaultsKey.scenes)
                self.scheduleScenesCloudPush(data: data)
            }
        }

        scenesPersistWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    /// Immediately run any pending scene persistence so recent changes are not lost (e.g., on background).
    func flushPendingScenePersistence() {
        guard let work = scenesPersistWorkItem else { return }
        work.perform()
        scenesPersistWorkItem = nil
    }

    private func persistActiveSceneID() {
        if let id = activeSceneID {
            defaults.set(id.uuidString, forKey: DriftlyDefaultsKey.activeSceneID)
        } else {
            defaults.removeObject(forKey: DriftlyDefaultsKey.activeSceneID)
        }
    }

    private static func decodeScenes(from data: Data) -> [DriftScene]? {
        try? JSONDecoder().decode([DriftScene].self, from: data)
    }

    private static func validated(source: AutoDriftSource, scenes: [DriftScene]) -> AutoDriftSource {
        switch source {
        case .scene(let id):
            guard scenes.contains(where: { $0.id == id && $0.deletedAt == nil }) else {
                return .all
            }
            return source
        default:
            return source
        }
    }

    private static func mergeScenes(local: [DriftScene], cloud: [DriftScene]) -> [DriftScene] {
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        var merged: [UUID: DriftScene] = [:]

        for remote in cloud {
            if let local = localByID[remote.id] {
                merged[remote.id] = pickScene(local: local, remote: remote)
            } else {
                merged[remote.id] = remote
            }
        }

        for localScene in local where merged[localScene.id] == nil {
            merged[localScene.id] = localScene
        }

        return Array(merged.values)
    }

    private static func pickScene(local: DriftScene, remote: DriftScene) -> DriftScene {
        let localDate = local.deletedAt ?? local.updatedAt
        let remoteDate = remote.deletedAt ?? remote.updatedAt
        return remoteDate >= localDate ? remote : local
    }

    private func pushFavoritesToCloud(_ favorites: Set<DriftMode>) {
        guard let ubiquitousStore, !applyingCloudFavorites else { return }
        let rawValues = favorites.map(\.rawValue)
        if ubiquitousStore is NSUbiquitousKeyValueStore {
            ubiquitousQueue.async {
                ubiquitousStore.set(rawValues, forKey: DriftlyDefaultsKey.favoriteModes)
                _ = ubiquitousStore.synchronize()
            }
        } else {
            ubiquitousStore.set(rawValues, forKey: DriftlyDefaultsKey.favoriteModes)
            _ = ubiquitousStore.synchronize()
        }
    }

    private func loadCloudScenes() -> [DriftScene]? {
        guard let data = ubiquitousStore?.data(forKey: DriftlyDefaultsKey.scenes) else { return nil }
        return Self.decodeScenes(from: data)
    }

    private func scheduleScenesCloudPush(data: Data?) {
        guard ubiquitousStore != nil, !applyingCloudScenes else { return }
        scenesCloudPushWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self, let data, let store = self.ubiquitousStore else { return }
            self.ubiquitousQueue.async {
                store.set(data, forKey: DriftlyDefaultsKey.scenes)
                _ = store.synchronize()
            }
        }
        scenesCloudPushWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
    }

    private func startObservingUbiquitousStore() {
        guard let ubiquitousStore else { return }

        ubiquitousObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore,
            queue: .main
        ) { [weak self] notification in
            self?.handleUbiquitousStoreChange(notification)
        }
    }

    private func handleUbiquitousStoreChange(_ notification: Notification) {
        guard
            let reasonRaw = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
            reasonRaw == NSUbiquitousKeyValueStoreServerChange ||
            reasonRaw == NSUbiquitousKeyValueStoreInitialSyncChange
        else { return }

        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        if changedKeys.contains(DriftlyDefaultsKey.favoriteModes) {
            let cloudFavorites = loadCloudFavorites() ?? []
            if cloudFavorites != favoriteModes {
                applyingCloudFavorites = true
                favoriteModes = cloudFavorites
                applyingCloudFavorites = false
            }
        }

        if changedKeys.contains(DriftlyDefaultsKey.scenes) {
            if let cloudScenes = loadCloudScenes() {
                applyingCloudScenes = true
                scenes = Self.mergeScenes(local: scenes, cloud: cloudScenes)
                applyingCloudScenes = false
            }
        }
    }

    static func clampBrightness(_ value: Double) -> Double {
        max(0.2, min(1.0, value))
    }

    private func autoDriftSourceName(_ source: AutoDriftSource) -> String {
        switch source {
        case .all:
            return "all"
        case .favorites:
            return "favorites"
        case .scene(let id):
            return "scene:\(id.uuidString)"
        }
    }
}
