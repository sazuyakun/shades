# Shades: plan (v1)

An open-source, Mac-only video editor that is **lightweight, smooth on a base M1 with 8 GB of RAM, and fully drivable by AI**.
Everything a human can do in the UI, Claude can do through the same commands.

**North star for v1:** edit *"01: I Said Yes"* start to finish in Shades, with Claude doing most of the work.

---

## 1. Architecture

```
Shades.app  (Swift 6 · SwiftUI + AppKit · Metal · AVFoundation · Apple Silicon only · macOS 15+)
│
├── Document     project model (JSON), typed edit commands, undo/redo  ← single source of truth
├── Media        import, bins, analysis, thumbnails, waveforms, proxies
├── Engine       decode → GPU compositor (Metal) → viewer / export
├── Color        color management, grade stack, LUTs, scopes
├── Graphics     titles, shapes, keyframes, templates
├── Audio        mixer, fades, ducking, loudness
├── Captions     on-device transcription, caption track, styles
├── Export       presets, hardware encode, queue
└── MCP          MCP server: every command is an AI tool
        ▲  localhost
        │
Claude Code / Claude Desktop  (your own Pro / Max plan)
```

**Rule:** UI buttons, keyboard shortcuts, undo and AI all go through the same **command layer**. If a command exists, Claude can use it. If Claude can't do something, we add a command, never an AI-only shortcut.

---

## 2. What makes Final Cut smooth, and how we copy it

| # | Technique | In Shades |
|---|---|---|
| 1 | Hardware decode on the media engine | VideoToolbox for H.264/HEVC (all iPhone footage) |
| 2 | Zero-copy frames | IOSurface-backed `CVPixelBuffer` → `CVMetalTextureCache` → Metal texture. No CPU copies, ever |
| 3 | Everything on the GPU | Effects and color fused into as few Metal passes as possible, in a half-float (RGBA16F) working space |
| 4 | Preview at viewer resolution | Play back at 1/2 or 1/4 resolution; render full resolution only when paused or exporting |
| 5 | Proxy / optimized media | Background-generated 1080p ProRes Proxy, switched automatically for heavy or long-GOP clips |
| 6 | Background render cache | When a section can't play in real time, render it to a cache while idle (like FCP's render files) |
| 7 | Read-ahead decode | A frame buffer filled on background queues, reused texture pools, and frames dropped gracefully. Audio never stalls |
| 8 | Audio as the master clock | AVAudioEngine drives time; video is presented on the display link |
| 9 | Cheap timeline drawing | Thumbnails and waveforms precomputed into cached tiles; only the visible part is drawn (Core Animation / Metal) |
| 10 | Memory discipline (8 GB) | Bounded LRU caches, texture pools, and a strict cap on decoded frames held |

**v1 engine strategy (pragmatic):** use `AVComposition` + `AVVideoComposition` with our own **Metal compositor** (`AVVideoCompositing`).
- AVPlayer gives us decode, A/V sync, audio and scrubbing for free.
- Our compositor does every effect and grade.
- Export reuses the same compositor, so **preview = export**.
- If we hit limits later, v2 swaps in a custom playback engine behind the same interface.

---

## 3. The systems (editor side)

### 3.1 Project & document
- `.shades` package: `project.json` plus caches. Human-readable JSON, so diffs work and AI can read it.
- Typed commands with undo/redo. AI edits are grouped into one undo step per request.
- Autosave, crash recovery, multiple sequences per project (e.g. the 4:3 master and 9:16 shorts).
- Opens `shades` CLI project folders (`~/Shades/<year>/<project>/`) directly.

### 3.2 Media system
- Import: drag and drop, folders, the iPhone camera roll export folder.
- Bins / smart collections, metadata, favourites, rejects.
- Analysis (background): shot cuts, people/faces, transcript, loudness, beats.
- Thumbnails / filmstrips and waveform caches.
- Proxies and optimized media, relink, duplicate detection.

### 3.3 Timeline
- Track-based (like Resolve, simpler for AI than a magnetic timeline): video, audio, graphics and caption tracks.
- Blade, trim (ripple / roll / slip / slide), snapping, markers, zoom.
- J/K/L, keyboard-first editing.
- Keyframes with easing, speed changes and speed ramps, freeze frames.
- Transitions, J/L cuts, linked audio.

### 3.4 Effects / VFX
- Transform, crop, opacity, blend modes, masks.
- **Person mask** via Apple's Vision person segmentation (our Magic Mask, needed for "CHUL behind your head").
- Transitions: dissolve, dip, white flash, whip blur, iris, tile wipe, swirl (the flush), hand-over-lens helper.
- Looks: grain, halation, vignette, film burn / light leaks, B&W.
- **Shader effects:** effects are Metal shaders loaded from source, so **Claude can write new effects on the fly**.

### 3.5 Color grading (full system)
- **Color management:** detects the input (Rec.709, iPhone HLG / Dolby Vision, Apple Log). Grades in a linear working space, outputs Rec.709 for web.
- **Grade stack per clip** (serial nodes):
  - Primaries: lift / gamma / gain / offset wheels, exposure, temperature / tint, contrast + pivot, saturation, highlights / shadows.
  - Curves: RGB + luma, hue vs hue / sat / luma.
  - Qualifier (HSL key) and power windows (circle / linear / gradient). Tracking comes in v1.5.
  - Person mask as a window.
  - LUTs (`.cube`).
  - Film look node (grain, halation, vignette).
- Adjustment layers, copy/paste grade, saved looks. Ships with **"Shades Film"** (your warm faded film).
- **Scopes on the GPU:** waveform, RGB parade, vectorscope, histogram.

### 3.6 Graphics & titles
- Text (Core Text), shapes, images, keyframes with easing.
- **Templates in JSON**, ported from the demo: corner labels and ticking clock, CHUL + dictionary card, polaroids, odometer, card stack + GitHub grid, selection box, stat card, reaction cards, bug and die stickers.
- Claude can create new templates by writing JSON.

### 3.7 Audio
- Clip gain, fades, track mixer, pan.
- Auto-ducking music under voice.
- Loudness normalize (−14 LUFS for YouTube / IG).
- Beat detection → markers, so cuts can land on the beat.
- SFX library panel (your Epidemic downloads).

### 3.8 Captions / subtitles
- On-device transcription. Apple's Speech framework where it works, WhisperKit for Hinglish.
- Caption track, styles (your small serif), burn-in or SRT export.
- Bilingual (Hinglish + English) captions.

### 3.9 Export
- Presets: **YouTube 4:3 master**, **Shorts / Reels 9:16 with the 4:3 inset**, ProRes master.
- Hardware HEVC / H.264 encode, background export queue.

### 3.10 App shell
Look and layout are decided in [DESIGN.md](DESIGN.md).
- Viewer, inspector, media browser, timeline, color page.
- Keyboard shortcuts, preferences, dark UI.
- Performance HUD (fps, dropped frames, memory) from day one.

---

## 4. The AI side

### 4.1 How Claude connects (no API key for you)
- Shades runs a local **MCP server**. You connect your own **Claude Code** (CLI, desktop app, or Remote Control from your phone) or **Claude Desktop** to it.
  - Claude Code: `claude mcp add shades …`
  - Claude Desktop: one config entry.
- Your Pro/Max plan is used by **Claude's own apps**, exactly as intended. Shades never sees a token or a login.
- **What we will not build:** a "Sign in with Claude" button inside Shades. Anthropic's terms don't allow third-party apps to offer claude.ai login or plan limits without approval, and that includes apps wrapping the Claude Code CLI. The MCP route sidesteps this cleanly and stays open source.
- **Later, optional:** an in-app chat panel with a bring-your-own API key, for people without Claude Code.

### 4.2 What Claude can do (MCP tools)
| Group | Tools |
|---|---|
| Read | `get_project`, `get_timeline` (JSON), `get_selection`, `list_media`, `get_playbook` (your style.md / taste.md / video plans as resources) |
| See | `render_frame(t)`, `render_filmstrip`, `get_scopes`, `analyze_media` (cuts, transcript, people, beats) |
| Edit | add / move / trim / blade / delete clips, tracks, markers, speed, keyframes, transitions |
| Color | set grade parameters, apply LUT, copy grade, match shots |
| Graphics | add title / template, animate, create template |
| Audio | levels, fades, ducking, add SFX at beats |
| Captions | transcribe, style, burn in |
| VFX | person mask, `write_effect` (a new Metal shader), apply effect |
| Export | export preset, make shorts from ranges |
| Meta | `batch` (many commands at once), `undo`, `checkpoint` |

### 4.3 The loop
**Claude reads the project → plans → runs commands → renders frames and checks scopes to *see* the result → fixes → shows you.**
- Every AI change shows up live in the timeline with an "AI" highlight.
- Each request is one undo step.

### 4.4 Selection-aware AI ("edit this part")
Like Claude Code's VS Code integration, but for clips: select something in the timeline and ask Claude to change *that*.

What travels with a selection: the clips, the time range, the transcript of that range, and a frame or two.

Built in stages:
1. **Selection via MCP (first).** `get_selection` tells Claude what's selected. Select clips in Shades, then tell Claude "make this punchier". Claude asks Shades what "this" is and edits only that. Everything after builds on this.
2. **Selection chat box.** Select clips and a small prompt box appears next to them. By default it hands the request plus the selection to your connected Claude Code, so it runs on your own plan. How seamless that handoff can be needs testing.
3. **API-key mode (in v1).** The same box, answered fully inside Shades with your own Anthropic API key (billed per use).

Stretch: show a "selected clips" badge in Claude Code's prompt the way VS Code does. That would mean using the IDE integration channel, which isn't documented for third-party apps, so it's an experiment, not a promise.

---

## 5. v1 scope, driven by "I Said Yes"

| The script needs | System |
|---|---|
| Cuts on TT pings and beats, J/L cuts | Timeline + beat markers |
| White flash, whip, dissolve, hand-over-lens, swirl (flush) | Transitions + shader effects |
| CHUL behind your head | Person mask + titles |
| Polaroids, frame-in-frame, 3-panel / 2x2 splits | Transform + templates |
| Corner labels, ticking clock, odometer, card stack, reaction cards, stickers | Graphics templates |
| B&W gym, warm faded film look | Color system + "Shades Film" look |
| Speed ramps, freeze frame | Retime |
| Hinglish + English captions | Captions |
| Music, SFX, ducking under VO, stem-style endings | Audio |
| 4:3 master + 9:16 shorts | Sequences + export presets |

**v1 also includes:** advanced color (hue-vs curves, qualifier, power windows, adjustment layers), and every Claude feature: `get_selection`, the selection pop-up, API-key mode, Claude-written effects and Claude-made templates.

**Pushed to v1.5** (not needed for "I Said Yes"):
- Library extras: smart collections, duplicate detection, relink, ratings. v1 has import, bins and favourites.
- Pro trims: roll, slip, slide. v1 has blade, ripple, trim start / end and nudge.
- Extra outputs: ProRes master preset, SRT export, opening `shades` CLI folders. v1 has the YouTube 4:3 and Reel 9:16 presets with burned-in captions.
- Tracking for power windows (already planned for v1.5).

## 6. Milestones
| Milestone | Goal |
|---|---|
| **M0** | Repo, Xcode project, app shell. Import a clip, play it through the Metal compositor. MCP server with ~6 tools. Claude connects, adds a clip and looks at a rendered frame. |
| M1 | Timeline core: tracks, edit / trim / blade, undo, autosave / snapshots, thumbnails and waveforms, the keymap, `get_selection`. **Start editing real footage in Shades from here.** |
| M2 | Audio and captions: clip gain, fades, mixer, ducking, loudness, beat markers; on-device transcription (WhisperKit for Hinglish), caption track and styles. The selection pop-up (Tab) and API-key mode. Claude can now cut by words. |
| M3 | Color: management, primaries, curves (RGB + hue-vs), qualifier, power windows, adjustment layers, LUTs, scopes, Shades Film |
| M4 | Graphics and VFX: templates, transitions, person mask, shader effects, Claude-written effects (`write_effect`) and templates |
| M5 | Export presets and queue, proxies, render cache, performance pass. **Cut "I Said Yes" in Shades** |

Build order is chosen so Claude gets useful early: once the transcript exists (M2), Claude can edit by what was said.

**Honest timeline:** M0 is a day. Full v1 is several weeks of focused work.

### Known issues
Problems found but not fixed yet. **All of them are fixed before M1 starts**, one at a time in this priority order, and the v2 UI restyle comes last. When one is fixed, delete its row in the same commit.

| # | Issue | Found in |
|---|---|---|
| 3 | If the Claude server can't start (e.g. port 4747 in use), the app shows no warning; it's only logged | M0 |
| 4 | Real iPhone footage (HEVC, HDR, rotation) is untested | M0 |
| 5 | Every edit rebuilds the whole playback composition; fine for short projects, slow for long ones | M0 |
| 6 | The app still uses the v1 grey look; DESIGN.md v2 (warm near-black, hairlines, title pill, capsules) is locked | M0 |

## 7. Constraints & setup notes
- Dev machine: **M1, 8 GB RAM, macOS 26**. If it plays smoothly here, it plays smoothly everywhere. That's our benchmark.
- **Minimum macOS: 15 (Sequoia).** Apple Silicon only.
- **Distribution: direct download** from the Shades website (in this monorepo, `apps/web`). Not on the Mac App Store, so no sandbox: Shades can link media where it sits, run its local MCP server, and talk to Claude Code freely. Distributed free: ad-hoc signed, not notarized (no paid Apple Developer Program). Users click "Open Anyway" once in System Settings.
- **Monorepo:** `apps/` holds the products (the Mac app and the website) and `packages/` holds shared code. Details in the code-structure decision.
- Xcode 26.6 is installed. The global command-line tools point at CommandLineTools, so builds set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (no sudo needed).
- The `claude` CLI is installed (`~/.local/bin/claude`).
- License: MIT.
- Launch blockers are tracked in [LAUNCH.md](LAUNCH.md).

## 8. Performance targets
Measured on the M1 8 GB dev machine. The performance HUD shows these live, and each milestone must still meet them.

| What | Target |
|---|---|
| Playback | 4K30 HEVC iPhone footage, 3 video layers + a grade, plays in real time with **0 dropped frames** (preview may drop to half resolution automatically) |
| Scrubbing / skimming | A new frame on screen in **under 50 ms** |
| Edits | Any edit (by hand or by Claude) updates the timeline within **1 frame (16 ms)** |
| Launch | Welcome window in **under 1 s**; a 10-minute project opens in **under 2 s** |
| Memory | Under **1.5 GB** for a 10-minute 4K project while editing |
| Idle | ~0% CPU when nothing is playing or rendering |
| Export | 1080p HEVC exports **faster than real time** (hardware encoder) |
