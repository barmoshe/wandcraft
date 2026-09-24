# Stack research: 2D pixel-art roguelite on iOS and Android (2026-09-24)

This note summarizes the research behind [decisions/0001](../decisions/0001-2026-09-24-godot-not-swift.md). Sources were checked in September 2026.

## Native Swift (SpriteKit, Metal, SwiftUI)
- **SpriteKit has stalled.** At WWDC 2025 Apple moved SceneKit to "critical-bug only" maintenance and pointed developers to RealityKit. SpriteKit received nothing and has "no clear successor yet". Sources: https://fatbobman.com/en/weekly/issue-090/ and https://askwwdc.com/q/2694
- **Its performance limits matter for this game.** Sprites batch well from a shared atlas, but physics bodies, `SKShapeNode` and `SKEmitterNode` are weak spots, and every emitter costs a draw call. `SKShader` is fragment-only, and bloom needs an `SKEffectNode` with Core Image or a custom Metal pass. Sources: https://www.hackingwithswift.com/articles/184/tips-to-optimize-your-spritekit-game and https://github.com/twostraws/ShaderKit
- **Swift 6.2 would fit a game loop.** SE-0466 lets a module default to `@MainActor`, which suits a single-threaded update loop.
- **Linux can only test pure logic.** SpriteKit, Metal, UIKit, GameController and Core Haptics are not available on Linux.
- **It cannot target Android**, which rules it out given the requirement to launch on both stores.

## Godot 4.7 (chosen)
- **Current version:** 4.7 shipped 2026-06-19, and the latest stable is 4.7.2 (2026-08-18). 4.7 added iOS HDR output and SDL3 controller support. Sources: https://godotengine.org/releases/4.7/ and https://github.com/godotengine/godot/releases/tag/4.7.2-stable
- **Rendering:** the Mobile renderer runs on Metal on iOS, and Metal builds default to A12 or newer devices. The Compatibility renderer is the fallback. Source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html
- **120Hz ProMotion** support was merged for 4.0. Source: https://github.com/godotengine/godot-proposals/issues/5676
- **Bullets:** scene-tree bullets struggle past roughly 3,000. The fix is `MultiMesh` or drawing through `RenderingServer`. Source: https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html
- **Language:** C# on iOS is experimental (NativeAOT), so we use GDScript. Source: https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/
- **iOS export requires macOS with Xcode.** The editor, headless runs, tests and the Android export all work on Linux.
- **Store plugins:**
  - The official iOS in-app purchase plugin is StoreKit 1.
  - GodotApplePlugins (Miguel de Icaza) covers Game Center, StoreKit 2 and Sign in with Apple, needs iOS 17+ and adds about 2.5 MB. https://github.com/migueldeicaza/GodotApplePlugins
  - godot-storekit2 exists, but its API is not stable yet. https://github.com/godot-sdk-integrations/godot-storekit2
- **The genre has shipped on it:** Brotato and Halls of Torment on iOS.

## Unity 6
- **Pricing:** the runtime fee is cancelled, and Personal is free under $200K. https://unity.com/products/pricing-updates
- **Strengths:** the strongest 2D tooling, and first-party IAP and Game Center support. Magicraft itself is made in Unity.
- **Weaknesses:** binary scene and prefab files are hard for an agent to edit, and iOS builds need macOS or the paid cloud build service.

## Capacitor or a WKWebView wrapper
- **App Store risk:** guideline 4.2 targets thin wrappers, and a self-contained offline game usually passes.
- **Feel:** garbage-collection hitches, audio latency and weaker 120Hz pacing make a premium feel harder to achieve.

## Verdict
Use Godot 4.7 with GDScript. Draw bullets through MultiMesh or RenderingServer. Use GodotApplePlugins and Play Billing for the stores. Build and test on Linux, and export for iOS on the Mac.
