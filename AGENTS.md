# Agents Guide

## Project
- Name: Driftly
- Platform: SwiftUI (iOS/tvOS)
- Schemes: Driftly (app + tests), DriftlyTV

## Local expectations
- Xcode command-line tools: /Applications/Xcode.app/Contents/Developer
- Simulators: iOS 26.x; common device UDID: iPad Pro 13-inch (M5) (B194C053-D85D-4348-9AFE-CD9BA66E16BA)
- Preferred destinations:
  - iOS: DESTINATION="id=B194C053-D85D-4348-9AFE-CD9BA66E16BA" (iPad Pro 13" M5)
  - Override with DESTINATION env var when needed.

## Commands
- Unit tests: `xcodebuild test -scheme Driftly -destination "$DESTINATION" -only-testing:DriftlyTests`
- UITests (snapshots):
  - Photon Rain & Voxel Mirage: `xcodebuild test -scheme Driftly -destination "$DESTINATION" -only-testing:DriftlyUITests/testSnapshotPhotonRainAndVoxelMirage`
  - Ink Topography: `xcodebuild test -scheme Driftly -destination "$DESTINATION" -only-testing:DriftlyUITests/testSnapshotInkTopography`
  - Helper script: `./run-ui-snapshots.sh` (uses DESTINATION env var)
- Launch args (for UITests/UI sanity): `UITestingReset`, `UITestingForceChromeVisible`

## Perf/visual rules
- Preserve visuals; optimizations must keep appearance identical.
- Heavy Timeline views: gate when paused; prefer precomputed constants and size-aware densities.
- Photon Rain: keep precompute path; legacy fallback via `PhotonRainLegacy` arg if ever needed.
- Avoid label swaps for CosmicHeart/SignalDrift (intentional).

## Testing expectations
- Run relevant unit tests after logic changes (AutoDrift, PhaseController, MotionSampling).
- Run snapshot UITests for visual regressions when touching heavy canvas modes (Photon Rain, Voxel Mirage, Ink Topography) if simulator is available.
- If simulators are unavailable in CI, note the skip and why.

## Editing conventions
- Use `apply_patch` for manual edits.
- Keep comments minimal and meaningful; default to ASCII.
- Don’t revert user changes; don’t use destructive git commands.

## Gotchas
- CoreSimulator must be reachable; if CLI fails but Xcode UI works, verify `xcode-select -p`, restart CoreSimulatorService, or recreate the target simulator.
- Some tests depend on chrome visibility; use `UITestingForceChromeVisible` when needed.

Drop this into agents.md at the repo root and adjust destinations/args as you see fit. I’ll read and follow it on future sessions.
