import OSLog
import TVServices
import UIKit

final class ContentProvider: TVTopShelfContentProvider {
    nonisolated(nonsending) override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        let reduceMotion = await MainActor.run { UIAccessibility.isReduceMotionEnabled }
        let content = Self.makeContent(bundle: .main, reduceMotion: reduceMotion)
        Logger(subsystem: "dn.DriftlyTV.TopShelf", category: "content").info(
            "Quiet Aurora loaded; reduceMotion=\(reduceMotion), preview=\(content?.items.first?.previewVideoURL != nil)"
        )
        return content
    }

    // Missing video deliberately leaves the full-screen still in place. Missing
    // artwork returns nil so tvOS can use the app's static brand-asset fallback.
    static func makeContent(bundle: Bundle, reduceMotion: Bool) -> TVTopShelfCarouselContent? {
        guard let image = bundle.url(forResource: "QuietAurora", withExtension: "png") else { return nil }
        let item = TVTopShelfCarouselItem(identifier: "driftly.quiet-aurora")
        item.title = "Aurora Veil"
        item.setImageURL(image, for: .screenScale1x)
        item.setImageURL(bundle.url(forResource: "QuietAurora@2x", withExtension: "png") ?? image, for: .screenScale2x)
        item.playAction = TVTopShelfAction(url: URL(string: "driftly-tv://aurora-veil/play")!)
        item.displayAction = TVTopShelfAction(url: URL(string: "driftly-tv://aurora-veil/display")!)
        if !reduceMotion {
            // Bundle URLs are a local-device qualification candidate. tvOS owns
            // focus timing, autoplay policy, loading, and preview playback.
            item.previewVideoURL = bundle.url(forResource: "QuietAurora-preview", withExtension: "mp4")
        }
        // No cinemagraph: the still is the loading background. A cinemagraph is
        // only a short silent loop while a preview loads, not the main preview.
        return TVTopShelfCarouselContent(style: .actions, items: [item])
    }
}
