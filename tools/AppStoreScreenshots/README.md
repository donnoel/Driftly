# App Store screenshot direction — October 17, 2026

Driftly Night's screenshot direction was approved by Don and uploaded on October 17, 2026. Both existing 2.2 (4) builds were resubmitted and verified **Waiting for Review**. See [the resubmission record](../../docs/APP_STORE_SCREENSHOTS_2026-10-17.md). No app source changed.

The approved exports are preserved in `docs/app-store/2.2/screenshots/`, with file hashes and a manifest. Raw captures, the local gallery, and three `*-sequence.png` contact sheets live in the ignored `Build/AppStoreScreenshotReview/` folder. Open `review.html` through a local static server to enlarge individual images.

## Visual direction

- Midnight background, restrained system typography, mint brand label.
- Genuine current app imagery occupies most of each composition; no mock device frames, fake reflections, generated artwork, or reconstructed UI.
- Aurora Veil, Glass Tides, and Lumen Vault establish atmosphere and variety. The last two cards demonstrate the sleep timer and optional clock; Apple TV replaces the clock with the actual Top Shelf carousel.
- iPhone/iPad use native platform captures with a compact caption area above the artwork. Apple TV uses the complete landscape capture with captions over quiet regions. The timer's controls remain visible.

## Evidence and capture scope

- App source: release commit `fa5423115c7a74f49fc40c609dc6705b30cf9b1d`, version 2.2 (4), unchanged by this work.
- iPhone 18 Pro Max, iPad Pro 13-inch (M5), and Apple TV 4K (3rd generation) simulators, current installed OS runtimes. iOS and tvOS Debug builds made from that source with Swift/C warnings treated as errors. The existing App Intents metadata extraction diagnostic remains in the tvOS build, as recorded in the release guidance.
- Simulator captures are full-resolution PNGs captured using `xcrun simctl io <UDID> screenshot`. Existing Debug launch arguments select an actual app mode and optionally present the real timer. `-driftly.isChromeVisible NO` and `-driftly.clockEnabled YES` use the simulator app's defaults argument domain.
- Raw filenames are `<platform>-<mode>.png`, matching `manifest.json`. The physical Top Shelf screenshot is copied from `Build/QuietAuroraReview/apple-tv-carousel.png`, captured during the accepted 2.2 release work on October 17. Its Play/More Info controls are genuine tvOS UI.
- The composition crops simulator-only motion hardware warnings out of the artwork. No in-app pixels are painted out. Artwork crops also remove temporary simulator system chrome. The iPad timer is a tighter crop to make the native dialog readable. These are marketing compositions, not evidence of a new UI layout.

## Rebuild the compositions

From the repository root, with the preserved raw captures in place:

```sh
swiftc -warnings-as-errors tools/AppStoreScreenshots/render-review.swift -o Build/AppStoreScreenshotReview/render-review
Build/AppStoreScreenshotReview/render-review Build/AppStoreScreenshotReview
cp tools/AppStoreScreenshots/review.html Build/AppStoreScreenshotReview/review.html
python3 -m http.server 8767 --bind 127.0.0.1 --directory Build/AppStoreScreenshotReview
```

Visit `http://127.0.0.1:8767/review.html`. The renderer uses only Apple frameworks. It exports five opaque sRGB PNGs per platform: iPhone 1320 × 2868, iPad 2064 × 2752, Apple TV 1920 × 1080. These dimensions and PNG format were checked against [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) on October 17, 2026.

`manifest.json` records the output files, source captures, captions, and dimensions. `validation.json` records SHA-256 hashes of the approved PNGs and raw captures. Any subsequent redesign needs a new visual review before upload. The submitted set uses the existing English (U.S.) localization and existing screenshot scaling behavior.
