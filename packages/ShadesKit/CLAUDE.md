# packages/ShadesKit: the Swift modules

All real Mac code lives here as a Swift package with one module per system. The app in `apps/mac` just wires them together. Root rules in `/CLAUDE.md` still apply, **including all Swift conventions** (style, errors, logging, tests).

## Modules
| Module | Owns |
|---|---|
| ShadesCore | Model types: Project, Sequence, Track, Clip, time, IDs. Foundation only |
| ShadesCommands | Command protocol, registry, undo, JSON schemas |
| ShadesDocument | `.shades` package (project, session, snapshots, thumbnail), the `~/Shades` library. Autosave timing lives in ShadesUI's `Workspace` |
| ShadesMedia | Import, audio decoding, thumbnails and filmstrips, proxies, the background `JobQueue` |
| ShadesEngine | AVComposition builder, Metal compositor, playback, shaders |
| ShadesColor | Color management, grade nodes, LUTs, scopes |
| ShadesGraphics | Titles, templates, keyframes |
| ShadesAudio | Speech activity (ported), beat detection; from M7 mixer, ducking, loudness |
| ShadesCaptions | WhisperKit transcription (models, audio decoding), caption lines. The only module that imports WhisperKit |
| ShadesExport | Presets, encode queue |
| ShadesMCP | MCP server: commands become Claude tools |
| ShadesMatting | Cut-outs (mattes): Apple Vision finds the subject, written as a small gray video played like any track; the subject's path over time for reframing |
| ShadesPolish | Polish for talking-head footage: the rule-based planner (silences, fillers, retakes, beat snaps, punch-ins) and `ApplyPolish`. Pure logic on Core and Commands |
| ShadesPlugins | Plugin folders (Settings), loading plugins (`PluginLoader`), and `PluginLibrary`: kept up to date with FSEvents, fonts registered for the app. Data only (on Core); templates are applied by `ApplyTemplate` in Commands |
| ShadesUI | SwiftUI views (AppKit/Metal where SwiftUI is too slow) |

Modules are created only when a milestone first needs them. They exist today: ShadesCore, ShadesAudio, ShadesCaptions, ShadesCommands, ShadesDocument, ShadesMedia, ShadesEngine, ShadesMatting, ShadesMCP, ShadesPlugins, ShadesPolish, ShadesUI (plus `ShadesTestSupport` for tests). The rest of the table arrives with their milestones.

## Rules
- **Dependencies point one way:** Core → Commands / Document → feature modules → MCP → UI → the app. Core imports only Foundation, nothing imports ShadesUI except the app, and ShadesMCP never imports ShadesUI (UI reads `MCPServer.status` to show Claude's connection).
- **Every edit is a command** (`Codable`: name, description, parameters). Registering it exposes it to menus, shortcuts, undo and Claude. Never add an AI-only shortcut, and never let the UI mutate the model directly.
- **Every user action is an `EditorAction` case** (title, `Shortcut`, `perform(in:)`). The editor window's one `onKeyPress` handler and the ⌘K palette both read that list, so never attach `.keyboardShortcut` to a button for an editor action. Only standard menu items (undo/redo, checkpoint, new/open, Settings) live in menus (`FileMenu`).
- **One open project.** `Workspace` (ShadesUI) owns the editor, player and MCP server and opens one project at a time; Claude's project tools reach it through the `ProjectHost` protocol, since ShadesMCP never imports ShadesUI.
- **Saved projects must keep opening.** When a saved model field is renamed or reshaped, its `Codable` reads the old form too, and `ProjectFormatTests` gets a test with the old JSON. New fields decode with a default (`decodeIfPresent`).
- The model is plain data. The engine reads it and builds what plays; ShadesUI never touches AVFoundation.
- Shaders ship as `.metal` source and compile at runtime (so Claude can write effects).
- Swift 6 strict concurrency. **ShadesUI** uses main-actor default isolation; every other module is nonisolated by default, with actors for caches and analysis and `@concurrent` for heavy work. Render paths never touch the main thread.
- Each module has one error enum (`<Module>Error`, e.g. `MediaError`) and one `Logger` with category `<Module>` (e.g. `Media`).
- Respect the 8 GB RAM budget: bounded caches, texture pools, no CPU copies of frames.

## Testing
- Swift Testing, with one test target per module (`ShadesCoreTests`, …). Rules are in the root CLAUDE.md.
- **Golden frames:** every effect, layer and grade gets a render test that ends with `#expect(try GoldenFrame.matches(png, named: "<kebab-name>", in: golden))`. References live in a `Golden/` folder next to the test file (excluded from the target in `Package.swift`). A missing reference is recorded and fails once; re-record after an approved visual change with `SHADES_RECORD_GOLDEN=1 swift test …`, and commit the PNGs. A mismatch writes `<name>.actual.png` (git-ignored) to compare.
- Rendered-frame snapshot tests to keep preview and export identical.
- Tests that need a speech model run only with `SHADES_WHISPER=1` (it downloads the Small model once, about 485 MB). Spoken test audio comes from `SpeechFixture` (the Mac's `say`), never real recordings.
- **Performance gates:** budgets live in `PerformanceTests` (one suite per module that has hot paths, `.serialized`), measured with `Benchmark.median` and `Benchmark.memoryFootprint()` from `ShadesTestSupport`. Budgets are set for the CI runner; never loosen one to make a regression pass, fix the regression. Suites are enabled only with `SHADES_PERFORMANCE=1` and run alone: `SHADES_PERFORMANCE=1 swift test --package-path packages/ShadesKit --filter PerformanceTests --no-parallel` (CI does this as its own step).
