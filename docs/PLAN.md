# Shades: plan

An open-source, Mac-only video editor that is **powerful, smooth on a base M1 with 8 GB of RAM, and fully drivable by Claude over MCP**. This is the **final product**, not an MVP: complete, bug-free and fast.

How the system works is in [SYSTEM.md](SYSTEM.md). The look is in [DESIGN.md](DESIGN.md), behaviour and keymap in [UX.md](UX.md), and code layout in [ARCHITECTURE.md](ARCHITECTURE.md).

**North star:** the taste agent (Claude in `~/shades-playbook`) cuts *"01: I Said Yes"* start to finish in Shades, using Soham's taste plugins, with no fallback to Resolve. Soham makes that edit separately after M8; the build ends with a showcase video instead.

---

## 1. Product scope
Everything below is in the final product. "Core" means built into Shades; taste-specific looks come from playbook plugins built on these primitives.

| Area | Core capabilities |
|---|---|
| **Project & timeline** | `~/Shades` library, autosave, snapshots, crash recovery. 4:3 timelines (2880×2160 or 1440×1080; 24/30/60 fps). Multiple video, graphics, caption and audio tracks. Blade, trim, ripple, move, snapping, markers, keyframes with easing and springs, speed changes and ramps, freeze frames, linked audio, undo/redo |
| **Media** | Import with footage linked in place, proxies for 4K HEVC, thumbnails and waveforms, real iPhone 16 footage (HEVC, rotation) |
| **Layers & VFX** | Depth slots (in front, behind subject, inside subject, replace background), transforms, crop, opacity, blend modes, masks, **auto-reframe 16:9→4:3**, **motion tracking**, transitions (cut, flash, dissolve, blackout, whip, tile/slice wipes, portals), Metal shader effects (from plugins too) |
| **Cut-outs** | Person and object mattes (engine chosen by benchmark), edge refinement, temporal smoothing, cached |
| **Type & motion** | Core Text rendering into Metal, per-word layers from the transcript, kinetic type, text on paths, **3D type and camera** (tilt, bend, depth, endless-zoom portals), title and motion templates from plugins, stickers and overlays |
| **Color** | Color management for iPhone footage, primaries, curves, LUTs, qualifiers, windows, film-look primitives (grain, halation, vignette), scopes, grade recipes from plugins |
| **Speech & captions** | WhisperKit transcripts with word timings (Hinglish), caption tracks and styles, SRT, text-based editing |
| **Polish** | Rule-based, on a selected range, propose → review → apply: silences and fillers, retakes, beat-snapped cuts, punch-in jump cuts, audio polish |
| **Audio** | Clip gain, fades, track mixer, ducking, loudness to platform targets, noise reduction, beat detection, **stem separation**, SFX from plugins |
| **Export** | YouTube 16:9 canvas, Reels/Shorts 9:16 canvas with batch shorts, frames, GIF, SRT, background queue |
| **Claude (MCP)** | Built-in HTTP MCP server, granular + batch + propose/apply tools, see tools (frames, scopes), built-in guide, History pane with per-request undo |
| **Plugins** | Data + Metal shader plugins, plugin folders configurable in Settings (multiple), hot reload |

**Not in Shades:** any in-app AI (chat, prompt boxes, API keys). The only AI is Claude Code over MCP.

## 2. Milestones
Each milestone ends with all four quality gates green ([SYSTEM.md §11](SYSTEM.md)) and a real playbook edit done through MCP.

| Milestone | Goal |
|---|---|
| ~~**M0**~~ | ✅ Foundation: modules, Metal compositor, player, basic UI, first MCP tools, CI and enforcement |
| ~~**M1 · UI**~~ | ✅ Build the locked v2 look ([DESIGN.md](DESIGN.md)) **without the Tab prompt**. Add the History pane (⌘L), the connection pill, Settings (including plugin folders) |
| ~~**M2 · Timeline core + MCP**~~ | ✅ First the quality-gate harnesses (golden frames, MCP scenarios, performance benchmarks), then Project library and save/load, New Project (2880×2160 @ 24 by default), multi-track timeline with all core edits and undo, the layer model with depth slots, proxies, the single action system and ⌘K, and the **new HTTP MCP server** (granular, batch, guide) replacing the relay and SDK |
| ~~**M3 · Speech & Polish**~~ | ✅ Background-tasks ring (the first background jobs arrive here), WhisperKit transcripts and captions (ported), text-based editing, Polish with propose/review/apply, speech activity and beats (ported) |
| ~~**M4 · Cut-outs & tracking**~~ | ✅ Matting benchmark on playbook footage → Apple Vision. Smoothed, cached mattes, depth-slot rendering, the subject's path and auto-reframe. Motion tracking moved to M5, where following needs keyframes |
| ~~**M5 · Type, motion & plugins**~~ | ✅ Keyframes with easing and springs, motion tracking and follow, the text engine (styles, kinetic reveals from the transcript), 3D layers and a camera, stickers (die-cut look, motion presets, cut-outs from a frame), hand-drawn boiling drawings, and the **plugin system** (styles, templates, stickers, sounds, fonts) with hot reload |
| ~~**M6 · Color & effects**~~ | ✅ Grading (primaries, curves, LUTs, qualifiers, windows), blend modes, film-look primitives (grain, vignette, halation, blur), green-screen keys, adjustment clips, scopes, transitions (dissolve, dip, flash, whip, push, slices, tiles, iris portal), Metal shader effects from plugins and Claude, grade recipes (looks), bent text |
| ~~**M7 · Audio**~~ | ✅ Waveforms, the Audio inspector (volume keyframes, fades, track and master levels), ducking music under speech, loudness to a target (BS.1770), noise reduction (ported), stem separation (HTDemucs on CoreML: voice and music), sound effects from plugins (`add_sound`) |
| ~~**M8 · Export & performance**~~ | ✅ Canvases (YouTube 16:9, Reels/Shorts 9:16), marked shorts exported in a batch, frames, GIFs, SRT, the ⌘E sheet and `export` tool on the background queue with a chime and notification, the performance pass (render cache not needed, see below) and a full test round. Showcase: *Shades Showcase* (39 s, `~/Shades`), made over MCP from playbook footage with every capability |

**Rough effort:** about **10–12 weeks** of focused work in total, depending on review speed and what the real edits turn up.

**Build decisions (2026-10-17):** test with footage already in `~/shades-playbook` (read-only). Cut-out and stem models: MIT/Apache only, converted to CoreML on this Mac, benchmarked against Apple Vision, downloaded by Shades on first use (never bundled). Check-ins: a summary with screenshots after each milestone, then keep going.

**Matting engine (2026-10-19):** Apple Vision, nothing to download. Benchmarked on playbook frames (M1, per frame): Vision person (accurate) 60–130 ms, Vision foreground 25–35 ms, BiRefNet-lite (MIT, converted to CoreML) 830–890 ms on the GPU. Vision is as clean as BiRefNet on talking heads; BiRefNet alone found the riders in a busy street shot, but at 10× the time, a ~100 MB hosted download and a graph the Neural Engine can't compile, so it doesn't ship. Revisit if the playbook asks for cut-outs of non-people in cluttered shots.

**Stem separation (2026-10-19):** HTDemucs (Meta, MIT) converted to CoreML with its STFT left out: Swift makes the spectrogram exactly as Demucs does (`StemSpectrogram`) and the network runs on the GPU in half precision (within 0.2% of PyTorch). It splits sound into voice and music (drums, bass and the rest summed), about 6× faster than realtime on the M1. The Neural Engine is skipped, as compiling for it can hang for hours. The model (~100 MB) downloads on first use into `~/Library/Application Support/Shades/Models`.

**Colour management (2026-10-19):** footage is SDR Rec.709 (iPhone 16, HDR off), so Shades grades in display-referred Rec.709/sRGB: frames are decoded as 8-bit BGRA, graded in the layer shader and exported in Rec.709. HDR and wide-gamut grading aren't in scope.

### Issues from the playbook
The taste agent files issues on `sazuyakun/shades` with its `editor-request` skill. The builder agent assesses each one, maps it to core capabilities (often it's a plugin built on existing core, not new core), estimates it, slots it into a milestone, and tells Soham. **Soham approves the order.** An issue closes only with tests plus a real-edit check.

### Known issues
Problems found but not fixed yet. When one is fixed, delete its row in the same commit.

| # | Issue | Fix in |
|---|---|---|
| 12 | `normalize_loudness` can't reach −14 LUFS when sound effects pile up: without a limiter it holds the master back to keep peaks under −1 dBFS (the showcase landed at −17.4 LUFS). Needs a true-peak limiter on the mix (an audio tap on export and playback) | After M8 |
| 11 | The stem model isn't hosted yet, so its first-use download fails until the `models-1` release asset is published (needs Soham's yes) | M7 |

## 3. Constraints & setup notes
- Dev machine: **M1, 8 GB RAM, macOS 26**. If it plays smoothly here, it plays smoothly everywhere. That's our benchmark.
- **Footage:** iPhone 16 (base), 4K, 24 fps (60 fps for slow motion), HDR off.
- **Minimum macOS: 15 (Sequoia).** Apple Silicon only.
- **Distribution: direct download** from the Shades website (`apps/web`). No sandbox. Free: ad-hoc signed, not notarized.
- **Monorepo:** `apps/` holds the products and `packages/` holds shared code.
- Xcode 26.6; builds set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- License: MIT. Any bundled model or library must be MIT, Apache-2.0 or similar: no GPL, no non-commercial.
- Launch blockers are tracked in [LAUNCH.md](LAUNCH.md).

## 4. Performance targets
Measured on the M1 8 GB dev machine with real iPhone 16 footage. The performance HUD shows these live, and CI's performance gates enforce them.

| What | Target |
|---|---|
| Playback | 2880×2160 @ 24 timeline from 4K HEVC footage, 3 video layers + a grade + a behind-subject text layer, in real time with **0 dropped frames** (preview may use proxies or half resolution) |
| Scrubbing | A new frame on screen in **under 50 ms** |
| Edits | Any edit (by hand or by Claude) updates the timeline within **1 frame** |
| Launch | Library window in **under 1 s**; a 10-minute project opens in **under 2 s** |
| Memory | Under **1.5 GB** for a 10-minute 4K project while editing |
| Idle | ~0% CPU when nothing is playing, rendering or analysing |
| Analysis | Never makes the editor stutter; pauses on battery or thermal pressure |
| Export | YouTube 4K HEVC exports **faster than real time** for plain cuts (hardware encoder) |

**Measured at the M8 performance pass (2026-10-19, M1 8 GB, debug build):** three 4K HEVC layers with a grade, grain, vignette and a behind-subject title play at 24–25 fps (from proxies) using 133 MB. A 31-minute, 60-clip project reopens in 0.4 s, plays at 25 fps and uses 130–145 MB. Launch to an open project takes 0.7 s. Idle CPU is 0.2–0.4%. A 28.5 s timeline exports to 3840×2160 HEVC in 15 s. CI gates export speed (faster than real time), frame render time and memory growth.

**Render cache (2026-10-19): not built.** The playback target already runs in real time, so pre-rendering heavy stretches would add a cache to keep in step with every edit for no gain. Revisit if real edits with shader effects or several cut-outs drop frames.
