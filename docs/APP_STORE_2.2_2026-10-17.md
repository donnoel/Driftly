# Driftly Night 2.2 (4) App Store release

Prepared October 17, 2026 for iOS/iPadOS and tvOS, using the requested short major.minor version convention on both platforms.

## Scope and baseline

- Repository: `/Users/donnoel/Development/Driftly`; branch `main`, configured remote `github` (`https://github.com/donnoel/Driftly.git`).
- App Store Connect app `6758164205`; team `H7LG8SK72M` (Don Noel); existing automatic signing. Production Release schemes `Driftly` and `DriftlyTV`.
- Main app bundle ID `dn.DriftlyTV` on both platforms; tvOS-only embedded extension `dn.DriftlyTV.TopShelf`.
- Live release baseline: iOS 2.1.1 (2) and tvOS 2.1.2 (3), both Ready for Distribution. Release source commits `fe871ad` and `d0b9608` establish the exact published-feature baseline.
- Existing local Top Shelf implementation is included: static shelf artwork, an offline bundled Aurora Veil preview, TVServices carousel, Play and More Info routes, fallback behavior, and six tvOS unit tests. Implementation details and original local device evidence are in `QUIET_AURORA_TOP_SHELF_REVIEW.md`.
- Shared app additions are guarded by `#if os(tvOS)`; no iOS feature change is claimed. Both apps and the extension are version 2.2, build 4.
- All pre-existing changed/untracked files were inspected and relate to the requested Top Shelf implementation, assets, tests, reproduction tool, and review document. No unrelated work was discarded or staged.

## What's New

iOS/iPadOS:

> This update brings the iPhone and iPad app to version 2.2, matching the Apple TV release.

tvOS:

> A refreshed Apple TV Top Shelf with a calming Aurora Veil preview and quick access to play or browse modes.

## Validation and physical delivery

- Both production Release archives succeeded with Swift/C warnings as errors. No compiler or asset warnings. The existing, previously approved App Intents metadata-extraction diagnostic remains, without suppression or artificial dependencies.
- All 6 existing tvOS unit tests passed (0 failures/skips), including Top Shelf resources, routes, preference preservation, Reduce Motion, and missing-media fallbacks. No test-suite expansion or broad audit.
- Archive actual version/build, bundle IDs, tvOS extension embedding, arm64, signatures, device provisioning, app entitlements and CA92.1 privacy manifests verified. Extension uses no required-reason APIs; no new data collection, network service, or credentials introduced.
- First tvOS upload validation identified a required `UIRequiredDeviceCapabilities = [arm64]` declaration in the new extension. Added that entry and rebuilt both archives from the final source. The rejected initial package is not the submitted binary.
- Final archives were installed and launched before submission on Don’s iPhone 15 Pro Max, iPad Pro 13-inch (M4), and Living Room Apple TV 4K (3rd generation). Each device reports 2.2 (4), with a live process matching its newly installed app container. No uninstall or data reset.
- Device launch is verified; new human visual/interaction acceptance is not inferred from installation. Original Top Shelf device qualification and remaining visual checklist remain documented separately.
- Final archives: `/Users/donnoel/Library/Developer/Xcode/Archives/2026-10-17/Driftly-2.2-4-final.xcarchive` and `/Users/donnoel/Library/Developer/Xcode/Archives/2026-10-17/DriftlyTV-2.2-4-arm64.xcarchive`.
- Build/test/device/source-hash evidence: `/Users/donnoel/.codex/automations/app-app-store-submission/evidence/2026-10-17/Driftly/`.

## Submission

Both final uploads succeeded through Xcode Organizer using existing Cloud Managed Apple Distribution and matching App Store provisioning. Manage version/build and internal-only options remained off. Both distribution records show success without preparation/upload warnings/errors. Exported uploaded IPA identities, signatures, production entitlements (`get-task-allow=false`), app privacy manifests, and archived media/assets were verified.

- tvOS processed build: `a4297bd8-36b9-4faf-9026-7ac9f2f23a97`; live Apple binary state **Validated**. Correct app/extension identity, arm64, Apple TV family, and production entitlements verified.
- tvOS final submission: **Waiting for Review**, **Items Submitted (1)**, exact **tvOS App 2.2 / 2.2 (4)**. Submitted October 17, 2026 at 7:31 AM PDT.
- [tvOS submission](https://appstoreconnect.apple.com/apps/6758164205/distribution/reviewsubmissions/details/3f35da13-e76c-40ed-8c4a-a4ac06b83a95).
- iOS processed build: `82c1633b-0b62-4f37-ab9b-dc1309b99fd7`; live Apple binary state **Validated**, exact 2.2 (4), iPhone/iPad family, correct bundle/team, and production entitlements verified.
- iOS final submission: **Waiting for Review**, **Items Submitted (1)**, exact **iOS App 2.2 / 2.2 (4)**. Submitted October 17, 2026 at 7:35 AM PDT.
- [iOS submission](https://appstoreconnect.apple.com/apps/6758164205/distribution/reviewsubmissions/details/2ae8e1f6-bde1-4ebd-b231-efcdc92eefc1).
- Both Add for Review and final Submit for Review completed on each platform. No incidental events, purchases, or other items submitted. Required encryption answers follow current source: None of the algorithms mentioned above; live metadata reports no non-exempt encryption.
- All 149 final pre-archive file hashes match the source staged for the release commit; this release evidence document is additional uncompiled content. No remaining user action.
- Exported tvOS IPA SHA-256: `9b38d259bbedb7829a3bbe98b04542d16ea201143fb034a300da529edf0b6bd6`.
- Exported iOS IPA SHA-256: `e8b7d519a1a42d9d62a55ccfb512e278a28d1bdfdef3489a246f6b35b1835c18`.

Submitted is distinct from approved or publicly released.

Both versions preserve English (U.S.), existing screenshots/previews, description, promotional text, keywords, URLs, copyright, review details/no-sign-in setting, privacy, age rating, pricing, availability, automatic release after approval, immediate automatic updates, and existing ratings. Only binaries/build selection, versions, and What's New are changed. User confirmed acceptance of the updated Apple Developer agreement; the agent did not accept an agreement. Automation remains paused/manual; no scheduling or review monitor enabled.
