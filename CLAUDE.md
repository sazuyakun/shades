# shades

Open-source, AI-native video editor for Mac. **No AI inside the app:** Claude Code drives it over MCP, and taste comes from playbook plugins (`docs/SYSTEM.md`). A monorepo with exactly two kinds of folders: `apps/` for anything that runs on its own (a program, a website, a server) and `packages/` for code that apps use. Nothing else at the top level besides `docs/`.

## Code philosophy (non-negotiable)
1. **Simplest possible.** The least code and the fewest concepts that solve the problem. No speculative abstractions, no "might need it later".
2. **Clean and readable.** Code is read far more than written. Clear names over clever code.
3. **Standardised.** There is exactly **one way** to do each thing in this repo. Before writing code, follow the conventions below; never introduce a second style for something that already has one.
4. **Decisions live in CLAUDE.md files.** Every coding decision is written in the relevant CLAUDE.md so future agents follow it. If something isn't covered, **ask the user, then record the answer here** before writing the code. Never invent a convention silently.

No slop: no dead code, no commented-out code, no unused parameters, no TODOs without an issue, no copy-paste duplication.

**Every problem you find gets fixed or written down.** If you can't fix it now, add it to the Known issues table in `docs/PLAN.md` with the milestone that will fix it. Never leave an issue only in chat or in a code comment. When you fix one, remove its row in the same commit.

## Teaching the user Swift (always)
The user is **new to Swift and Apple development** and knows JavaScript/TypeScript and React. Every session doubles as a lesson:
- **Explain each Swift or Apple concept the first time it shows up** in code you write or change: what it is, why we use it here, and a one-line JS/TS/React comparison when one exists (e.g. "`struct` is a value type, like a frozen object that's copied on assignment", "`@Observable` is like a store that re-renders the views reading it", "`throws` is like a typed, compiler-checked `{ result, error }`").
- Keep explanations short and concrete, tied to the code just written: a few sentences, not a tutorial. Explain in chat, never in code comments (code comments still follow the "why only" rule).
- **Record each new concept in `docs/LEARNING.md`** (one entry per concept: name, plain explanation, JS/TS analogy, where it's used in Shades) and check that file first so concepts aren't re-explained at length. A concept already there gets a one-line reminder at most, unless the user asks.
- If the user asks "why" or "what's that", answer fully before continuing.

## Git workflow (always)
- Keep the repo up to date both locally and on the remote (GitHub: `origin`).
- Work **straight on `main`** in small, complete commits. After **every** change: `git add -A`, commit, and `git push`. Don't batch up changes or leave work uncommitted.
- Before starting work, `git pull --rebase` so the local copy matches the remote.
- **Conventional Commits:** `type(scope): summary` in the imperative, lowercase, no period.
  - Types: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `build`, `ci`, `chore`.
  - Scope is the app or module without its prefix: `mac`, `web`, `mcp`, `core`, `commands`, `document`, `media`, `engine`, `color`, `graphics`, `audio`, `captions`, `export`, `ui`. Omit the scope for repo-wide changes.
  - Examples: `feat(engine): add metal compositor`, `fix(ui): keep playhead visible while scrolling`, `docs: record logging rules`.

## Enforcement
Style is enforced by tools, never by memory:
- **Claude Code hook** (`.claude/settings.json` → `.claude/hooks/format-swift.sh`): after every edit to a Swift file, SwiftFormat formats it and SwiftLint lints it. Remaining violations are sent back to Claude, which must fix them before moving on.
- **Git hooks** (`.githooks/`): `pre-commit` blocks staged Swift files that fail formatting or lint; `commit-msg` blocks subjects that aren't Conventional Commits.
- **CI** (`.github/workflows/ci.yml`, free `macos-26` runner): format check, strict lint, and `swift test` for ShadesKit on every push. A red CI is fixed before anything else.
- **Configs:** `.swiftformat` (Airbnb's config, Swift 6 mode, 100 columns) and `.swiftlint.yml` (Airbnb's rules plus our bans as `error`s). Change these only with the user's approval, and record why here.
- **Edit atomically:** the hook formats after every edit, and SwiftFormat renames unused parameters to `_`. When you add a parameter, change the signature and its uses in the same edit.
- **Fresh clone setup:** `brew install swiftformat swiftlint` and `git config core.hooksPath .githooks`.
- Tool versions in use: SwiftFormat 0.63.1, SwiftLint 0.65.1. Airbnb's `preferStructSwiftTestingSuites` rule is commented out in `.swiftformat` until SwiftFormat ships it.

Tool config files and folders (`.claude/`, `.githooks/`, `.github/`, `.swiftformat`, `.swiftlint.yml`, `.gitignore`) are the only exception to the apps/packages/docs top-level rule.

## Dependencies
- No third-party package is added without the user's explicit approval. Approved packages are listed here with the reason.
- Approved:
  - **WhisperKit** (`argmaxinc/WhisperKit`, **exact 1.1.0**, MIT). Only the captions module may import it. Why: on-device transcription with word timings, handles Hinglish. Pinned to Nebula's version so the downloaded model is shared, not re-downloaded. It brings Apple's `swift-argument-parser` (Apache-2.0) with it, which our code doesn't use directly. Models download into `~/Library/Application Support/Shades/Models`, after checking Nebula's folder.
- **Bundled models and libraries must be MIT, Apache-2.0 or similar. Never GPL, never non-commercial.**

## Swift conventions (all Swift code: apps and packages)
**Base:** the [Airbnb Swift Style Guide](https://swift.airbnb.tech/) on top of Apple's [API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/). Where this file is more specific, this file wins.

**Formatting:** 2-space indent, 100-column lines. SwiftFormat and SwiftLint configs live at the repo root; never disable a rule inline without a `// why:` comment.

**Architecture (SwiftUI):**
- **No ViewModels.** Views read `@Observable` models and services and change things only by sending Commands. A dedicated `@Observable` flow model is allowed only for genuinely multi-step flows (e.g. the export sheet), and is named `XxxFlow`.
- **View inputs are stored `let` properties with the synthesized memberwise init.** No hand-written `init` unless a value must be computed. `@State`, `@Environment` and other wrappers are always `private`.
- **Split big views into separate `View` structs**, never into `some View` computed properties or functions.
- Dependencies come in through the initializer or SwiftUI `@Environment` (declared with `@Entry`). No singletons.

**Concurrency:** ShadesUI and the apps use main-actor default isolation. All other modules are nonisolated by default; heavy work is marked `@concurrent` or lives in an `actor`. Never do video, audio or file work on the main actor. Every target enables Swift 6.2 "approachable concurrency" (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`), so async functions run on their caller's actor unless marked `@concurrent`. When an Apple async API would have to take a non-`Sendable` object to another thread, use its callback form inside `withCheckedContinuation` instead (see `FrameRenderer`). **Blocking calls never run on Swift's cooperative pool** (it has one thread per core, and blocking decodes there deadlocked the tests): run them on a dispatch queue inside `withCheckedContinuation`, passing only `Sendable` values in and out (see `AudioDecoder`, which uses ExtAudioFile).

**Files and declarations:**
- One main type per file; the file is named after the type. Small private helpers used only by that type may share the file.
- Protocol conformances go in extensions in the same file, marked `// MARK: - Type + Protocol`.
- Prefer `struct` and `enum`. Classes are `final` unless designed for subclassing.
- Strictest access level possible; omit `internal` (it's the default). Prefer `private` over `fileprivate`.

**Comments:**
- Code says *what*; comments say only *why* (a non-obvious decision or constraint).
- Every non-private type and function gets a one-line `///` doc comment.
- Never leave commented-out code.

**Errors:**
- Fallible functions use **typed throws**: `func importClip(at url: URL) throws(MediaError) -> Clip`. This is the "result or error" contract: a value or an error, never both, and the compiler forces every caller to handle it with `try`.
- `Result` is only used where an outcome is **stored** (e.g. a finished export job), never as a return type.
- Each module has one error enum named after it (`MediaError`, `EngineError`, `CommandError`…) with specific cases carrying context. Exception: ShadesMCP's is `ToolError`, because the MCP library owns `MCPError`.
- Every error enum conforms to `LocalizedError` in an extension in the same file, and its `errorDescription` is the plain-words message for the user and Claude (what went wrong and what to do). Wrapping cases return the wrapped error's description.
- **Bubble by wrapping:** when an error crosses into another module, wrap it in that module's error with context: `CommandError.importFailed(MediaError)`. Never pass a foreign error through unchanged.
- Never swallow errors: no empty `catch`, and `try?` only where `nil` is a genuinely valid outcome (with a `// why:` comment).
- Errors surface in exactly two places: **ShadesUI** turns them into a toast or alert in plain words with what to do next, and **ShadesMCP** turns them into an MCP tool error so Claude can read it and retry. Lower layers never show UI.

**Logging:**
- `print()` is banned. Each module has exactly one `let logger = Logger(subsystem: "com.sazuyakun.shades", category: "<Module>")` in a file named `Log.swift` (category is the module name without the prefix, e.g. `Media`). This immutable logger constant is the only allowed module-level global.
- **Log once, where it happens.** The function where a failure originates logs it, then throws. Code that bubbles or wraps an error never logs it again.
- **Only two levels:**
  - `error`: a failure, logged once at its origin.
  - `fault`: an impossible state (a bug). Also call `assertionFailure` so it stops debug builds.
  No debug, info, notice or warning logs.
- **One format:** `area.event key=value key=value`
  - `area.event` is lowercase, dot-separated, event in past tense: `import.failed`, `frame.dropped`, `timeline.invariantBroken`.
  - Keys are lowerCamelCase; values carry no spaces.
  - User content (file paths, names, transcript text) is always `privacy: .private`; everything else `.public`.
  - Example: `logger.error("import.failed reason=fileMissing path=\(url.path, privacy: .private)")`

**Banned (enforced by SwiftLint):** force unwraps (`!`), `try!`, `as!`, `print()`, singletons and mutable globals (`static let shared`, `static var`).

**Tests:**
- Swift Testing only. Suites are `struct`s named `XxxTests`, and test names are backticked sentences: `` @Test func `splitting a clip keeps total duration`() ``.
- Use `#expect` for checks and `try #require` for preconditions and unwrapping. No `guard`, `try!` or force unwraps in tests.
- **Every Command and all Core, Document and feature-module logic** gets tests in the same commit. Views aren't unit-tested; rendering is covered by frame snapshot tests.
- A bug fix starts with a failing test that reproduces it.
- Tests import modules normally. `@testable import` is allowed only to check internal logic that has no public surface (e.g. `Composition.Structure`).
- Tests never use real footage. Shared helpers (e.g. `VideoFixture`, which writes solid-color test videos) live in the `ShadesTestSupport` target.
- Run all tests: `swift test --package-path packages/ShadesKit`.

**Naming:**
- The user-facing "sequence" is the `Timeline` type, because `Sequence` is a Swift standard-library protocol.
- Caseless `enum`s are namespaces for static functions (e.g. `MediaLoader`, `FrameRenderer`).

## CLAUDE.md files
- This root file covers the whole repo. **Every app and package has its own `CLAUDE.md`** with what's specific to it:
  - `apps/mac/CLAUDE.md`: the Shades Mac app
  - `apps/web/CLAUDE.md`: the website
  - `packages/ShadesKit/CLAUDE.md`: the Swift modules
- When you add a new app or package, create its `CLAUDE.md` in the same commit.
- When you change how an app or package works (build commands, structure, rules), update its `CLAUDE.md` too.

## Project docs
- `docs/SYSTEM.md`: **how the whole product works**: taste agent vs builder agent, MCP, format, layers and depth slots, analysis, Polish, plugins, storage, export, quality gates
- `docs/PLAN.md`: product scope, milestones, known issues, performance targets
- `docs/ARCHITECTURE.md`: code layout and rules
- `docs/DESIGN.md` / `docs/UX.md`: locked look, flows and keymap
- `docs/LAUNCH.md`: launch blockers (placeholder icon etc.). Flag these when launch gets close.
- `docs/LEARNING.md`: the Swift concepts glossary built up as the user learns

## Building
- Builds use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (global xcode-select points at CommandLineTools).
- The Xcode project is generated by XcodeGen from `apps/mac/project.yml`; never commit the `.xcodeproj`.
- If linking fails with "Undefined symbols" after changing a signature or conformance, or tests crash with signal 11 right after a model struct gained fields, SwiftPM reused stale objects: run `swift package clean --package-path packages/ShadesKit`.
- App: `xcodegen generate --spec apps/mac/project.yml --project apps/mac`, then `xcodebuild -project apps/mac/Shades.xcodeproj -scheme Shades -derivedDataPath apps/mac/.build build`.
