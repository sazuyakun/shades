# Shades: user experience

How Shades behaves. The look is in [DESIGN.md](DESIGN.md).

**Principle:** one hand on the mouse, the other on the keyboard for edits. Claude works over MCP from Claude Code; inside the app you only ever see what it did.

## Getting in
| Moment | Behaviour |
|---|---|
| Opening Shades | A small native welcome window: **New Project**, recent projects with thumbnails, and "drop footage here" |
| New project | Name it and pick a size: **2880×2160** (default) or **1440×1080**, both 4:3, plus a frame rate (24, 30 or 60; default **24**) |
| Format | Every timeline is a 4:3 picture. Clips of any shape are fitted inside it upright (16:9 iPhone footage is auto-reframed to 4:3). The 9:16 and 16:9 versions are only canvases added at export |
| Importing | Media stays where it is on disk; Shades links to it and copies nothing. "Collect media" copies into the project later if wanted |
| Background work | Thumbnails, waveforms, transcripts and proxies run quietly. A progress ring sits in the toolbar; click it for details. Nothing blocks editing |
| Shorts | Marked as named ranges on the master timeline ("Short 1 · Chul ka keeda") and exported in a batch on the 9:16 canvas |

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
| A · B · T · P | Select tool · Blade tool · Trim tool · Draw tool (drag in the viewer to draw lines over the picture) |
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
| ⌘K | Command palette: every action by name |
| ⌘L | Show or hide the History pane |
| Esc | Close a sheet or palette |

All shortcuts are remappable.

## Working with Claude
There's no AI inside Shades: Claude Code edits over MCP ([SYSTEM.md](SYSTEM.md)), and the app shows what it did.
1. **Edits appear live** on the timeline while Claude works. Changed clips glow soft purple, then fade.
2. **A toast** summarises each request ("Claude · removed 47 pauses") with **Undo**. The whole request is one undo step.
3. **The History pane (⌘L)** swaps the inspector for a read-only list of every change Claude made: the request, its result ("+2 clips", "−47 cuts"), and **Undo** / **Show** per request. It's an edit log, not a chat.

**Connection status:** a pill in the toolbar shows **● Claude ready** (green) or **● Claude offline** (red). Clicking it explains why and what to do, e.g. "port 4747 is already in use, usually by another copy of Shades. Quit it, then reopen Shades." In the v2 restyle it becomes the dot on the ✦ Claude capsule.

**First-time setup:** connect once from a terminal with `claude mcp add --transport http shades http://127.0.0.1:4747/mcp`. Settings › Claude shows the command with a Copy button.

## Playback
Auto quality. When footage is too heavy to play in real time, Shades quietly lowers preview resolution or switches to proxies to stay smooth. A small "Proxy" badge in the viewer shows when that's happening. Export is always full quality.

## Saving & safety
| Moment | Behaviour |
|---|---|
| Saving | Always autosaved, so there's no Save button. **⌘S** makes a named checkpoint |
| Versions | Automatic snapshot every 10 minutes and **before every Claude request**. Browse them in File › Revert To, with thumbnails |
| Crash | On relaunch the project reopens silently, exactly where you were (playhead, zoom, selection), with a small "Recovered" note |

## Export
- **⌘E** opens a sheet: **YouTube** (4:3 picture on a 16:9 black canvas), **Reels/Shorts** (4:3 picture on a 9:16 black canvas, one file per short range), **Frame**, **GIF** or **SRT**, plus file name and location.
- Press Export and keep editing; progress shows in the toolbar ring. Several exports can be queued.
- **When it's done** (or when Claude finishes while you're in another app), Shades plays a soft chime and shows a native Mac notification. Clicking it reveals the file or jumps to the edit.
