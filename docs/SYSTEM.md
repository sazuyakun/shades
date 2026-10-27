# Shades: system design

How the whole product works. Decided with Soham on 2026-10-17. Product scope and milestones are in [PLAN.md](PLAN.md); the look is in [DESIGN.md](DESIGN.md).

## 1. The system

```
 Taste agent  (Claude Code in ~/shades-playbook)        Builder agent  (Claude Code in this repo)
 ├─ owns Soham's taste: TASTE.md, toolbox, plans         ├─ builds Shades to final-product quality
 ├─ drives Shades through its MCP server ─────────┐      ├─ triages issues into PLAN.md (Soham approves order)
 ├─ ships taste as plugins (~/shades-playbook/plugins)   └─ ports proven code from Nebula
 └─ files issues on sazuyakun/shades (editor-request) ─▶ builder
                                                   │
                    ┌──────────────────────────────▼──────────────────────────────┐
                    │                       Shades.app (local)                    │
                    │  editor UI (manual editing)   ·   MCP server (HTTP, localhost)│
                    │  one action system · one renderer · one project store       │
                    └─────────────────────────────────────────────────────────────┘
```

- **No AI inside the app.** The only AI is Claude Code talking to Shades over MCP. No chat, no prompt box, no API keys.
- **Shades is a real editor** that Soham can use by hand. Everything Claude does, the UI can do, and the other way round.
- **Shades is neutral.** It ships powerful, unopinionated primitives (grading, type, motion, effects, sound). Taste comes from the playbook as plugins.

## 2. One action system, one renderer, one store (from Nebula)
- **Project store:** the open project is one value (`Project`). Every change is a command applied through one path, so undo, autosave, preview refresh, the activity history and MCP all hang off it.
- **Actions:** menus, keyboard shortcuts, the ⌘K palette, buttons and MCP tools all trigger the same actions.
- **Renderer:** preview, frame grabs for Claude, thumbnails and export all draw through the same Metal compositor, so what you see is what you export.

## 3. Format
- **The picture is always 4:3.** Every timeline is a 4:3 picture: **2880×2160 at 24 fps** by default (1440×1080 also available). Frame rate is picked per project (24, 30 or 60).
- **Canvases are added at export**, never edited:
  - YouTube: the picture at 2880×2160, centred in a black 3840×2160 canvas.
  - Reels/Shorts: the picture at 1080×810, centred in a black 1080×1920 canvas.
- **Shorts are ranges of the master**, exported in a batch.
- iPhone 16 footage is 4K 16:9. **Auto-reframe** crops it to 4:3 and pans with the subject like a calm camera operator (a dead zone ignores small drifts, a top speed keeps pans slow, moves ease in and out), or stays locked on one framing; adjustable per clip.


## 4. Layers and depth slots
Every clip can be split by the renderer into **background** and **subject** using its matte (the person or object cut-out). Every text, graphic, sticker or video layer has a **depth slot**:

| Slot | What it does | Example |
|---|---|---|
| In front | Drawn over everything | Captions, corner labels |
| Behind subject | Between the background and the subject | "CHUL" behind Soham |
| Inside subject | Drawn only inside the subject's outline | Silhouette portals |
| Replace background | Replaces the background | Paper cut-out on a red canvas |

The frame is drawn in a fixed order: background → behind-subject layers → subject → inside-subject layers → in-front layers.

## 5. Analysis
Heavy understanding of footage, cached forever per media file in the project:

| Analysis | Engine | When |
|---|---|---|
| Thumbnails, waveforms | AVFoundation | On import (cheap) |
| Transcript with word timings | **WhisperKit** (same version and model folder as Nebula, so the model is shared, not re-downloaded) | On demand |
| Person/object cut-outs (mattes) | **Chosen by a benchmark on Soham's footage**: Apple Vision (+ edge refinement), BEN2 (MIT), BiRefNet (MIT), SAM 2.1 / EdgeTAM (Apache-2.0). GPL and non-commercial models are excluded | On demand |
| Subject tracking (reframe, motion tracking) | Vision tracking / the benchmark winner | On demand |
| Motion in footage (optical flow, for footage motion blur) | Apple Vision optical flow, cached as a small video | When a clip's footage blur is switched on |
| Speech activity, beats, shot changes | Ported from Nebula + Accelerate | On demand |
| Music stems | On-device stem separation (MIT-licensed model) | On demand |

**Scheduling:** heavy jobs queue and run one at a time at low priority. They pause on battery or thermal pressure, show in the toolbar's background-tasks ring, and are readable over MCP.

## 6. Smart tools: propose, review, apply
Rule-based tools (no AI) that write ordinary, editable timeline items, starting with **Polish** for talking-head footage:
- **Scope:** Polish runs on the range you select, never the whole timeline unless you select it all.
- **Automations:** cut silences (only inside clips with speech: a music or B-roll clip on the track is never a pause) and fillers (um, uh, matlab, मतलब, हम्म…), remove retakes (repeated lines in the transcript), snap cuts to beats, punch-in zooms on jump cuts, and audio polish: noise reduction for sound whose background (its quietest tenth, from sound analysis) is louder than −50 dBFS, ducking the music under speech where the speech lands after the cuts, and loudness for a platform (YouTube, Instagram & Reels, TikTok −14 LUFS, podcast −16, broadcast −23) measured on the polished mix, with a limiter holding true peaks under −1 dBTP.
- **Propose, then apply:** Polish first returns a **plan**. It shows as ghost overlays on the timeline (e.g. red stripes for silences) plus a checklist grouped by type with counts. Toggle groups or single items, preview, then apply. Applying is one undo step.
- Over MCP, Claude gets the same plan and applies all or some of it.

## 7. MCP server
- **Our own small server over Streamable HTTP** inside Shades.app, on `127.0.0.1:4747/mcp`, localhost only. Ported from Nebula; no MCP library and **no relay app**.
- Connect: `claude mcp add --transport http shades http://127.0.0.1:4747/mcp`
- **Tool shape:**
  - **Read:** project, timeline, selection, transcript, analysis results, plugins, background jobs.
  - **See:** render a frame, filmstrip, scopes, so Claude checks its own work.
  - **Edit:** one small tool per command, plus a **batch** tool for many edits in one undo step.
  - **Smart:** Polish, captions and other propose/apply tools.
  - **Guide:** a built-in resource that teaches Claude the tools, the layer model and good practice.
- Every MCP change shows live in the editor, glows purple, appears in the History pane, and is undoable per request.
- **Requests:** Claude names each user request with `start_request`; without it, calls less than two minutes apart belong to one request. A snapshot is saved as each request starts. Every step stores what it changed (the saved JSON it replaced, field by field and item by item for lists with IDs), and edits that background jobs make later (stems landing under their clips) are logged under the request that started them. The log is saved with the project (`history.json`).
- **Per-request undo** takes back only what that request changed, even after later edits: clips it added go, clips it removed come back in place, values it changed return. When a later edit changed the same things (or the result would overlap clips or lose media), it's refused and the History pane offers to revert to the snapshot from before the request instead. Over MCP: `get_history` and `undo_request`.


## 8. Plugins (taste lives here)
- **A plugin is a folder with a manifest** that can contain: LUTs, grade recipes, type styles plus font files, title and motion templates (JSON), sticker and overlay packs, SFX packs, and **Metal shader effects** (compiled at runtime). No compiled code, so plugins are safe.
- **Settings → Plugins** holds a list of plugin folders (add, remove, reorder). Each folder is watched and hot-reloaded. Soham's is `~/shades-playbook/plugins`; other users start with `~/Shades/Plugins`.
- The core must support everything a plugin can describe: grades, type, motion, effects, sound.
- Over MCP, Claude can list plugins, use them, and write new ones as files.
- **Format (M5):** a plugin folder holds any of:
  - `plugin.json`: `name`, `description`, `styles` (named text styles: font, size, color, outline_color, outline, shadow, align, anchor, highlight, arc; fields left out keep the caption look) and `templates` (named; `duration` and `layers`, each layer text with `{field}` placeholders or a `sticker`, plus `style`, `reveal`, `start`, `duration`, `transform`, `look`, `motion`, `keyframes`, `depth_slot`, `sound`). Keys may be snake_case or camelCase.
  - `stickers/` (pictures), `overlays/` (movies such as light leaks, dust or film burns), `sounds/` (audio), `fonts/` (registered while loaded), `luts/` (`.cube`), `shaders/` (`.metal` effects).
  - **Overlays** are laid over the footage by `add_overlay` or the timeline's Overlays menu: on a free track above, zoomed to fill the frame, silent, blended with screen by default (so their black drops away). A LUT or shader edited on disk is read again on the next frame.
  - `plugin.json` may also hold `looks`: named grades with effects and a blend mode (a grade recipe).
  - **Shader effects** define `float4 effect(float4 color, float2 uv, float time, float amount, texture2d<half> source, sampler s)`: `color` is the layer's straight (not premultiplied) colour after its grade, `uv` where in its picture, `time` seconds into the clip, `amount` the effect's strength. Shades compiles it with the layer shader at runtime; an edited file recompiles, and compile errors go back to Claude.
  - A folder in Settings is a plugin itself, or holds plugins one level down. Changes reload by themselves; a broken manifest is reported (where and what) in Settings and `list_plugins`.

## 9. Storage
- **Projects:** `~/Shades/<name>.shades`, a package with `project.json`, snapshots, and caches (analysis, mattes, optical flow, proxies). Footage stays where it is on disk and is linked.
- **Proxies:** for 4K HEVC footage, generated in the background so editing stays smooth on 8 GB. Export always uses the originals.

## 10. Export
- **YouTube:** the 16:9 canvas (HEVC or H.264).
- **Reels/Shorts:** the 9:16 canvas, with batch export of master ranges.
- **Frames, GIF and SRT.**
- A background export queue, with a notification and chime when done.

## 11. Quality bar
"Bug-free and performant" means all four gates are enforced:
1. **Golden-frame render tests:** every effect, layer and grade has reference frames. A visual change fails CI unless approved.
2. **MCP scenario tests:** scripted end-to-end edits, like a taste-agent session, run in CI against the real engine.
3. **Performance gates:** benchmarks for playback fps, memory, export speed and analysis time on reference footage. Regressions fail CI.
4. **Real-edit dogfooding:** every milestone ends with a real playbook edit done through MCP. Problems go to the known-issues table.

## 12. Code reused from Nebula
Ported and adapted to Shades' conventions (same author, MIT): the HTTP MCP server, WhisperKit captions, audio (speech activity, ducking, waveforms, noise reduction) and spring physics.
