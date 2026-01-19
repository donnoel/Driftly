# AGENTS.md — Don’s Agent Contract (Apple-platform / Codex)

This file defines how coding agents should work in this repository.
Follow these rules unless a closer (more specific) AGENTS.md overrides them.

---

## Prime Directive
Ship **production-grade Apple-platform code** with clean builds, high performance, and Apple-native UX.
Prefer the **simplest viable solution**. Avoid over-engineering and unnecessary abstractions.

---

## Operating mode (non-negotiable)

- Work **iteratively** with small, testable changes. Avoid large rewrites.
- Prefer **one best recommendation**. Provide alternatives only when tradeoffs are meaningful.
- If uncertain, explicitly state:
  - what is known
  - what is assumed
  - what would change the recommendation
- Surface risks and constraints **early** (API availability, platform limits, performance cost, UX regressions).
- Maintain a calm, practical, “ship-it safely” tone.
- Propose **natural pause points** so the user can build/run/test locally.

---

## Platforms & stack

- Apple platforms only: **iOS / macOS / tvOS** (watchOS only if explicitly requested).
- Language / UI: **Swift, SwiftUI**.
- Tooling: **Xcode**.
- Architecture bias: **MVVM**, clean separation, Apple-native patterns.
- Dependencies: avoid third-party libraries unless explicitly approved; prefer system frameworks.

---

## Quality bar (non-negotiable)

### Build & correctness
- Code must compile cleanly with **zero warnings**.
- Avoid deprecated APIs unless explicitly required.
- Ensure correctness across:
  - edge cases
  - state transitions
  - concurrency safety
  - error paths

### Performance & energy (first-class concerns)
- Treat performance as first-class:
  - no main-thread blocking
  - minimize SwiftUI state invalidations / recompositions
  - avoid unnecessary allocations in hot paths (animations, Canvas, timers)
  - minimize GPU cost (blur, materials, overdraw, offscreen passes)
  - consider battery and thermal impact
- Respect Reduce Motion; avoid large or flashy animations by default.
- When performance is in scope:
  - propose profiling steps (Instruments)
  - define measurable targets or expectations

### Accessibility & Apple-style UX
- Prefer **Apple-native UI patterns** over custom chrome unless there is a clear experiential benefit.
- Accessibility is required:
  - VoiceOver labels
  - Dynamic Type / scalable text
  - Reduce Motion / Reduce Transparency
  - sufficient contrast
  - correct focus behavior (especially tvOS)

### Security & privacy
- Do not introduce insecure patterns:
  - no secrets in the repo
  - use Keychain for sensitive data
  - least-privilege permissions
  - safe networking (TLS, validation where appropriate)
- Be explicit about data flows, storage, and retention.

### Reliability & resilience
- Defensive handling for:
  - network failure
  - decoding errors
  - disk issues
  - permission denial
- Predictable behavior across:
  - app lifecycle
  - background / foreground
  - first-run and empty states
  - corrupted or missing state

---

## Default workflow (implementation changes)

1. **Brief plan** (3–8 bullets) including:
   - files to touch
   - approach and why it’s the simplest viable option
   - risks / tradeoffs
   - test plan
2. Make changes with **minimal edits / commits**.
3. Stop at a natural **pause point** and ask the user to build/run/test locally.
4. If failures occur, diagnose using evidence:
   - logs
   - stack traces
   - reproduction steps

---

## Testing expectations

- Add or update tests when they meaningfully reduce regression risk:
  - unit tests for domain / business logic
  - UI tests only when practical and valuable
- Always include a short checklist:
  - **How I tested**
  - **How you should test**

---

## Git hygiene

- Keep changes tightly scoped; avoid drive-by refactors.
- Provide high-quality commit messages (conventional style acceptable).
- If multiple changes are needed, propose a clear commit breakdown.

---

## Media & provided artifacts (must comply)

- If a ZIP, project, or file is provided: **open and inspect it**.
- If screenshots or photos are provided: **view them**.
- If you cannot open or view something, say so **explicitly and immediately**.
- Never guess about unseen files or media.

---

## Code review mode (when user says “code review”)

Perform a **production-grade code review** covering:

- correctness
- architecture (MVVM / Apple-native)
- code quality & style
- clean builds (no warnings)
- performance (main-thread usage, state mutation, memory / CPU / GPU, caching)
- security & privacy (data handling, permissions, networking, secrets)
- accessibility (VoiceOver, Dynamic Type, Reduce Motion / Transparency, contrast)
- reliability (errors, edge cases, lifecycle)
- platform compliance (iOS / macOS / tvOS guidelines)
- tests (unit / UI, regression coverage)

Conclude every review with:
- the **single best path forward** (prioritized)
- explicit tradeoffs and risks
- an overall **letter grade (A–F)** with a short rubric summary

---