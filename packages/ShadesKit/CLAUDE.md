# packages/ShadesKit: the Swift modules

All real Mac code lives here as a Swift package with one module per system. The app in `apps/mac` just wires them together. Root rules in `/CLAUDE.md` still apply, **including all Swift conventions** (style, errors, logging, tests).

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
| ShadesMCP | MCP server: commands become Claude tools |
| ShadesPlugins | Plugin folders (Settings), and from M5 loading and hot-reloading plugins |
| ShadesUI | SwiftUI views (AppKit/Metal where SwiftUI is too slow) |

Modules are created only when a milestone first needs them. They exist today: ShadesCore, ShadesCommands, ShadesMedia, ShadesEngine, ShadesMCP, ShadesPlugins, ShadesUI (plus `ShadesTestSupport` for tests). The rest of the table arrives with their milestones.

## Rules
- **Dependencies point one way:** Core → Commands / Document → feature modules → MCP → UI → the app. Core imports only Foundation, nothing imports ShadesUI except the app, and ShadesMCP never imports ShadesUI (UI reads `MCPServer.status` to show Claude's connection).
- **Every edit is a command** (`Codable`: name, description, parameters). Registering it exposes it to menus, shortcuts, undo and Claude. Never add an AI-only shortcut, and never let the UI mutate the model directly.
- The model is plain data. The engine reads it and builds what plays; ShadesUI never touches AVFoundation.
- Shaders ship as `.metal` source and compile at runtime (so Claude can write effects).
- Swift 6 strict concurrency. **ShadesUI** uses main-actor default isolation; every other module is nonisolated by default, with actors for caches and analysis and `@concurrent` for heavy work. Render paths never touch the main thread.
- Each module has one error enum (`<Module>Error`, e.g. `MediaError`) and one `Logger` with category `<Module>` (e.g. `Media`).
- Respect the 8 GB RAM budget: bounded caches, texture pools, no CPU copies of frames.

## Testing
- Swift Testing, with one test target per module (`ShadesCoreTests`, …). Rules are in the root CLAUDE.md.
- **Golden frames:** every effect, layer and grade gets a render test that ends with `#expect(try GoldenFrame.matches(png, named: "<kebab-name>", in: golden))`. References live in a `Golden/` folder next to the test file (excluded from the target in `Package.swift`). A missing reference is recorded and fails once; re-record after an approved visual change with `SHADES_RECORD_GOLDEN=1 swift test …`, and commit the PNGs. A mismatch writes `<name>.actual.png` (git-ignored) to compare.
- Rendered-frame snapshot tests to keep preview and export identical.
- **Performance gates:** budgets live in `PerformanceTests` (one suite per module that has hot paths, `.serialized`), measured with `Benchmark.median` and `Benchmark.memoryFootprint()` from `ShadesTestSupport`. Budgets are set for the CI runner; never loosen one to make a regression pass, fix the regression.
