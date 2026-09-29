# The hero's look and motion: sourced notes (0.26)

Bar asked for a better hero. A 3/4-view redraw was tried and rejected ("It was better before"). It is kept on the branch `claude/hero-3-4-experiment`. Bar then asked for web research. These notes are that research, and they led to ADR 0038: keep the front-facing hero he liked, polish its pixels, and fix its motion.

## Sourcing caveat
- The research proxy blocked direct page fetches on most sites. GitHub was reachable.
- The Celeste numbers come from the game's published source (`NoelFB/Celeste`, `Player.cs`).
- Everything else comes from search excerpts of the linked pages. Check a number before building on it.

## What other games do
- **Aim decides the facing, not movement.** Nuclear Throne flips the character toward the mouse and runs it backwards when you move against your aim ([Careless Labs](https://carelesslabs.wordpress.com/2018/04/03/nuclear-throne-style-weapon-movement-libgdx-gamedev/)). Its player sheets are small: idle 4, walk 6, hurt 3, dead 6 frames ([NTT custom graphics FAQ](https://itch.io/t/33311/custom-graphics-faq)).
- **Enter the Gungeon** moves the hands with each gun, frame by frame, so the grip is never a fixed arm ([Gun Animation Editor mod](https://modworkshop.net/mod/31323/post/132112)). Its sprites stay under about 30x30 px ([EtG modding guide](https://mtgmodders.gitbook.io/etg-modding-guide/all-things-spriting/important-sprite-creation-information.)).
- **Running and shooting is an upper/lower split.** Metal Slug builds its hero from two sprites so the legs run while the torso shoots ([Metal Slug tutorial](https://6th-divisions-den.com/ms_tutorial.html)). Slynyrd's run 'n gun keeps the legs looping "irrespective" of the top half ([Pixelblog 60](https://www.slynyrd.com/blog/2026/1/26/side-view-run-n-gun)).
- **Extra views multiply the work.** Moonlighter's note on 4-view sprites ([80.lv](https://80.lv/articles/moonlighter-building-pixel-art-preparing-for-switch)) supports one front view, mirrored.

## Animation at small sizes
- **Run bob.** Slynyrd's top-down run is 6 frames. The bob is uneven: down 1 px, down 1 px, up 2 px, per stride. He says a smooth sine bob "looks a bit robotic" ([Pixelblog 55](https://www.slynyrd.com/blog/2025/3/24/pixelblog-55-top-down-character-animation)).
- **Run lean.** A run leans the head and torso forward ([Pixelblog 60](https://www.slynyrd.com/blog/2026/1/26/side-view-run-n-gun)).
- **Arm swing.** The free arm swings against the lead leg ([Pixelblog 22](https://www.slynyrd.com/blog/2019/10/21/pixelblog-22-top-down-character-sprites)).
- **Timing.** Hold on the extremes; attacks read as anticipation, fast frames, then a long hold ([Pixelblog 56](https://www.slynyrd.com/blog/2025/5/23/pixelblog-56-top-down-character-attack-animation), [Saint11](https://saint11.art/pixel_art_articles/article3/)).
- **Noise.** Single pixels that flicker between frames make motion harder to read ([Pixelblog 58](https://www.slynyrd.com/blog/2025/10/2/pixelblog-58-top-down-character-animation-part-3)).
- **Readability.** Coloured outlines rather than black; asymmetry and protruding parts make a silhouette ([Sprite-AI style guide](https://www.sprite-ai.art/blog/2d-pixel-art-style-guide)).
- **Squash and stretch** by whole pixels: Celeste scales to (0.6, 1.4) on a jump and eases back at 1.75/s, at 320x180 ([Player.cs](https://github.com/NoelFB/Celeste/blob/master/Source/Player/Player.cs)).

## Feedback (not adopted in 0.26; candidates)
- **Hurt:** a white flash of 1-2 frames, an i-frame flicker every 0.05 s (Celeste), and a 0.05-0.2 s hitstop ([CritPoints](https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/)). Wandcraft already has the hitstop, a screen flash and the flicker.
- **Dash:** Celeste freezes 0.05 s at the start, spawns afterimages at the start, at +0.08 s and at the end, and bursts 4-8 dust particles ([Player.cs](https://github.com/NoelFB/Celeste/blob/master/Source/Player/Player.cs)). Wandcraft already has the afterimages.
- **Footfalls:** Alx Preston credits Hyper Light Drifter's feel to "little dust clouds or how a character's foot stops" ([The Skinny](https://www.theskinny.co.uk/tech/gaming/alex-preston-on-hyper-light-drifter)).
- **Recoil:** move the gun back along the aim, and nudge small sprites back a couple of pixels ([Ash Hamnett](http://ahamnett.blogspot.com/2012/07/top-down-shooters-and-recoil.html)). Wandcraft already kicks the wand back 2 px.

## What 0.26 took from this (ADR 0038)
- The legs keep running while he fires (the upper/lower split, done as a `run_cast` clip that shares the run's legs and phase).
- The run: Slynyrd's uneven bob, a 1 px head lead, the free arm swinging against the stride, and the run played backwards when backpedalling (Nuclear Throne).
- A burst of fire holds one lean instead of rocking on every shot (hold on the extreme).
- The wand stays in the fist through the bob (Gungeon's hands move with the body).
- A pixel polish that keeps the design: a sheen through the quiff, beard strands, collar points, a buckle, the inner shade of each trouser leg, rolled cuffs, toe shines.
