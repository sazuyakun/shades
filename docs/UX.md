# Shades: user experience

How Shades behaves. The look is in [DESIGN.md](DESIGN.md).

**Principle:** one hand on the mouse, the other on the keyboard for edits. Claude is one key away and never in the way.

## Getting in
| Moment | Behaviour |
|---|---|
| Opening Shades | A small native welcome window: **New Project**, recent projects with thumbnails, and "drop footage here" |
| New project | Name it and pick a preset: **YouTube 4:3**, **Reel 9:16**, **ProRes master** or **Custom** (resolution, fps) |
| Importing | Media stays where it is on disk; Shades links to it and copies nothing. "Collect media" copies into the project later if wanted |
| Background work | Thumbnails, waveforms, transcripts and proxies run quietly. A progress ring sits in the toolbar; click it for details. Nothing blocks editing |
| Sequences | Tabs above the timeline ("4:3 Master · Reel 1 · Reel 2"). Switching tabs reshapes the viewer to match |

## Editing by hand
- **Choosing a range:** hover-scrub a thumbnail in the media browser and press **I** / **O** to mark just the part you want. There's no separate source viewer.
- **Dragging onto the timeline inserts**: later clips move right. Hold **⌘** while dropping to overwrite instead.
- **One-key edits** put the marked part on the timeline without dragging: **R** append to end, **Z** insert at playhead, **⌥Z** overwrite at playhead, **C** place on top (the track above, for B-roll).
- **Linking:** a clip's own audio moves with it (**⇧⌘L** to unlink). Clips on other tracks stay where they are.
- **Deleting leaves a gap** (lift). **⇧⌫** is ripple delete, and **D** closes all gaps.
- **Keyboard:** Final Cut shortcuts as the base, with the creator's DaVinci Resolve customizations on top. Editing lives on the left hand.

![Shades keymap](design/keymap.png)

| Key | Action |
|---|---|
| A · B · T | Select tool · Blade tool · Trim tool |
| S · ⌘B | Split at playhead |
| Q · W | Ripple trim start / end to playhead |
| ⇧Q · ⇧W | Trim start / end to playhead (no ripple) |
| R · Z · ⌥Z · C | Append · Insert · Overwrite · Place on top |
| E · ⌘Z | Undo |
| ⌃R · ⇧⌘Z | Redo |
| D | Delete gaps |
| ⌫ · ⇧⌫ | Delete (leave gap) · Ripple delete |
| V · ⇧V · Y | Select nearest edit · Select clip at playhead · Select forward |
| I · O · X · M · G · F | Mark in · Mark out · Mark clip · Marker · Flag · Match frame |
| Space · J K L | Play / pause · Reverse / stop / forward |
| ← → · ↑ ↓ | Frame step · Previous / next clip |
| , . · ⇧, ⇧. | Nudge 1 frame · 5 frames |
| N | Snapping on / off (on by default) |
| ⌥⌘J | Join clips |
| ⌥↑ · ⌥↓ | Move clip up / down a track |
| ⌘= · ⌘− · ⇧Z | Zoom in / out / fit |
| ⇧⌘L | Link / unlink audio and video |
| ⌘S · ⌘E | Named checkpoint · Export |
| **Tab** · ⌘K | **Ask Claude** about the selection |
| Esc | Close the prompt · stop Claude |

All shortcuts are remappable.

## Working with Claude
1. **Select** clips or a range. A small ✨ button appears next to the selection.
2. **Press Tab** (or click ✨, or ⌘K). The prompt opens next to the selection, showing what it will send: clips, time range, transcript, frames.
3. **Type and press Return.** The prompt shrinks to a status pill ("Cutting pauses… 12/47") with **Stop**.
4. **Edits happen live** on the timeline. Changed clips glow soft purple, then fade.
5. **When done**, a toast summarises it ("Claude · removed 47 pauses") with **Undo**. The whole request is one undo step.

**First-time setup:** the first Tab press opens a guided sheet. It detects Claude Code or Claude Desktop, then either shows the one command to run (with a Copy button) or adds the config itself, and finishes with "Connected ✓".

## Playback
Auto quality. When footage is too heavy to play in real time, Shades quietly lowers preview resolution or switches to proxies to stay smooth. A small "Proxy" badge in the viewer shows when that's happening. Export is always full quality.

## Saving & safety
| Moment | Behaviour |
|---|---|
| Saving | Always autosaved, so there's no Save button. **⌘S** makes a named checkpoint |
| Versions | Automatic snapshot every 10 minutes and **before every Claude request**. Browse them in File › Revert To, with thumbnails |
| Crash | On relaunch the project reopens silently, exactly where you were (playhead, zoom, selection), with a small "Recovered" note |

## Export
- **⌘E** opens a sheet: preset (**YouTube 4:3**, **Reel 9:16**, **ProRes master**), file name and location.
- Press Export and keep editing; progress shows in the toolbar ring. Several exports can be queued.
- **When it's done** (or when Claude finishes while you're in another app), Shades plays a soft chime and shows a native Mac notification. Clicking it reveals the file or jumps to the edit.
