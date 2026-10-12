# Driftly Night tvOS 2.1.2 (3) App Store update

Prepared October 12, 2026 from the accepted wide Apple TV icon at `19c2ae21b8317d200cce3166c20ec8702136da08`.

- Target: `/Users/donnoel/Development/Driftly`, production `DriftlyTV` scheme, Release configuration.
- App Store Connect app `6758164205`, bundle `dn.DriftlyTV`, team `H7LG8SK72M` (Don Noel).
- Existing tvOS 2.1.1 (2) is Ready for Distribution in App Store Connect. Its exact release source is `fe871ad99f4c343191d5999c203a25d263af5fa9`; the only later application changes are the four foreground icon PNGs, ending with the accepted landscape composition at `19c2ae2`.
- tvOS-only update; iOS stays 2.1.1 (2). No application behavior, signing, deployment-target, privacy, dependency, or test-suite changes.

## What's New

> A refreshed app icon for Apple TV.

## Validation and upload

- Production Release archive succeeded with Swift/C compiler warnings treated as errors; no compiler or asset warnings/errors. The same App Intents processor diagnostic previously approved for Driftly remains: `Metadata extraction skipped, no AppIntents.framework dependency found`. It was neither suppressed nor addressed with an artificial dependency.
- Actual archive and uploaded IPA: 2.1.2 (3), `dn.DriftlyTV`, AppleTVOS/arm64, minimum tvOS 18.0, device family 3; no embedded extensions or Watch apps.
- Both signatures verified. Distribution uses existing Cloud Managed Apple Distribution and tvOS Team Store Provisioning Profile: dn.DriftlyTV; `get-task-allow=false`, production team/application and iCloud KVS entitlements verified.
- Required UserDefaults privacy manifest CA92.1 retained; no tracking or collected data. IPA icon asset catalog and privacy manifest match the archive byte-for-byte.
- Four PNG sizes, alpha, catalog compilation, image stacks, plist lint, and diff checks passed. All 139 pre-archive tracked inputs SHA-256 match the post-archive source. This document is additional uncompiled evidence.
- Narrow validation covers icon assets and release metadata. No behavior tests, broad audit, or repeat device installation; prior physical icon acceptance is recorded in automation memory.
- Xcode Organizer upload succeeded, with no distribution preparation/upload warnings or errors. Automatic signing retained; Manage version and build number off; TestFlight internal testing only off.
- Uploaded IPA SHA-256: `9acc3bc4a5d7e2a0a36e37520455c29ce89d1c4b42ee380dc72cf60977c5d048`.
- Archive: `/Users/donnoel/Library/Developer/Xcode/Archives/2026-10-12/DriftlyTV-2.1.2-3.xcarchive`.
- Logs, source hashes, asset catalog information, distribution summary/options, and exact uploaded IPA retained at `/Users/donnoel/.codex/automations/app-app-store-submission/evidence/2026-10-12/DriftlyTV/`.

## Submission

- Processed build ID: `cc78a11d-14ea-4719-a096-aea92a934778`.
- Live Apple Build Metadata verified **Validated**, exact 2.1.2 (3), Apple TV, bundle/team, production entitlements, and App Uses Non-Exempt Encryption: No.
- Required compliance answer: None of the algorithms mentioned above, supported by unchanged Apple-framework-only source and targeted source check.
- App Store Connect's included App Store layered icon preview visually shows the accepted cyan/blue and coral/pink wide composition.
- Completed Add for Review and final Submit for Review. Live submission detail verified **Waiting for Review**, **Items Submitted (1)**, **tvOS App 2.1.2 / 2.1.2 (3)**.
- Submitted October 12, 2026 at 3:43 PM PDT by Don Noel; submission ID `d316ff01-00c3-4807-b502-af668639d35e`.
- [Exact tvOS submission](https://appstoreconnect.apple.com/apps/6758164205/distribution/reviewsubmissions/details/d316ff01-00c3-4807-b502-af668639d35e).
- [Processed build metadata](https://appstoreconnect.apple.com/teams/a7d6ed44-3c4b-4dcf-b24a-a284df0bc533/apps/6758164205/testflight/tvos/cc78a11d-14ea-4719-a096-aea92a934778/metadata).
- No other app versions, events, purchases, or assets submitted. Existing iOS 2.1.1 remains Ready for Distribution.
- Submitted is not approved or publicly released. No remaining user action at handoff.

Preserved English (U.S.), five screenshots, description, promotional text, keywords, URLs, copyright, review contact and no-sign-in information, privacy, age rating, pricing, availability, automatic release after approval, immediate automatic updates, and existing rating. Automation remains PAUSED; no monitor or schedule enabled.
