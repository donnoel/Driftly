## Project intent

Driftly is a premium ambient “liquid lamp” experience for iOS, iPadOS, and tvOS.
Primary goals:
- Butter-smooth animation (no hitching, no flashing, no stutters)
- Apple-native UI/UX (tvOS focus, Settings feel, onboarding)
- Correctness and reliability across platforms
- Clean builds, no warnings

Non-goals:
- Over-engineering or large rewrites
- Adding third-party dependencies unless explicitly requested

## Platforms and constraints

- Platforms: iOS + iPadOS + tvOS
- UI: SwiftUI
- Prefer Apple-native APIs and patterns.
- Treat tvOS as performance-critical and focus-state correctness as first-class.

Key policies:
- Respect Reduce Motion everywhere.
- Avoid state mutation during view update (“Modifying state during view update…” is a blocker).
- Avoid “skip draw => blank frame” patterns that cause flicker.

## Working style (how to make changes)

- Make small, testable changes. One “unit of change” per commit.
- Prefer one best recommendation; alternatives only with meaningful tradeoffs.
- If uncertain, state:
  - what is known
  - what is assumed
  - what would change the recommendation
- Surface risks early (perf regressions, focus issues, cross-platform behavior).
- Pause points are required: after each meaningful change, instruct Don to build/run and verify.

## Performance rules (non-negotiable)

Performance is a feature. Optimize for consistent frame pacing.

### Avoid these patterns
- Mutating `@State` or publishing (`@Published`) from inside `body`, `Canvas` render closures, `GeometryReader` branches, or computed properties called during render.
- “Gating” by returning `Color.clear` or early-returning from `Canvas` such that a frame draws nothing (causes flashing).
- Periodic main-thread timers that do work during animation unless proven safe.
- Reassigning the same value to `@Published` properties (causes unnecessary invalidations).

### Prefer these patterns
- If throttling is needed, throttle the **timeline cadence** (e.g. `TimelineView(.periodic(...))`) rather than skipping draw output.
- Make assignments idempotent: only set state when it actually changes.
- Keep expensive computation out of hot render paths; precompute and cache.
- For tvOS: minimize main-thread work while animation is active.

### Profiling expectations
When addressing hitching:
- Prefer Instruments (Time Profiler + Core Animation) and correlate stutters with timers, allocations, or view invalidations.
- If a fix is speculative, include a simple in-app logging hook (temporary, dev-only) to confirm cadence and root cause.

## Architecture conventions

- SwiftUI + MVVM-ish structure (where present); avoid introducing new architectural layers unless necessary.
- DriftlyRootCoordinator / engine logic should be deterministic and testable.
- Rendering views (modes) should be:
  - free of side effects during render
  - stable under frequent ticks
  - compatible with Reduce Motion

## Mode rendering rules

For mode views (Aurora Veil, Cosmic Tide, Lunar Drift, Signal Drift, etc.):
- Rendering must not depend on mutating state during the draw pass.
- If you need time-based animation:
  - use TimelineView/PausableTimelineView
  - drive visuals from `context.date` / phase calculations
- Any “phase anchor” resets must happen via lifecycle modifiers (`onAppear`, `onChange`) not in `currentPhase()`.

## Auto-Drift policy

Auto-Drift is performance-sensitive on tvOS.
- Do not enable Auto-Drift by default.
- If features are gated (Labs/Experimental), enforce at runtime:
  - no timers/scheduling when gated off
  - tvOS may be disabled entirely for release stability
- Any shuffle/peek APIs must not mutate state unless explicitly “advance”.

## UI/UX guidelines (Apple-first)

- Prefer Apple’s standard spacing, typography, and focus behavior.
- tvOS:
  - focus ring/scale must be stable (no jitter)
  - navigational hierarchy should feel like Apple TV patterns
- Settings:
  - roomy, readable, not cramped
  - clear grouping and consistent row height
- Onboarding:
  - premium look (minimal text, clear value, polished imagery)
  - 3–5 screens max unless specified otherwise

## Build cleanliness

- No new warnings.
- No debug prints left in shipping builds.
- Platform-specific code must be guarded with `#if os(tvOS)` etc.
- Ensure iOS/iPadOS builds aren’t broken by tvOS changes (and vice versa).

## PR/commit expectations

Each commit should include:
- What changed (bullets)
- Why (one sentence)
- Risk/impact (perf, UI, behavior)
- Any follow-up test suggestion (what to click / what mode to run)

## When blocked

If you cannot confidently identify the root cause:
- propose the smallest diagnostic change that confirms/denies the top hypothesis
- include where to observe it (log points, Instruments markers, reproduction steps)
- do not proceed with broad refactors
