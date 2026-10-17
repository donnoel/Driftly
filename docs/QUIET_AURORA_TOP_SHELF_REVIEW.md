# Quiet Aurora — local tvOS review

Implemented and installed on **Living Room, Apple TV 4K (3rd generation), tvOS 27.0**, October 17, 2026. Visual acceptance is handed to Don. No commit, push, hosting, TestFlight, or App Store submission was performed. App versions remain unchanged.

## Implementation

- Four static shelf slots replaced at 1920×720 / 3840×1440 and 2320×720 / 4640×1440. Each aspect ratio is rendered independently with consistent ribbon proportions, rather than stretching a banner. App icon stacks are unchanged.
- `DriftlyTopShelf` is a tvOS-only TVServices extension, embedded through an app target dependency and Embed App Extensions phase. It returns one stable `.actions` carousel item.
- Separate full-screen artwork: 1920×1080 and 3840×2160. No baked-in text, badge, or logo. The system supplies the Aurora Veil title and action controls.
- `QuietAurora-preview.mp4`: 24 seconds, 720 frames, 1080p30, HEVC Main 10, SDR Rec.709, no audio. Ten-bit rendering/encoding reduces dark-gradient quantization. There are no HDR brightness changes. The MP4 header precedes its media payload.
- Offline Metal rendering adapts Aurora Veil's blurred translucent bands and Glass Tides' curved sheets. The extension runs no renderer or playback controller. Fixed fine dithering avoids animated grain. The start/end source poses are byte-identical; the last encoded frame is one frame before the join, avoiding a duplicate-frame hold. Average luma varies less than 1% over the asset.
- `previewVideoURL` uses the extension's bundled movie. `cinemagraphURL` is intentionally nil: the matching still is the loading background. Preview repeat behavior remains under tvOS control.
- Play opens the existing Aurora Veil mode. More Info selects that mode and opens the existing mode browser. Only the two exact `driftly-tv://aurora-veil/play` and `/display` URLs are accepted. No preferences are reset.
- Missing movie leaves the carousel still and actions available; missing artwork returns nil for the system's static brand-asset fallback. When queried with Reduce Motion enabled, the provider omits the preview URL.
- Shared coordinator/view additions are guarded by `#if os(tvOS)`. Existing ambient renderers and iOS behavior are unchanged.

## Verified

- tvOS simulator app + extension build; signed physical tvOS app + embedded extension build; iOS simulator compatibility build. Swift/C compiler warnings treated as errors. Code signatures verified. Xcode's existing, previously approved App Intents metadata diagnostic remains; no artificial dependency or suppression was added (see `APP_STORE_TVOS_2.1.2_2026-10-12.md`).
- All 6 tvOS unit tests passed, including the 3 new Top Shelf tests: actual extension resources and both actions, Reduce Motion content, unavailable-video/missing-artwork fallbacks, rejected routes, and preservation of brightness/speed/clock/favorites.
- Physical Apple TV: installed/launched; carousel shown in the Dock and full screen; navigation away/back; actual Play and More Info buttons; auto-play disabled retains a still. Two background captures 7 seconds apart with auto-play disabled were pixel-identical.
- Bundled H.264 preview motion was proven by timestamped physical captures before the final ten-bit replacement. The final HEVC Main 10 asset was installed and its Dock/carousel artwork and both buttons were observed. Final motion smoothness, banding, and Reduce Motion acceptance are for human inspection.
- All four shelf dimensions, both carousel dimensions, silent video track, duration, frame count, profile, and source seam checked. The first HEVC frame differs from its matching still by less than 0.5/255 mean per RGB channel.

## Your visual checklist

1. Focus Driftly in the Dock, then swipe up. Check slow lateral movement, soft ribbons, dark-gradient banding, brightness stability, and the quiet lower region. Observe through the end of the 24-second preview; tvOS need not loop it indefinitely.
2. Move to another Dock app and back. Check the loading still and return to motion.
3. Try Play and More Info. Play should open Aurora Veil; More Info should open the existing mode browser with Aurora Veil selected as the active mode.
4. In Settings → Accessibility → Motion, try Auto-Play Video Previews Off and Reduce Motion On separately. Check an attractive still and usable system actions. Restore your preferred settings afterward. Before handoff, original values were restored: **Reduce Motion Off; Auto-Play Video Previews On**.

Unavailable video is covered by the unit test. A signed no-video qualification build is prepared at `Build/TopShelfStaticFallback/Build/Products/Debug-appletvos/DriftlyTV.app`, built with `EXCLUDED_SOURCE_FILE_NAMES=QuietAurora-preview.mp4`; it has not been installed. The normal animated build remains installed. Do not delete media from a signed installed bundle to simulate failure.

Bundled media is supported by the tested current SDK/device path; this is not a claim about every supported tvOS version or Apple TV model. If another device rejects bundled media, retain the static artwork and qualify an HTTPS media source separately. No hosting has been provisioned.

## Assets and reproduction

- Movie and full-screen stills: `DriftlyTopShelf/QuietAurora-preview.mp4`, `QuietAurora.png`, `QuietAurora@2x.png`.
- Renderer: `tools/TopShelf/render-quiet-aurora.swift` (macOS 26+; Apple frameworks only). Compile/run commands are at the top of the source; `--stills-only` skips video encoding.
- Local evidence: `Build/QuietAuroraReview/` (ignored by Git): build/install logs, media validation JSON, decoded frames, and physical screenshots. The device explicitly rejects direct screen recording; Device Hub screen viewing and timestamped screenshots were used instead.

Apple references checked against the installed tvOS 27 SDK headers and Xcode Top Shelf template:

- [Top Shelf design guidance](https://developer.apple.com/design/human-interface-guidelines/top-shelf)
- [Carousel preview video](https://developer.apple.com/documentation/tvservices/tvtopshelfcarouselitem/previewvideourl)
- [Cinemagraph loading-loop role](https://developer.apple.com/documentation/tvservices/tvtopshelfcarouselitem/cinemagraphurl)
- [WWDC19: Creating Great Apps for the Living Room](https://developer.apple.com/videos/play/wwdc2019/211/)
