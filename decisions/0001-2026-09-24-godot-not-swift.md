# 0001. Godot 4.7 with GDScript, not native Swift

- Date: 2026-09-24
- Status: Accepted

## Context
Bar asked whether the mobile rebuild should be written in Swift. The game is a 2D pixel-art twin-stick roguelite: hundreds of projectiles, particles, bloom and lighting, played in landscape. He wants iOS **and Android at launch** (answered 2026-09-24). Development happens mostly through an AI agent in a Linux container. Bar has a Mac for the final iOS build.

Research (`research/stack.md`, sourced) found:
- **Native Swift + SpriteKit:**
  - It is iOS-only.
  - SpriteKit got no updates at WWDC 2025, when Apple moved SceneKit to maintenance mode and pointed developers to RealityKit.
  - None of it can be built or rendered on Linux.
- **Godot 4.7:**
  - 4.7.2 (August 2026) is MIT-licensed and exports to iOS (Metal) and Android (Vulkan).
  - The same genre shipped on iOS with it (Brotato, Halls of Torment).
  - Scenes and scripts are text files the agent can edit.
  - The editor, headless tests and Android export all run on Linux. Only the iOS export needs macOS with Xcode.
- **Unity 6:** the runtime fee is cancelled, but its binary scene and prefab files are hard for an agent to edit, and the tooling is heavier.
- **A Capacitor web wrapper:** weaker frame pacing and audio for this genre.

## Decision
**Build in Godot 4.7.2 with typed GDScript, on the Mobile renderer.**
- Bullets are data-oriented and drawn through MultiMesh or RenderingServer, not as nodes.
- C# is not used: on iOS it is experimental and uses NativeAOT.
- Hot paths can move to GDExtension C++ later if profiling asks for it.

## Consequences
- One codebase ships to both stores. Android builds can run in this container; iOS builds on Bar's Mac, or later on a cloud macOS runner.
- Store features come from plugins: GodotApplePlugins (Game Center, StoreKit 2, iOS 17+) and the Google Play Billing plugin. Pin their versions and test them early.
- Rich Core Haptics needs a small custom plugin. Basic vibration works out of the box.
- The v1-v5 JavaScript is not reused as code. Its proven rules are ported as typed GDScript, with tests.
