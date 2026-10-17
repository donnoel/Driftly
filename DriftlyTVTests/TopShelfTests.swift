import Foundation
import SwiftUI
import Testing
import TVServices
@testable import DriftlyTV

@MainActor
struct TopShelfTests {
    private func extensionBundle() throws -> Bundle {
        try #require(Bundle(url: Bundle.main.bundleURL.appendingPathComponent("PlugIns/DriftlyTopShelf.appex")))
    }

    @Test func bundledCarouselAndReduceMotionFallback() throws {
        let bundle = try extensionBundle()
        let content = try #require(ContentProvider.makeContent(bundle: bundle, reduceMotion: false))
        #expect(content.style == .actions)
        #expect(content.items.count == 1)
        let item = try #require(content.items.first)
        #expect(item.imageURL(for: .screenScale1x)?.isFileURL == true)
        #expect(item.imageURL(for: .screenScale2x)?.isFileURL == true)
        #expect(item.previewVideoURL?.isFileURL == true)
        #expect(item.cinemagraphURL == nil)
        #expect(TVTopShelfRoute(url: try #require(item.playAction?.url)) == .play)
        #expect(TVTopShelfRoute(url: try #require(item.displayAction?.url)) == .display)

        let reduced = try #require(ContentProvider.makeContent(bundle: bundle, reduceMotion: true)?.items.first)
        #expect(reduced.previewVideoURL == nil)
        #expect(reduced.imageURL(for: .screenScale1x) == item.imageURL(for: .screenScale1x))
    }

    @Test func unavailableVideoKeepsStillAndMissingArtworkUsesStaticShelf() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let plist: [String: Any] = ["CFBundleIdentifier": "dn.DriftlyTV.TopShelfFixture", "CFBundlePackageType": "BNDL"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: directory.appendingPathComponent("Info.plist"), options: .atomic)
        let source = try #require(extensionBundle().url(forResource: "QuietAurora", withExtension: "png"))
        try FileManager.default.copyItem(at: source, to: directory.appendingPathComponent("QuietAurora.png"))
        let bundle = try #require(Bundle(url: directory))
        let item = try #require(ContentProvider.makeContent(bundle: bundle, reduceMotion: false)?.items.first)
        #expect(item.previewVideoURL == nil)
        #expect(item.imageURL(for: .screenScale1x) != nil)
        #expect(item.imageURL(for: .screenScale2x) == item.imageURL(for: .screenScale1x))
        #expect(item.playAction != nil && item.displayAction != nil)

        let emptyDirectory = directory.appendingPathComponent("empty.bundle")
        try FileManager.default.createDirectory(at: emptyDirectory, withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: emptyDirectory.appendingPathComponent("Info.plist"), options: .atomic)
        let emptyBundle = try #require(Bundle(url: emptyDirectory))
        #expect(ContentProvider.makeContent(bundle: emptyBundle, reduceMotion: false) == nil)
    }

    @Test func bothActionsOpenAuroraWithoutResettingPreferences() throws {
        let suite = "TopShelfRoute-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let engine = DriftlyEngine(defaults: defaults, ubiquitousStore: nil)
        engine.brightness = 0.42
        engine.animationSpeed = 0.6
        engine.clockEnabled = true
        engine.favoriteModes = [.glassTides]
        let coordinator = DriftlyRootCoordinator()
        let item = try #require(ContentProvider.makeContent(bundle: extensionBundle(), reduceMotion: false)?.items.first)
        for (url, showsPicker) in [(try #require(item.playAction?.url), false), (try #require(item.displayAction?.url), true)] {
            engine.currentMode = .glassTides
            coordinator.isSettingsPresented = true
            coordinator.sleepState.sleepTimerHasExpired = true
            #expect(coordinator.openTopShelfURL(url, engine: engine, scenePhase: .active))
            #expect(engine.currentMode == .auroraVeil)
            #expect(coordinator.isModePickerPresented == showsPicker)
            #expect(!coordinator.isSettingsPresented)
            #expect(!coordinator.sleepState.sleepTimerHasExpired)
            #expect(engine.brightness == 0.42)
            #expect(engine.animationSpeed == 0.6)
            #expect(engine.clockEnabled)
            #expect(engine.favoriteModes == [.glassTides])
        }
        engine.currentMode = .glassTides
        for address in ["https://example.com", "driftly-tv://unknown/play", "driftly-tv://aurora-veil/play?reset=true"] {
            #expect(!coordinator.openTopShelfURL(try #require(URL(string: address)), engine: engine, scenePhase: .active))
            #expect(engine.currentMode == .glassTides)
        }
    }
}
