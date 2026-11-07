# Driftly Night 3.0 (6) App Store release

Both iOS/iPadOS and tvOS **3.0 (6)** were submitted and verified **Waiting for Review** on November 7, 2026. Release source is `5a3069c895dfa39caa5974d6decb9843744338ac` on `main`, configured remote `github` (`https://github.com/donnoel/Driftly.git`).

## Scope and baseline

- Live November 7 baseline: iOS and tvOS 2.3 (5), Ready for Distribution; no pending versions and no later uploaded build. The prior binary source was `500fcc6bf7dd324d5e77260ab8caf4586f478920`.
- Requested major marketing version: 3.0; unused build 6. Both app targets and embedded Top Shelf match. Existing automatic signing retained: team `H7LG8SK72M`, app `dn.DriftlyTV`, extension `dn.DriftlyTV.TopShelf`; production Release schemes `Driftly` and `DriftlyTV`.
- Includes the accepted scene refinements through `b9c9670`: living opal Vital Wave, luminous Glow Bloom blossoms, a reimagined Pulse Aurora and Neon Kelp, folded-light Lumen Vault, animated companions, more natural koi/rain, elastic Gravity Rings, Chromatic Spine interactions, flowing Caustic Silk notes and Ribbon Orbit, and lighter playback controls.
- Store copy is sourced from [English (U.S.) Description](app-store/releases/3.0/en-US/description.txt) and [What's New](app-store/releases/3.0/en-US/whats-new.txt). Both platforms receive the same verified copy. No audio feature is claimed; the musical notes are animated visuals.
- Existing screenshots/previews, promotional text, keywords, URLs, review information, privacy, age rating, pricing, availability, automatic release and immediate updates are retained.

## Validation

- Fixed local Xcode 27.0 (27A266a); existing pinned iOS/tvOS 26.5 simulators. Both production Release archives succeeded with Swift/C warnings treated as errors. No compiler or asset warnings; only the previously approved, unsuppressed App Intents metadata-extraction diagnostic remains.
- 42 focused scene/mode/transition tests across 12 suites and all 8 TV unit tests passed. Existing iPhone cold-launch/control smoke and TV remote-guide/navigation/Settings replay UI checks both passed. No broad audit, new tests, or hosted CI result claimed.
- Archive actual version/build, arm64, bundle IDs, embedded target, strict signatures, team provisioning, entitlements, app UserDefaults privacy reason CA92.1, and TV preview resources verified. Top Shelf uses no required-reason APIs and retains its arm64 requirement.
- Archives: `/Users/donnoel/Library/Developer/Xcode/Archives/2026-11-07/Driftly-3.0-6.xcarchive` and `DriftlyTV-3.0-6.xcarchive` in the same directory.
- 195 source/configuration/copy hashes match the release commit and archive inputs. Evidence: `/Users/donnoel/.codex/automations/app-app-store-submission/evidence/2026-11-07/Driftly/`; focused xcresults/build logs and uploaded exports under ignored `Build/Release-3.0/`.
- Current application source was already installed/launched on all three physical devices during the preceding scene sprint; scene visual approval and device evidence are recorded in the central [scene sprint report](/Users/donnoel/Development/Documentation/Projects/Driftly/2026-11-07-scene-sprint.md). This release changes versions and listing copy only; it does not claim a new physical installation or fresh aesthetic approval of the archive.

## Submission

- iOS final state: **Waiting for Review**, **Items Submitted (1)**, exact **iOS App 3.0 / 3.0 (6)**. Submitted November 7, 2026 at 8:18 AM PST. [Submission receipt](https://appstoreconnect.apple.com/apps/6758164205/distribution/reviewsubmissions/details/89fc9cc3-e8b7-4d1a-b687-25b1cd3dd85e).
- tvOS final state: **Waiting for Review**, **Items Submitted (1)**, exact **tvOS App 3.0 / 3.0 (6)**. Submitted November 7, 2026 at 8:21 AM PST. [Submission receipt](https://appstoreconnect.apple.com/apps/6758164205/distribution/reviewsubmissions/details/69c52ec9-f287-4f6e-8c61-04856a2c3dc4).
- Exact processed builds report **Validated**: iOS `606307d3-97b2-4a19-953a-1ef3c756567d`; tvOS `12b378fd-2031-4fda-ba36-e6ce086e894b`. Live Apple metadata confirms version/build, bundle IDs, supported device families and production app/extension entitlements.
- Both Add for Review and final Submit for Review completed. Each submission contains only its one app version; no incidental event, purchase, or other item was submitted.
- Both uploads succeeded using existing Cloud Managed Apple Distribution and matching Store profiles. Manage version/build and TestFlight internal-only options stayed off. Exported uploaded IPA signatures, production `get-task-allow=false`, bundle/version/build identity and privacy were verified.
- Required export-compliance answer: None of the algorithms mentioned above, based on the unchanged encryption/dependency boundary and current local visual code. Both builds report no non-exempt encryption. No legal agreements, account permissions, signing configuration or distribution settings were changed.
- Before review, both live descriptions and What's New matched the committed copy exactly. Existing iPhone screenshots inherit the approved set; the five iPad and five TV screenshots remain present. No previews or other listing metadata were edited.
- Application source and listing copy are committed and pushed as `5a3069c895dfa39caa5974d6decb9843744338ac`. The final evidence-record commit changes this uncompiled document only; the submitted archive source remains identical.

No remaining user action. Submitted is distinct from approved or publicly released. Automation remains paused/manual; no schedule or review-status monitor was created.

Uploaded ios IPA SHA-256: `9ada3ddfa8c2e1ee090d3b71134ed34ba07eb4e65b98cd9b790e672ef4b8520a`.

Uploaded tvos IPA SHA-256: `ab00e041cbab8955c6f221024d3861431afe8a2cdf78388e0f802d0b661e3a48`.
