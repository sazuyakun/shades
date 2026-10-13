# packages/ShadesKit: the Swift modules

All real Mac code lives here as a Swift package with one module per system. The app in `apps/mac` just wires them together. Root rules (git workflow etc.) in `/CLAUDE.md` still apply.

## Modules
| Module | Owns |
|---|---|
| ShadesCore | Model types: Project, Sequence, Track, Clip, time, IDs. Foundation only |
| ShadesCommands | Command protocol, registry, undo, JSON schemas |
| ShadesDocument | `.shades` package, autosave, snapshots |
| ShadesMedia | Import, analysis, thumbnails, waveforms, proxies |
| ShadesEngine | AVComposition builder, Metal compositor, playback, shaders |
| ShadesColor | Color management, grade nodes, LUTs, scopes |
| ShadesGraphics | Titles, templates, keyframes |
| ShadesAudio | Mixer, ducking, loudness, beats |
| ShadesCaptions | Transcription, caption styles |
| ShadesExport | Presets, encode queue |
| ShadesBridge | MCP server: commands become Claude tools |
| ShadesUI | SwiftUI views (AppKit/Metal where SwiftUI is too slow) |

## Rules
- **Dependencies point one way:** Core → Commands / Document → feature modules → Bridge and UI → the app. Core imports only Foundation, and nothing imports ShadesUI except the app.
- **Every edit is a command** (`Codable`: name, description, parameters). Registering it exposes it to menus, shortcuts, undo and Claude. Never add an AI-only shortcut, and never let the UI mutate the model directly.
- The model is plain data. The engine reads it and builds what plays; ShadesUI never touches AVFoundation.
- Shaders ship as `.metal` source and compile at runtime (so Claude can write effects).
- Swift 6 strict concurrency: actors for caches and analysis, and keep render paths off the main thread.
- Respect the 8 GB RAM budget: bounded caches, texture pools, no CPU copies of frames.

## Testing
- Swift Testing for logic, with one test target per module.
- Rendered-frame snapshot tests to keep preview and export identical.
