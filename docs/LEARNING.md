# Learning Swift through Shades

A running glossary of Swift and Apple concepts, added the first time each shows up in Shades' code. Each entry covers what it is, the closest JavaScript/TypeScript/React idea, and where Shades uses it.

<!-- Entry format:
## Concept name
**What it is:** one or two plain sentences.
**JS/TS analogy:** the closest idea, or "none" if it's new.
**In Shades:** where and why we use it (file or module).
-->

## Swift basics

## `struct` (value type)
**What it is:** A bundle of data whose copies are independent: assigning or passing a struct copies it, so changing one copy never changes another.
**JS/TS analogy:** Like an object you always spread into a new one (`{...obj}`) before changing, except Swift does it for you automatically and cheaply.
**In Shades:** The whole project model (`Project`, `Timeline`, `Track`, `Clip`, `Media`, `MediaTime` in ShadesCore). It's why "a failed command leaves the project unchanged" is trivial: `Editor` edits a copy and only keeps it if nothing threw.

## `final class` (reference type)
**What it is:** A type whose instances are shared: everyone holding it sees the same object. `final` means nothing can subclass it.
**JS/TS analogy:** A normal JS class instance (shared by reference).
**In Shades:** Things with identity that many parts share: `Editor`, `Player`, `MCPServer`.

## `let` vs `var`
**What it is:** `let` can never be reassigned (and for structs, never mutated); `var` can.
**JS/TS analogy:** `const` vs `let`, but stronger: a `let` struct is fully frozen, not just its binding.
**In Shades:** Model fields that never change after creation (`Clip.id`, `Media.url`) are `let`.

## Optionals (`Type?`, `if let`, `guard let`)
**What it is:** A value that might be missing is typed `Clip?`. You must unwrap it before use: `if let clip { … }` or `guard let clip else { return }`.
**JS/TS analogy:** TypeScript's `Clip | undefined` with `strictNullChecks`, but the compiler won't let you skip the check. `!` force-unwraps (crashes if empty), which is why we ban it.
**In Shades:** Everywhere, e.g. `project.media(withID:)` returns `Media?`.

## `enum` with associated values
**What it is:** A type that is exactly one of several cases, where each case can carry its own data.
**JS/TS analogy:** A TypeScript discriminated union: `{ type: "fileMissing", url } | { type: "noVideo", url }`, with exhaustive `switch` checking built in.
**In Shades:** Every error type, e.g. `MediaError.fileMissing(URL)`.

## Caseless `enum` as a namespace
**What it is:** An `enum` with no cases can't be created; it's just a home for static functions.
**JS/TS analogy:** A module that only exports functions.
**In Shades:** `MediaLoader`, `FrameRenderer`, `SystemStats`, `Theme`.

## `protocol`
**What it is:** A contract listing what a type must provide. Any struct or class can adopt it.
**JS/TS analogy:** A TypeScript `interface`.
**In Shades:** `Command` (in ShadesCommands): anything with `apply(to:)` is an edit.

## `some Protocol` (opaque types)
**What it is:** "Some specific type that conforms to this protocol"; the compiler knows the exact type, you don't need to spell it.
**JS/TS analogy:** Roughly a generic `<T extends Command>(command: T)`.
**In Shades:** `Editor.perform(_ command: some Command)`, and every SwiftUI `var body: some View`.

## `extension`
**What it is:** Adds methods or protocol conformances to an existing type, even one you didn't write.
**JS/TS analogy:** Like adding to a prototype, but type-safe and scoped to your module.
**In Shades:** `MediaTime+CMTime.swift` teaches our time type to convert to Apple's `CMTime`; each error's `LocalizedError` conformance lives in an extension.

## `Codable`
**What it is:** A protocol that lets a type convert to and from JSON automatically.
**JS/TS analogy:** `JSON.stringify`/`JSON.parse`, but type-checked both ways.
**In Shades:** The model is `Codable`, so `get_project` can hand Claude the whole project as JSON (and saving in M1 will reuse it).

## Access control (`public`, `private`)
**What it is:** Who can see a declaration. The default (`internal`) means "anywhere in this module"; `public` crosses modules; `private` stays in its scope.
**JS/TS analogy:** `export` vs not exporting, plus `private` class fields.
**In Shades:** Each module exposes only what others need, e.g. `MetalCompositor` is internal to ShadesEngine.

## Errors

## Typed throws (`throws(MediaError)`) and `try`
**What it is:** A function either returns its value or throws an error of the stated type. Every call must be marked `try`, and the compiler checks that errors are handled or passed on.
**JS/TS analogy:** Your `{ result, error }` pattern, enforced by the compiler instead of convention.
**In Shades:** Every fallible function, e.g. `MediaLoader.load(_:) throws(MediaError) -> Media`.

## `do` / `catch` and wrapping errors
**What it is:** `do { try … } catch { … }` handles an error. With typed throws, `error` in the `catch` already has the right type.
**JS/TS analogy:** `try/catch`, but the caught error is typed.
**In Shades:** `ToolHandler` catches a `MediaError` and wraps it as `ToolError.mediaFailed(error)`, our "bubble by wrapping" rule.

## `LocalizedError`
**What it is:** A protocol that gives an error a human-readable `errorDescription`.
**JS/TS analogy:** A custom `Error` subclass with a good `message`.
**In Shades:** Every error enum; the UI's alert and Claude's tool errors both show this text.

## Concurrency

## `async` / `await`
**What it is:** Functions that can pause while waiting (for a file, the GPU…) without blocking the thread.
**JS/TS analogy:** Exactly JavaScript's `async`/`await` with Promises.
**In Shades:** Loading media (`await MediaLoader.load(url)`), building compositions, seeking.

## Actors and `@MainActor`
**What it is:** An actor guards its data so only one task touches it at a time. `@MainActor` means "always runs on the main (UI) thread".
**JS/TS analogy:** None directly: JavaScript has one thread, so you never think about this. In Swift, many threads run at once, and actors prevent two from changing the same data simultaneously.
**In Shades:** `Editor` and `Player` are `@MainActor` because the UI reads them. ShadesUI is main-actor by default.

## `Sendable`
**What it is:** A promise that a value is safe to share between threads (immutable, or protected by a lock or actor). Swift 6 refuses to compile code that shares non-`Sendable` values across threads.
**JS/TS analogy:** None; it's the price (and the safety) of real multithreading.
**In Shades:** The compiler made us restructure `MetalRenderer` (no texture cache) and `FrameRenderer` (callback API) to stay provably thread-safe.

## `Mutex`
**What it is:** A lock: only one thread at a time can be inside `withLock { … }`.
**JS/TS analogy:** None (single-threaded JS never needs locks).
**In Shades:** `FrameCounter`, written by the compositor's thread and read by the HUD.

## Continuations (`withCheckedContinuation`)
**What it is:** Turns an old callback-style API into something you can `await`.
**JS/TS analogy:** `new Promise(resolve => api(callback => resolve(callback)))`.
**In Shades:** `FrameRenderer` wraps AVFoundation's image-generation callback; the test fixture wraps `finishWriting`.

## SwiftUI

## `View` and `body`
**What it is:** A SwiftUI view is a struct with a `body` describing its UI. SwiftUI re-runs `body` when the data it reads changes.
**JS/TS analogy:** A React function component; `body` is the returned JSX.
**In Shades:** Everything in ShadesUI, e.g. `EditorView`, `TimelinePane`.

## View inputs (stored `let`s)
**What it is:** A view's inputs are plain `let` properties; Swift generates the initializer.
**JS/TS analogy:** React props. Our rule: one way only, always stored `let`s.
**In Shades:** `TrackRow(track:scale:)`, `MediaTile(media:isSelected:)`.

## `@State` and `@Binding`
**What it is:** `@State` is private state a view owns; `@Binding` is a two-way reference to state owned by a parent.
**JS/TS analogy:** `useState`, and passing `[value, setValue]` down to a child.
**In Shades:** `EditorView` owns `@State selection`; `MediaBrowser` gets it as `@Binding`.

## `@Observable` and `@Environment`
**What it is:** `@Observable` makes a class's property changes re-render the views reading them. `@Environment` hands an object down the whole view tree without passing it through every view.
**JS/TS analogy:** A store (Zustand/MobX) plus React Context.
**In Shades:** `Editor` and `Player` are `@Observable` and injected with `.environment(...)`; views read them with `@Environment(Editor.self)`.

## `.task(id:)`
**What it is:** Runs async work when a view appears, and re-runs it when `id` changes (cancelling the old run).
**JS/TS analogy:** `useEffect(() => { … }, [id])` with automatic cleanup.
**In Shades:** `EditorView` reloads the player whenever the project changes, whether the change came from you or from Claude.

## `NSViewRepresentable`
**What it is:** Wraps an older AppKit view so SwiftUI can use it.
**JS/TS analogy:** Wrapping a non-React library widget in a React component with a ref.
**In Shades:** `PlayerSurface` wraps `AVPlayerView`.

## Apple frameworks

## AVFoundation: assets, compositions and the custom compositor
**What it is:** Apple's media framework. An `AVAsset` is a media file; an `AVComposition` stitches pieces of assets into a timeline; a custom `AVVideoCompositing` class draws every frame.
**JS/TS analogy:** None; it's the engine a browser's `<video>` tag is built on.
**In Shades:** `Composition.build` turns our timeline into an `AVComposition`; `MetalCompositor` draws each frame, for both playback and export.

## Metal and shaders
**What it is:** Apple's GPU API. A shader is a small program the GPU runs for every vertex and pixel.
**JS/TS analogy:** WebGL/WebGPU and GLSL/WGSL shaders.
**In Shades:** `Shaders/Passthrough.metal` fits each frame into the output; it's compiled at runtime so Claude can write new effects later.

## IOSurface (zero-copy frames)
**What it is:** A block of memory that both the CPU and GPU can use. A video frame in an IOSurface can become a Metal texture without copying a single pixel.
**JS/TS analogy:** None.
**In Shades:** `MetalRenderer.texture(for:)`. It's one reason playback stays light (about 108 MB while playing).

## OSLog `Logger`
**What it is:** Apple's fast system logger, viewable and filterable in Console.app, with private values redacted.
**JS/TS analogy:** A structured logger (like pino), built into the OS.
**In Shades:** One `logger` per module in `Log.swift`; only `error` and `fault`.

## Swift Package Manager: packages, targets, modules
**What it is:** A package (`Package.swift`) defines targets; each target is a module you `import`. The manifest declares which module may use which.
**JS/TS analogy:** A monorepo workspace with `package.json` files, plus enforced import boundaries.
**In Shades:** `packages/ShadesKit/Package.swift`; the compiler enforces that arrows only go down.

## Swift Testing (`@Test`, `#expect`, `#require`)
**What it is:** Apple's test framework. `#expect` checks and keeps going; `try #require` stops the test if a precondition fails.
**JS/TS analogy:** Jest/Vitest: `test(...)` and `expect(...)`.
**In Shades:** Every `Tests/` folder; test names are plain sentences in backticks.

## `CGAffineTransform` and `preferredTransform`
**What it is:** A 2D transform (rotate, scale, move) stored as six numbers. A phone records portrait video as landscape pixels plus a `preferredTransform` that says "rotate 90° to show it upright".
**JS/TS analogy:** CSS `transform: matrix(a, b, c, d, tx, ty)`, the same six numbers.
**In Shades:** `Composition` reads each clip's `preferredTransform`; `FrameUniforms` turns it into the mapping the shader uses to draw every frame upright.

## `static` properties
**What it is:** A value that belongs to the type itself, not to each instance. `VideoFormat.youTube4x3` is one shared, ready-made format.
**JS/TS analogy:** A `static` field on a class, or an exported constant like `export const youTube4x3 = {...}`.
**In Shades:** The format presets in `VideoFormat` (`.youTube4x3`, `.reel9x16`).

## `@ObservationIgnored`
**What it is:** Inside an `@Observable` class, marks a property that views should *not* react to (internal plumbing that never changes what's on screen).
**JS/TS analogy:** Keeping a value in a `useRef` instead of `useState`, so changing it doesn't re-render.
**In Shades:** `MCPServer` hides its listener and tool handler this way; only `status` drives the toolbar pill.

## `.transition` and `.animation(_:value:)`
**What it is:** `.transition` says how a view enters and leaves when an `if` adds or removes it (slide, fade). `.animation(_:value:)` animates any change on screen whenever `value` changes.
**JS/TS analogy:** Framer Motion's `<AnimatePresence>` with `initial`/`exit`, and `animate` keyed on a value.
**In Shades:** `ClaudeToast` slides up and fades when Claude edits; `TimelineClipView` fades its purple glow in and out.

## Computed properties
**What it is:** A `var` with a body and no storage: it's recalculated from other properties every time it's read, so it can never go stale.
**JS/TS analogy:** A class `get` accessor, or a derived value in React (`const total = items.length`) instead of separate state.
**In Shades:** `ActivityLog.recentlyChangedClipIDs` is derived from `recentEntry`, so the glow and the toast can't disagree.

## `mutating` and `inout`
**What it is:** Structs are values, so a method that changes one must say so with `mutating`, and a function that edits a value you pass in takes it as `inout` (called with `&`). The caller's copy really changes; nobody else's does.
**JS/TS analogy:** Like a reducer that gets `draft` from Immer: you "mutate" freely, but it's your own copy, not shared state.
**In Shades:** `Track.split(at:)` is `mutating`; every command's `apply(to project: inout Project)` edits a copy, and `Editor` only keeps it if nothing threw.

## `any Protocol` and `.Type` (existentials and metatypes)
**What it is:** `any ToolCommand` is "some value of a type that conforms, decided at runtime"; `any ToolCommand.Type` is the type itself, so you can call its `static` members (`name`, `parameters`) and decode it, without having an instance.
**JS/TS analogy:** An array of classes `[TrimClip, SplitClip]` where each class has static fields you read before calling `new`.
**In Shades:** `CommandRegistry.tools` lists the command types; MCP reads their names and schemas and decodes Claude's arguments into the right one.

## Custom `Codable` (`init(from:)` / `encode(to:)`)
**What it is:** When the automatic JSON mapping isn't enough, a type writes its own decoding and encoding. Decoding can try several shapes.
**JS/TS analogy:** A hand-written `parse()` with a zod `union`: accept either a number or an object.
**In Shades:** `MediaTime` reads plain seconds from Claude or exact `{value, timescale}` from project files; `JSONValue` decodes any JSON at all.

## Custom `==` and `hash(into:)`
**What it is:** `Hashable` types can define what "equal" means. Two values that are equal must hash the same, or sets and dictionaries break.
**JS/TS analogy:** Writing your own `isEqual(a, b)` plus a matching `key(a)` for a `Map`, instead of comparing object identity.
**In Shades:** `MediaTime` treats 1/2 s and 300/600 s as the same time.

## `@concurrent`
**What it is:** Marks an `async` function to run on a background thread instead of its caller's actor. With approachable concurrency, plain `async` functions stay on the caller's actor (often the main one), so slow work needs `@concurrent`.
**JS/TS analogy:** Like moving a heavy job into a Web Worker, but with the same `await` syntax.
**In Shades:** Reading and writing `.shades` files (`ProjectFile`) and making proxies (`ProxyMaker`) run off the main thread so the UI never stutters.

## `weak` references and `AnyObject` protocols
**What it is:** A `weak` reference doesn't keep its object alive and becomes `nil` when the object goes away. Only classes can be referenced weakly, so the protocol is marked `AnyObject`.
**JS/TS analogy:** A `WeakRef` in JavaScript.
**In Shades:** The MCP tool handler holds the `Workspace` weakly through the `ProjectHost` protocol, so they don't keep each other alive forever.

## `@NSApplicationDelegateAdaptor`
**What it is:** Lets a SwiftUI app keep a classic AppKit app delegate for the moments SwiftUI has no hook for, like "the app is about to quit".
**JS/TS analogy:** Like adding a `beforeunload` listener in a framework that otherwise hides the window events.
**In Shades:** `AppDelegate` saves the open project before Shades quits.

## `onKeyPress` and `@FocusState`
**What it is:** `onKeyPress` handles raw key presses for the focused view; `@FocusState` tracks and moves keyboard focus.
**JS/TS analogy:** A `keydown` listener on a focusable `div` with `tabIndex`, plus `element.focus()`.
**In Shades:** The editor window handles the whole keymap in one `onKeyPress`, looking each press up in `EditorAction`.

## `ScrollPosition` and `onScrollGeometryChange`
**What it is:** `ScrollPosition` lets code scroll a `ScrollView`; `onScrollGeometryChange` reports how far it has scrolled.
**JS/TS analogy:** `element.scrollTo()` and a `scroll` event listener.
**In Shades:** The timeline follows the playhead while playing and keeps track headers in view while you scroll sideways.

## `Mirror` (reflection)
**What it is:** Looks inside a value at runtime: its type's fields or an enum case's name.
**JS/TS analogy:** `Object.keys(value)`, roughly.
**In Shades:** `rejected(_:)` logs just an error's case name (never its payload), keeping user content out of logs.

## `Atomic` (Synchronization)
**What it is:** A value many threads can read and write safely without a lock, for simple flags and counters.
**JS/TS analogy:** `Atomics.store` / `Atomics.load` on a `SharedArrayBuffer`.
**In Shades:** `AudioDecoder` sets an `Atomic<Bool>` when a decode is cancelled, and the decode loop on another thread checks it.

## Calling C APIs from Swift (`ExtAudioFile`)
**What it is:** Swift calls Apple's C libraries directly: you pass pointers with `&value` and `withUnsafeMutableBytes`, and check returned status codes.
**JS/TS analogy:** Calling a native addon from Node, or `fetch`-level APIs that hand you raw buffers instead of objects.
**In Shades:** `AudioDecoder` reads any file's sound with AudioToolbox's ExtAudioFile, which converts to 16 kHz mono as it reads.

## The cooperative thread pool (and why blocking calls stay off it)
**What it is:** Swift's `async` code shares a small pool, one thread per CPU core. A call that blocks (waits without `await`) holds a thread hostage; enough of them at once and nothing else can run.
**JS/TS analogy:** Like doing a synchronous `while` loop in Node's event loop: everything else freezes.
**In Shades:** Blocking audio decoding runs on a separate dispatch queue (`AudioDecoder`); doing it on the pool deadlocked the tests.

## `Layout` (custom SwiftUI layouts)
**What it is:** A type that measures and places child views itself, when stacks and grids don't fit.
**JS/TS analogy:** Writing your own CSS layout algorithm, like `flex-wrap`, in code.
**In Shades:** `WordFlow` wraps transcript words like a paragraph.

## Region-based isolation (`sending`)
**What it is:** Swift tracks which values could be reached from more than one thread. A value that isn't marked `Sendable` can still move to another thread if nothing else holds onto it; otherwise the compiler stops you.
**JS/TS analogy:** Transferring an `ArrayBuffer` to a Web Worker: after the transfer, the sender can't touch it.
**In Shades:** Why caches hold `IOSurface`s (thread-safe) rather than pixel buffers, and why the decoder passes only a URL in and samples out.

## Accelerate and `vDSP` (whole-array maths)
**What it is:** Apple's library of fast maths over whole arrays at once, using the CPU's vector units: `vDSP.add(a, b)` adds every pair in one call instead of a Swift loop.
**JS/TS analogy:** Like using a typed-array kernel (or WebAssembly SIMD) instead of `array.map((x, i) => x + b[i])`.
**In Shades:** `MatteMaker` blends each cut-out with the last frame's and converts it to bytes with `vDSP`.

## Bi-planar YUV pixel buffers
**What it is:** A video frame stored as two planes: brightness (Y) at full size and colour (CbCr) at quarter size. It's what video encoders want natively, so no conversion is needed.
**JS/TS analogy:** Like storing an image as a grayscale `Uint8Array` plus a smaller colour array, rather than RGBA.
**In Shades:** A cut-out is gray, so `MatteMaker` copies its mask straight into the brightness plane and fills colour with neutral 128.

## Parameterized tests (`@Test(arguments:)`)
**What it is:** One test function run once per value in a list; each run passes or fails on its own.
**JS/TS analogy:** Jest's `test.each([...])`.
**In Shades:** `AnimationTests` checks every `Easing` case starts at 0 and arrives at 1.

## `switch` with `where` clauses
**What it is:** A `case` can add a condition: `case .opacity where value > 1:` only matches when both hold, and `default` catches the rest.
**JS/TS analogy:** Like a `switch (true)` with `case prop === "opacity" && value > 1:`, but the compiler still checks every case is covered.
**In Shades:** `SetKeyframes.validate` refuses out-of-range opacity and scale.

## Actors with a custom executor (`unownedExecutor`)
**What it is:** An actor normally runs on Swift's shared thread pool. Giving it its own `DispatchSerialQueue` as executor makes all its code run on that queue instead, so it can call slow, blocking APIs without starving the pool.
**JS/TS analogy:** Like giving one object its own dedicated Web Worker that processes its messages one at a time.
**In Shades:** `MotionTracker` keeps Vision's frame-to-frame tracking state and runs Vision on its own queue.

## Raw strings (`#"…"#`)
**What it is:** A string where `\` and `"` are literal; more `#`s on each side let the text itself contain `"#`.
**JS/TS analogy:** `String.raw` template literals.
**In Shades:** JSON snippets in tests, like a style with `"#FFD84A"` inside `##"…"##`.

## `simd` matrices (`simd_float4x4`)
**What it is:** Apple's small fixed-size vector and matrix types, matching the GPU's. A 4×4 matrix can scale, rotate, move and add perspective in one multiply; multiplying matrices chains those steps.
**JS/TS analogy:** Like CSS `transform: perspective() rotateY() translate()`, or a `DOMMatrix`, as one value.
**In Shades:** `FrameUniforms` builds each layer's model × camera × perspective matrix for the shader.

## C callbacks with `Unmanaged` (FSEvents)
**What it is:** Older C APIs call back through a plain function pointer that can't capture variables. You pass your object in as a raw pointer (`Unmanaged.passUnretained(self).toOpaque()`) and turn it back into the object inside the callback.
**JS/TS analogy:** Like passing `this` explicitly into a callback that can't be a closure, then casting it back.
**In Shades:** `FolderWatcher` listens for file changes in plugin folders so plugins reload by themselves.

## `withObservationTracking`
**What it is:** Runs a closure, notes which `@Observable` properties it read, and calls you once when any of them changes. It fires once, so you re-arm it each time.
**JS/TS analogy:** Like a one-shot MobX `reaction` or a Vue `watch` you set up again after it fires.
**In Shades:** `PluginLibrary` reloads when the list of plugin folders changes in Settings.

## Metal blending and the backdrop pass
**What it is:** The GPU can mix a new pixel over the old one by fixed rules (like "over" by alpha), but modes such as overlay need to read the pixel underneath. Shades copies the frame drawn so far into a second texture (a blit) and lets the shader read it.
**JS/TS analogy:** Like canvas `globalCompositeOperation`, but where some modes make you snapshot the canvas first with `drawImage` into another canvas.
**In Shades:** `MetalRenderer` does this for blend modes and adjustment clips.
