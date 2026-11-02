# Driftly Night 2.3 (5) release

## Scope and baseline

- Production iOS/iPadOS and tvOS Release schemes: `Driftly` and `DriftlyTV`, team `H7LG8SK72M`, bundle `dn.DriftlyTV`, embedded TV extension `dn.DriftlyTV.TopShelf`.
- Live published baseline checked November 1: both platforms 2.2 (4), Ready for Distribution, with no pending update. Both new drafts use 2.3 (5).
- Includes the previously committed smooth scene transitions (`9510955`) and a TV-only four-screen remote guide. The guide appears once per TV installation, supports Skip and remote Back, and can be replayed from Settings without resetting preferences.
- Existing screenshots, previews, other metadata, review details, privacy declarations, pricing, availability, and automatic/immediate release settings are preserved.

## What's New

iOS/iPadOS:

> Visuals now blend smoothly into one another for a calmer, more continuous experience.

tvOS:

> Enjoy smoother transitions between visuals, plus a new remote guide covering visual selection, brightness, and the sleep timer.

## Validation and delivery

- Fixed local Xcode 27.0 (27A266a), shared pinned tvOS/iOS 26.5 simulators. Both production Release archives succeeded with Swift/C warnings treated as errors. No compiler or asset warnings; the existing previously accepted App Intents metadata-extraction diagnostic remains unsuppressed.
- All 8 TV unit tests passed, including local guide completion and preference preservation. Focused remote UI flow passed: four screens, Menu/Back, completion across relaunch, Settings replay, and Skip. Final screenshots inspected; shortened a truncated diagram caption.
- 12 focused iOS tests passed across scene transitions, mode registry, and idle-timer policy. Existing idle-timer tests now await the app's actor-isolated functions, as required by the fixed compiler. Full hosted CI and broad suites were not run.
- Both archives contain actual version 2.3/build 5, arm64, expected bundle IDs/team/signatures/entitlements; TV extension matches and retains its arm64 requirement and bundled preview. App manifests declare UserDefaults reason CA92.1; the extension contains no required-reason API usage. Distribution signing is verified separately after export.
- Archived apps installed and launched on Don's iPhone 15 Pro Max, iPad Pro 13-inch (M4), and Living Room Apple TV 4K (3rd generation), preserving existing data. Don approved the visual result in this session.
- Archives: `/Users/donnoel/Library/Developer/Xcode/Archives/2026-11-01/Driftly-2.3-5.xcarchive` and `DriftlyTV-2.3-5-final.xcarchive` in the same folder.
- Logs, screenshots, device receipts, archive inspection and source hashes: `/Users/donnoel/.codex/automations/app-app-store-submission/evidence/2026-11-01/Driftly/` and ignored local `Build/` artifacts.

## Submission

Submission pending upload and live verification. This document will record exact final review states after both final Submit for Review steps. Uploaded, submitted, approved, and publicly released are separate states.

Automation stays paused/manual; no review monitor or scheduling is created.
