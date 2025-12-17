import SwiftUI
import Combine
import Foundation

protocol UbiquitousKeyValueStoring: AnyObject {
    func array(forKey: String) -> [Any]?
    func set(_ value: Any?, forKey: String)
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: UbiquitousKeyValueStoring {}

private enum DriftlyDefaultsKey {
    static let currentMode           = "driftly.currentMode"
    static let animationSpeed        = "driftly.animationSpeed"
    static let preventAutoLock       = "driftly.preventAutoLock"
    static let isChromeVisible       = "driftly.isChromeVisible"
    static let brightness            = "driftly.brightness"
    static let autoDriftEnabled      = "driftly.autoDriftEnabled"
    static let autoDriftIntervalMins = "driftly.autoDriftIntervalMins"
    static let autoDriftShuffle      = "driftly.autoDriftShuffle"
    static let favoriteModes         = "driftly.favoriteModes"
    static let autoDriftFavoritesOnly = "driftly.autoDriftFavoritesOnly"
    static let modeDisplayOrder      = "driftly.modeDisplayOrder"
}

final class DriftlyEngine: ObservableObject {
    // MARK: - Published state

    private let defaults: UserDefaults
    private let ubiquitousStore: UbiquitousKeyValueStoring?
    private var ubiquitousObserver: NSObjectProtocol?
    private var applyingCloudFavorites = false

    @Published var currentMode: DriftMode {
        didSet { persistCurrentMode() }
    }

    @Published var isChromeVisible: Bool {
        didSet { persistChromeVisibility() }
    }

    /// 1.0 = normal speed, 0.5 = slower, 1.5 = faster
    @Published var animationSpeed: Double {
        didSet { persistAnimationSpeed() }
    }

    /// When true, Driftly will try to prevent auto-lock while active
    @Published var preventAutoLock: Bool {
        didSet { persistPreventAutoLock() }
    }

    /// 0.2 (dim) ... 1.0 (full brightness)
    @Published var brightness: Double {
        didSet {
            let clamped = Self.clampBrightness(brightness)
            if clamped != brightness {
                brightness = clamped
                return
            }
            persistBrightness()
        }
    }

    /// Auto-drift: whether Driftly should automatically change modes
    @Published var autoDriftEnabled: Bool {
        didSet { persistAutoDriftEnabled() }
    }

    /// Whether auto-drift should use a shuffled order.
    @Published var autoDriftShuffleEnabled: Bool {
        didSet { persistAutoDriftShuffle() }
    }

    /// Auto-drift interval in minutes
    @Published var autoDriftIntervalMinutes: Int {
        didSet { persistAutoDriftInterval() }
    }

    /// Favorited modes (set of raw values)
    @Published var favoriteModes: Set<DriftMode> {
        didSet { persistFavorites() }
    }

    /// Whether auto-drift should be limited to favorites when available
    @Published var autoDriftFavoritesOnly: Bool {
        didSet { persistAutoDriftFavoritesOnly() }
    }

    /// When set, Driftly will fade out once this time is reached (not persisted across launches)
    @Published var sleepTimerEndDate: Date? = nil

    var allModes: [DriftMode] {
        DriftMode.allCases
    }

    /// User-selected ordering for the mode picker UI (does not affect core mode list)
    @Published var modeDisplayOrder: [DriftMode] {
        didSet { persistModeDisplayOrder() }
    }

    // Non-persisted shuffle queue to ensure we traverse each candidate once before repeating.
    private var shuffleQueue: [DriftMode] = []

    var modePickerModes: [DriftMode] {
        modeDisplayOrder
    }

    // MARK: - Init

    init(
        defaults: UserDefaults = .standard,
        ubiquitousStore: UbiquitousKeyValueStoring? = NSUbiquitousKeyValueStore.default
    ) {
        self.defaults = defaults
        self.ubiquitousStore = ubiquitousStore
        self.ubiquitousStore?.synchronize()

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

        // animationSpeed (default: 1.0)
        let storedSpeed = defaults.double(forKey: DriftlyDefaultsKey.animationSpeed)
        animationSpeed = storedSpeed == 0 ? 1.0 : storedSpeed

        // preventAutoLock (default: false)
        if defaults.object(forKey: DriftlyDefaultsKey.preventAutoLock) != nil {
            preventAutoLock = defaults.bool(forKey: DriftlyDefaultsKey.preventAutoLock)
        } else {
            preventAutoLock = false
        }

        // brightness (default: 1.0)
        let storedBrightness = defaults.double(forKey: DriftlyDefaultsKey.brightness)
        if storedBrightness == 0 {
            brightness = 1.0
        } else {
            brightness = Self.clampBrightness(storedBrightness)
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
            autoDriftIntervalMinutes = max(3, storedInterval)
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

        // favorites only (default: false)
        if defaults.object(forKey: DriftlyDefaultsKey.autoDriftFavoritesOnly) != nil {
            autoDriftFavoritesOnly = defaults.bool(forKey: DriftlyDefaultsKey.autoDriftFavoritesOnly)
        } else {
            autoDriftFavoritesOnly = false
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

        startObservingUbiquitousStore()
    }

    deinit {
        if let ubiquitousObserver {
            NotificationCenter.default.removeObserver(ubiquitousObserver)
        }
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

    // MARK: - Persistence

    private func persistCurrentMode() {
        defaults.set(currentMode.rawValue, forKey: DriftlyDefaultsKey.currentMode)
    }

    func shouldAutoDrift(
        now: Date,
        lastChange: Date,
        sleepTimerHasExpired: Bool
    ) -> Bool {
        guard autoDriftEnabled, !sleepTimerHasExpired else { return false }

        let intervalMinutes = max(3, autoDriftIntervalMinutes)
        let intervalSeconds = Double(intervalMinutes * 60)
        let elapsed = now.timeIntervalSince(lastChange)

        return elapsed >= intervalSeconds
    }

    func nextAutoDriftMode(after current: DriftMode) -> DriftMode {
        if autoDriftShuffleEnabled {
            let pool = shuffleCandidatePool(current: current)
            return nextShuffledMode(from: pool, current: current)
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

    private func autoDriftCandidates(startingAt current: DriftMode) -> [DriftMode] {
        if autoDriftFavoritesOnly, !favoriteModes.isEmpty {
            // Keep favorites in a stable, user-friendly order (alphabetical by display name)
            let favoritesList = favoriteModes.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            if !favoriteModes.contains(current) {
                return [current] + favoritesList
            }
            return favoritesList
        }
        return allModes
    }

    private func shuffleCandidatePool(current: DriftMode) -> [DriftMode] {
        if autoDriftFavoritesOnly, !favoriteModes.isEmpty {
            return favoriteModes.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
        return allModes
    }

    private func nextShuffledMode(from candidates: [DriftMode], current: DriftMode) -> DriftMode {
        guard !candidates.isEmpty else { return current }

        let candidateSet = Set(candidates)
        // Prune any stale entries and never keep the current mode in the queue.
        shuffleQueue = shuffleQueue.filter { candidateSet.contains($0) && $0 != current }

        if shuffleQueue.isEmpty {
            shuffleQueue = candidates.filter { $0 != current }.shuffled()
        }

        return shuffleQueue.isEmpty ? current : shuffleQueue.removeFirst()
    }

    private func persistAnimationSpeed() {
        defaults.set(animationSpeed, forKey: DriftlyDefaultsKey.animationSpeed)
    }

    private func persistPreventAutoLock() {
        defaults.set(preventAutoLock, forKey: DriftlyDefaultsKey.preventAutoLock)
    }

    private func persistChromeVisibility() {
        defaults.set(isChromeVisible, forKey: DriftlyDefaultsKey.isChromeVisible)
    }

    private func persistBrightness() {
        defaults.set(brightness, forKey: DriftlyDefaultsKey.brightness)
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

    private func persistAutoDriftFavoritesOnly() {
        defaults.set(autoDriftFavoritesOnly, forKey: DriftlyDefaultsKey.autoDriftFavoritesOnly)
    }

    private func persistModeDisplayOrder() {
        let rawValues = modeDisplayOrder.map(\.rawValue)
        defaults.set(rawValues, forKey: DriftlyDefaultsKey.modeDisplayOrder)
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
            ubiquitousStore?.synchronize()
            return localFavorites
        }
    }

    private func loadCloudFavorites() -> Set<DriftMode>? {
        guard let rawValues = ubiquitousStore?.array(forKey: DriftlyDefaultsKey.favoriteModes) as? [String] else {
            return nil
        }
        let favorites = Set(rawValues.compactMap(DriftMode.init(rawValue:)))
        return favorites
    }

    private func pushFavoritesToCloud(_ favorites: Set<DriftMode>) {
        guard let ubiquitousStore, !applyingCloudFavorites else { return }
        let rawValues = favorites.map(\.rawValue)
        ubiquitousStore.set(rawValues, forKey: DriftlyDefaultsKey.favoriteModes)
        ubiquitousStore.synchronize()
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

        guard
            let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
            changedKeys.contains(DriftlyDefaultsKey.favoriteModes)
        else {
            return
        }

        let cloudFavorites = loadCloudFavorites() ?? []
        guard cloudFavorites != favoriteModes else { return }

        applyingCloudFavorites = true
        favoriteModes = cloudFavorites
        applyingCloudFavorites = false
    }

    static func clampBrightness(_ value: Double) -> Double {
        max(0.2, min(1.0, value))
    }
}
