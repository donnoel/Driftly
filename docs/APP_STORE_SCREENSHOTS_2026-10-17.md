# Driftly Night 2.2 (4) — screenshot resubmission

Don approved the local screenshot direction on October 17, 2026, then explicitly requested upload to App Store Connect and resubmission. All 15 approved screenshots were uploaded to app `6758164205`, using the existing English (U.S.) localization.

## Exact submitted versions

| Platform | Version/build | Submitted October 17 (PDT) | Verified status | Submission |
| --- | --- | --- | --- | --- |
| iOS/iPadOS | 2.2 (4) | 8:09 AM | Waiting for Review | [afb890fb-365f-4ec7-8e4f-9e141f6f08e6](https://appstoreconnect.apple.com/apps/6758164205/distribution/reviewsubmissions/details/afb890fb-365f-4ec7-8e4f-9e141f6f08e6) |
| tvOS | 2.2 (4) | 8:03 AM | Waiting for Review | [ea439cac-b27f-498d-a5db-ed08026ed34d](https://appstoreconnect.apple.com/apps/6758164205/distribution/reviewsubmissions/details/ea439cac-b27f-498d-a5db-ed08026ed34d) |

Each final live detail page shows **Items Submitted (1)** and the exact app version/build. Submitted is distinct from approved or publicly released. The original 7:31 AM / 7:35 AM submissions show Removed after the authorized cancellations.

## Assets and retained settings

- Five iPhone images at 1320 × 2868 replace the existing master Dynamic Island large-display set in Media Manager. The required medium-display set continues to inherit them; its five new filenames were verified after reloading.
- Five iPad images at 2064 × 2752 replace the existing 13-inch set. Its five ordered filenames persisted after reloading. Existing scaling to other iPad sizes remains.
- Five Apple TV images at 1920 × 1080 replace the existing TV set. The fifth uses the actual current Top Shelf carousel capture.
- In order: Aurora Veil, Glass Tides, Lumen Vault, Sleep Timer, then Optional Clock on iPhone/iPad or Top Shelf on TV.
- Apple's Remove All confirmation explicitly preserved the previous images in Asset Library. No library assets were deleted. Existing preview counts remain zero.
- Description, promotional text, keywords, URLs, copyright, review contact/sign-in details, privacy, age rating, pricing, availability, and ratings were untouched. Automatic release after approval and immediate automatic updates remain selected on both platforms.
- What's New remains unchanged: iOS, “This update brings the iPhone and iPad app to version 2.2, matching the Apple TV release.” tvOS, “A refreshed Apple TV Top Shelf with a calming Aurora Veil preview and quick access to play or browse modes.”

## Validation and source

- [Approved PNG exports and manifest](app-store/2.2/screenshots/) are preserved with [validation hashes](app-store/2.2/screenshots/validation.json). All 15 match the reviewed/uploaded bytes, expected dimensions, 8-bit RGB, opaque PNG, and sRGB IEC61966-2.1 profile. Sizes/format were checked against [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
- Native reproduction tool and review gallery: `tools/AppStoreScreenshots/`. Genuine current app captures are cropped/composed with Apple frameworks; no app UI was invented or repainted. Local raw captures and static contact sheets remain in ignored `Build/AppStoreScreenshotReview/`.
- The app, extension, project, and tests remain unchanged from binary release commit `fa5423115c7a74f49fc40c609dc6705b30cf9b1d`. The existing processed build identities, signing, and archives recorded in [the binary release record](APP_STORE_2.2_2026-10-17.md) are retained. This change requires no new archive, binary upload, signing change, version increment, device installation, or app test run.
- Both Add for Review and final Submit for Review were completed. The iOS final action returned a generic unexpected-error message, but a fresh App Review load showed the new submission Waiting for Review. A full Safari reload reconciled the stale sidebar/draft, and a fresh detail tab confirmed the exact 2.2 (4) build. No second submission was sent.
- Live AX records and screenshots are retained outside Git at `/Users/donnoel/.codex/automations/app-app-store-submission/evidence/2026-10-17/Driftly/screenshots/`, including the final two detail pages and combined submission list.
- Automation remains PAUSED/manual. No scheduling, status monitor, or unrelated submission was created. No remaining user action was identified.

The narrow change is marketing assets, their renderer/review page, and release documentation. Runtime and interaction behavior are unchanged. A future screenshot revision should be reviewed locally before another upload.
