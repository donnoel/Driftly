# 🌌 **Driftly**
### *A premium ambient “lava-lamp” app for cosmic gradients, slow motion, and calm.*

<p align="center">
  <img src="https://img.shields.io/badge/SwiftUI-Canvas-orange?logo=swift">
  <img src="https://img.shields.io/badge/Platforms-iOS_26.1_|_tvOS_18-blue">
  <img src="https://img.shields.io/badge/Modes-30-purple">
</p>

---

## ✨ What is Driftly?

**Driftly** is a fullscreen ambient light object — a pocket-sized “nebula lamp” that slowly shifts through **cosmic gradients**, **liquid motion**, and **abstract generative visuals**.

It’s intentionally not a utility. Driftly is the app you leave running on a nightstand, on an iPad dock, or on a TV when you want your space to feel *different*.

---

## 💎 Core Features

| Feature | Description |
|--------|-------------|
| 🌈 **30 Ambient Modes** | A curated gallery of “Cosmic Liquid” gradients plus abstract, line-based generative modes. |
| 🫥 **Minimal UI Chrome** | Fullscreen experience with tiny controls that fade away. |
| 🔁 **Auto Drift** | Automatically cycles modes on a timer (with shuffle + favorites-only options). |
| 🌙 **Sleep Timer** | Set a timer and Driftly gently powers down the visuals. |
| ☀️ **Brightness Edge Gestures** | Drag up/down on screen edges to adjust in-app brightness (clamped with haptic feedback). |
| 🌀 **Motion Parallax** | Optional subtle motion parallax using device motion for extra depth. |
| 💾 **Persistence** | Remembers mode, brightness, chrome visibility, auto-drift settings, favorites, and ordering. |
| 📺 **tvOS Support** | Includes a tvOS target for big-screen ambient Driftly vibes. |

---

## 🎛 Controls (by design: tiny)

- **Tap** to show/hide controls  
- **Tap mode name** to open the mode picker  
- **Drag screen edges** to adjust brightness  
- **Auto Drift** to let Driftly “DJ” the modes for you  
- **Sleep Timer** when it’s time for the lights to go out

---

## 🎨 Modes

A mix of cosmic-liquid gradients and “generative art gallery” modes:

- **Nebula Lake**
- **Cosmic Tide**
- **Aurora Veil**
- **Abyss Glow**
- **Starlit Mist**
- **Lunar Drift**
- **Solar Bloom**
- **Plasma Reef**
- **Velvet Eclipse**
- **Neon Kelp**
- **Ember Drift**
- **Pulse Aurora**
- **Vital Wave**
- **Echo Bloom**
- **Cosmic Heart**
- **Signal Drift**
- **Horizon Pulse**
- **Photon Rain**
- **Gravity Rings**
- **Drift Grid**
- **Quiet Signal**
- **Chromatic Spine**
- **Ribbon Orbit**
- **Ink Topography**
- **Prism Shards**
- **Lissajous Bloom**
- **Meridian Arcs**
- **Spectral Loom**
- **Voxel Mirage**
- **Halo Interference**

---

## 🛠 Built With

- **SwiftUI**
- **Canvas** + **TimelineView** (smooth infinite animation)
- **Combine** (timers & reactive state)
- **Core Motion** (subtle parallax via `DriftMotionManager`)
- **UserDefaults** persistence (via `DriftlyEngine`)

---

## 🧠 Architecture Overview

### **DriftlyEngine**
The single source of truth for the app:
- Current mode
- Brightness
- Chrome visibility
- Auto-drift settings (interval, shuffle, favorites-only)
- Favorites + mode display ordering
- Sleep timer end date

### **SleepAndDriftController**
Owns the logic for:
- Auto drift timing
- Sleep timer expiration
- “tick” updates (driven from `DriftlyRootView`)

### **DriftlyRootView**
The full-screen shell:
- Renders the active mode view
- Presents the mode picker + settings
- Handles brightness edge gestures
- Coordinates motion + idle timer policy

### **Mode Views**
Each mode is its own `SwiftUI.View` (mostly Canvas-driven), enabling a clean “gallery” architecture.

---

## 📁 Project Structure

```
Driftly/
├── App/
│   ├── DriftlyApp.swift
│   ├── DriftMode.swift
│   ├── DriftEnvironment.swift
│   ├── DriftAnimationPauseKey.swift
│   └── IdleTimerPolicy.swift
├── Engine/
│   └── DriftlyEngine.swift
├── Features/
│   ├── DriftNoise.swift
│   ├── DriftMotionManager.swift
│   ├── MotionPhaseHandler.swift
│   ├── PhaseController.swift
│   └── SleepAndDriftController.swift
├── Haptics/
│   └── DriftHaptics.swift
├── Views/
│   ├── DriftlyRootView.swift
│   ├── DriftModePickerView.swift
│   ├── DriftlySettingsView.swift
│   ├── DriftLiquidLampView.swift
│   └── (Mode Views…)
└── Assets.xcassets/
    └── AppIcon.appiconset, colorsets, etc.
```

Also included:
- `DriftlyTV/` (tvOS target)
- `DriftlyTests/` + `DriftlyUITests/` + tvOS test targets

---

## 🧪 Tests

`DriftlyTests` covers core behavior such as:
- Auto-drift timing
- Sleep timer state transitions
- Brightness clamping
- Motion sampling + phase handling
- Idle timer policy behavior
- Root view initialization (test overrides)

---

## 🚀 Getting Started

1. Open `Driftly.xcodeproj` in Xcode  
2. Select a scheme:
   - **Driftly** (iOS / iPadOS)
   - **DriftlyTV** (tvOS)
3. Build & run on a simulator or device

> Tip: Driftly is designed to feel best at full-screen brightness in a dim room. (Yes, that’s a feature request disguised as vibes.)

---

## 🗺️ Roadmap

- [ ] **Share** (export a “moment” as an image / short loop)
- [ ] More curated mode sets (Night, Deep Space, Minimal, etc.)
- [ ] Music-reactive mode (gentle, not disco)
- [ ] Custom color blends
- [ ] Onboarding (minimal, skippable)

---

## ❤️ Credits

Built with care by **Don Noel** and **Bella**, my AI collaborator ✨

---

> *Driftly should feel like a lava lamp found in deep space — slow, hypnotic, and weirdly comforting.*
