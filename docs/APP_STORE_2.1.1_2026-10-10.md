# Driftly Night 2.1.1 (2) App Store submission

Prepared on October 10, 2026 for iOS/iPadOS and tvOS.

- App Store Connect app: 6758164205; bundle ID: `dn.DriftlyTV` on both platforms.
- Developer team: `H7LG8SK72M` (Don Noel); existing automatic signing.
- Production schemes: `Driftly` and `DriftlyTV`, both Release configuration.
- Source baseline: `57247a73104f3d71f4100930dbd182c5b134942b` plus the scoped version/build and privacy-manifest changes in this release commit.
- Previous published release: 2.1 (1) on both platforms. Its live build IDs match the July 5 local archives. Git commit `94e4d91` is the corresponding version bump; the archives do not embed a source commit, so this baseline association is historical evidence rather than exact source attestation.

## What's New

iOS/iPadOS:

> A refreshed app icon, plus compatibility updates for the latest iOS and iPadOS releases.

tvOS:

> Compatibility updates for the latest tvOS release.

The iOS icon change is `4df253e`. Shared SwiftUI compatibility changes are `2cf6830`; these disambiguate gradient blend-mode calls without claiming a newly fixed user-visible rendering issue.

## Scoped release changes

- Set both app targets' Debug and Release versions to 2.1.1 (2); leave test target versions independent.
- Declare `NSPrivacyAccessedAPICategoryUserDefaults` with approved reason `CA92.1`, matching app-owned preferences. Preserve no-tracking and no-collected-data declarations.
- Use the existing English (U.S.) localization and preserve screenshots, description, keywords, URLs, privacy metadata, review details, pricing, availability, and release settings.

## Validation

- Both device Release archives succeeded with Swift and C warnings treated as errors.
- No compiler/source warnings. Xcode emitted one App Intents processor warning per archive: `Metadata extraction skipped, no AppIntents.framework dependency found`. The user explicitly approved this specific exception on October 10; no warning suppression or artificial App Intents dependency was added.
- Actual archive version/build, bundle ID, team, arm64 architecture, privacy manifest, and signatures verified. No embedded extensions, widgets, or Watch app.
- Archive signatures are Apple Development; App Store distribution uses the existing Cloud Managed Apple Distribution setup and re-signs with `get-task-allow=false`.
- Plist lint and `git diff --check` passed. No behavior code changed by this release preparation; no expanded test suite or broad audit was run. Physical interaction and visual acceptance were not re-tested.
- The initial CLI export encountered a cached profile/certificate mismatch. Xcode Organizer's existing automatic cloud-signing workflow resolved the distribution step without installing tools or changing signing configuration.

## Submission evidence

Both platforms completed Add for Review and the final Submit for Review. Live submission detail pages verified exactly **2.1.1 (2)**, **Waiting for Review**, and **Items Submitted (1)** on each platform.

| Platform | Processed build ID | Submission ID | Submitted (PDT) |
| --- | --- | --- | --- |
| iOS/iPadOS | `8e5f3b0b-f86e-44ed-a7a6-f78046bd34b4` | `bd2e4e1f-8547-42eb-9fda-fd11d4842c0c` | October 10, 2026, 4:28 PM |
| tvOS | `22f2c225-7603-4864-9678-0191a5123e08` | `2afcbc9c-45f2-4b9f-a5b4-480ff43d1ce9` | October 10, 2026, 4:29 PM |

- [iOS submission](https://appstoreconnect.apple.com/apps/6758164205/distribution/reviewsubmissions/details/bd2e4e1f-8547-42eb-9fda-fd11d4842c0c)
- [tvOS submission](https://appstoreconnect.apple.com/apps/6758164205/distribution/reviewsubmissions/details/2afcbc9c-45f2-4b9f-a5b4-480ff43d1ce9)
- Both Xcode archive distribution records report successful upload, actual uploaded build number 2, and no upload or distribution-preparation errors/warnings.
- Answered the required build encryption question as "None of the algorithms mentioned above", based on the app's Apple-framework-only code and lack of proprietary or separately implemented standard encryption.
- Existing automatic release after approval and immediate automatic updates remain selected; no review-status monitor or schedule was enabled. Automation status remains PAUSED.
- Archives are retained under `/Users/donnoel/Library/Developer/Xcode/Archives/2026-10-10/` as `Driftly-2.1.1-2.xcarchive` and `DriftlyTV-2.1.1-2.xcarchive`.
- Build logs, submission screenshots, and the SHA-256 snapshot of the 138 previously tracked files are retained under `/Users/donnoel/.codex/automations/app-app-store-submission/evidence/2026-10-10/`. The snapshot matches both archive preparations and is checked against the release commit; this document is the only newly added file and is not compiled into the apps.

Submitted does not mean approved or publicly released. No remaining user action was required at submission time.
