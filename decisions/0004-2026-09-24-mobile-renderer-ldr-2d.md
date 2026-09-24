# 0004. Mobile renderer with LDR 2D, lit by 2D lights; glow by brightness threshold

- Date: 2026-09-24
- Status: Accepted (to re-check on a real iPhone and Android phone at the first device build)

## Context
The plan left the renderer to an early spike: the Mobile renderer (Metal on iOS, Vulkan on Android) for 2D glow and HDR, with the Compatibility renderer as a fallback tier. The M1 room needs 2D lighting to read well: a dim ambient `CanvasModulate`, with warm torches and a cool light around the wizard.

The spike rendered the same frame three ways under Xvfb with Mesa llvmpipe/lavapipe (`tools/shots.sh`):

| Setup | 2D lights |
|---|---|
| Mobile renderer, `hdr_2d` on | missing: the room was uniformly dark |
| Mobile renderer, `hdr_2d` off | correct |
| Compatibility renderer | correct |

## Decision
- Keep the **Mobile renderer**, with `rendering/viewport/hdr_2d=false`.
- Glow still comes from `WorldEnvironment` (canvas background mode). It uses an LDR threshold of 0.72, so only the brightest pixels bloom: spell cores, flames and sparks.
- **Emissive things live on their own layer.** Bullets, spell effects, damage numbers and torch flames sit on a `CanvasLayer` that follows the camera. The ambient `CanvasModulate` darkens only the room and the actors, never the magic.

## Consequences
- Colors pushed above 1.0 in code clamp to 1.0. Brightness comes from light colors and the glow threshold, not HDR values.
- **The llvmpipe result may not match real hardware.** At the first TestFlight and Play internal build, check the frame from `tools/shots.sh` against a device capture. If Metal handles `hdr_2d` with lights correctly, we can revisit.
- The Compatibility renderer also rendered the room correctly, so it stays a viable low-end tier (M4 quality settings).
