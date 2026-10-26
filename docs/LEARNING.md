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

## SwiftUI `Canvas`
**What it is:** A view you draw into with code (paths, fills, images) in one pass, instead of building it from many child views. Much cheaper when there are hundreds of shapes.
**JS/TS analogy:** Like an HTML `<canvas>` with a 2D context inside a React component, redrawn when its props change.
**In Shades:** `ClipWaveform` draws an audio clip's waveform as one path of thin bars.

## CoreML (`MLModel`, `MLMultiArray`)
**What it is:** Apple's framework for running trained neural networks on the Mac's CPU, GPU or Neural Engine. A model is compiled to an `.mlmodelc` folder; you feed it named inputs (`MLMultiArray` is an n-dimensional array of numbers) and read named outputs.
**JS/TS analogy:** Like loading an ONNX model in `onnxruntime-web` and calling `session.run({ input: tensor })`, but the runtime is built into macOS.
**In Shades:** `StemSeparator` runs HTDemucs to split voice from music.

## `Float16` and strides
**What it is:** `Float16` is a half-size floating-point number (2 bytes): the GPU computes in it for speed. Strides say how many elements to skip to move one step along each dimension of an array; GPUs often pad rows, so the next row doesn't start right after the last element of this one.
**JS/TS analogy:** Like reading a `Uint16Array` view over an `ArrayBuffer` where each image row has extra padding bytes, so you index with `row * stride + column`, not `row * width + column`.
**In Shades:** `StemSeparator.values(of:)` reads the model's padded half-float output directly, 100× faster than the generic conversion.

## `AVAssetExportSession`
**What it is:** AVFoundation's one-call exporter: give it a composition (with our video compositor and audio mix) and a preset, and it renders, encodes on the Mac's hardware encoder and writes the file, reporting progress.
**JS/TS analogy:** Like calling `ffmpeg` with a filter graph and a preset, but as a built-in API with an async `export(to:)` and a stream of progress states.
**In Shades:** `MovieExporter` writes YouTube, Reels and plain exports.

## Core Image (`CIImage`, `CIContext`)
**What it is:** Apple's GPU image pipeline: a `CIImage` is a recipe (scale this, place it over that), and a `CIContext` renders the recipe into real pixels.
**JS/TS analogy:** Like building a chain of canvas `drawImage` and `transform` calls lazily, then running it all at once on the GPU.
**In Shades:** `RenderContext.place(_:onCanvas:)` scales the 4:3 picture onto the black export canvas.

## Closures as parameters (`(MediaTime) -> LayerPose`)
**What it is:** A function type written as `(Input) -> Output`. A function can take another function (a closure) as a parameter and call it as often as it needs. When the closure is the last argument, it can go after the parentheses (a "trailing closure").
**JS/TS analogy:** Passing a callback, e.g. `poses(time, (moment) => place(moment))`. The type `(MediaTime) -> LayerPose` is TypeScript's `(moment: MediaTime) => LayerPose`.
**In Shades:** `Shutter.poses(around:…place:)` asks the compositor's `place` closure where a layer is at each moment inside the shutter.

## Accumulation buffers (additive blending into half floats)
**What it is:** A texture you draw into many times with "add" blending (`one + one`), so every draw sums onto what's there. Each draw is weighted (here by 1/n), so the result is an average. It uses half floats (`rgba16Float`), because 8-bit colour would lose the faint 1/32 shares to rounding.
**JS/TS analogy:** Like adding many `ImageData` arrays into one `Float32Array` and dividing at the end, but done by the GPU.
**In Shades:** `MetalRenderer.accumulate` sums a moving layer's moments into its trail for motion blur. `trailFragment` then draws the average like any layer.

## `Task` and cooperative cancellation
**What it is:** `Task { … }` starts async work and hands back a handle. `task.cancel()` doesn't stop it by force; it only sets a flag (`Task.isCancelled`) that the work checks, and calls like `Task.sleep` throw when it's set. `await task.value` waits for its result.
**JS/TS analogy:** Like an `AbortController`: `abort()` just flips `signal.aborted`, and the work has to look at it. `await task.value` is `await promise`.
**In Shades:** `JobQueue` runs each job in its own `Task`, so cancelling one job flags only that job; the loop that runs the rest lives in a different task and carries on.

## Vision optical flow (`VNGenerateOpticalFlowRequest`)
**What it is:** An Apple Vision request that compares two frames and says, for every pixel, how far it moved (x and y, in pixels). Vision requests run through a handler: you build the request, `perform` it on an image, then read `results`.
**JS/TS analogy:** Like calling a computer-vision library, e.g. OpenCV.js `calcOpticalFlowFarneback(prev, next)`, but built into macOS and run on the GPU or Neural Engine.
**In Shades:** `FlowEstimator` measures motion between neighbouring frames for footage motion blur. It pins revision 1, which measured test moves exactly.

## Raw pointers (`assumingMemoryBound(to:)`)
**What it is:** `CVPixelBufferGetBaseAddress` hands back an untyped `UnsafeMutableRawPointer` to the frame's bytes. `assumingMemoryBound(to: Float.self)` reads those bytes as floats, and `pointer + n` moves along by bytes. There's no bounds checking, so the code must stay inside the buffer's rows.
**JS/TS analogy:** Like taking an `ArrayBuffer` and wrapping a slice of it in a `Float32Array` view at a byte offset.
**In Shades:** `FlowEstimator.encoded` reads Vision's two-floats-a-pixel flow buffer row by row.

## Core Text lines, runs and glyphs (`CTLine`, `CTRun`)
**What it is:** Core Text turns a styled string into a `CTLine` (one line of laid-out text), which is split into `CTRun`s (stretches with the same font and colour), each holding glyphs (the font's drawn shapes) with their positions and advances (widths). `CTRunDraw` draws a run, or just some of its glyphs.
**JS/TS analogy:** Like measuring text with canvas `measureText` and then `fillText` letter by letter, except Core Text hands you every letter's position for free.
**In Shades:** `TextRenderer` draws text piece by piece: whole words in wrapped lines, or each glyph stood on a path and turned to follow it (arcs, any path), and crops a single word for per-word layers.

## Transparency layers (`beginTransparencyLayer`)
**What it is:** A Core Graphics group: everything drawn between `beginTransparencyLayer` and `endTransparencyLayer` is composited as one picture, so a shadow (or alpha) applies to the group once instead of to each piece.
**JS/TS analogy:** Like wrapping elements in a `<div>` with `filter: drop-shadow(...)` instead of giving each child its own `box-shadow`.
**In Shades:** `TextRenderer` draws letters one at a time; the layer gives the text a single shadow, so neighbouring letters' shadows don't double up where they overlap.

## Default argument values (evaluated at each call)
**What it is:** A parameter can have a default, `func make(at url: URL = newTempFile())`. Swift works out the default every time the function is called without that argument, so each call can get a fresh value; callers who pass one get theirs instead.
**JS/TS analogy:** The same as JavaScript's `function make(url = newTempFile())`, which also runs the default expression on each call (unlike Python's once-only defaults).
**In Shades:** `LUTFixture.make` writes to a new temporary `.cube` file by default, or over an existing one when a test passes `at:` to check that an edited LUT is read again.

## Tuples (`(time: Double, value: Double)`)
**What it is:** A quick, unnamed bundle of a few values, optionally with labels, written in parentheses. It's a value type like a struct but needs no declaration; you read parts by label (`move.time`) or position (`move.0`).
**JS/TS analogy:** A small object literal `{ time, value }` (or a typed tuple `[number, number]`), used for a short hop between functions.
**In Shades:** `PanToSubject.camera(following:)` passes the camera's path around as `[(time: Double, value: Double)]` while it steadies, limits and eases it. Anything that outlives a function gets a real `struct` instead.

## Key paths (`\SubjectPoint.x`, `value[keyPath:]`)
**What it is:** A reference to a property itself, not its value: `\SubjectPoint.x` means "the x of some SubjectPoint". `point[keyPath: path]` reads it from a particular value.
**JS/TS analogy:** Passing a property name and reading `point[key]`, but checked by the compiler (no typos, right type).
**In Shades:** `PanToSubject` runs the same camera maths for both axes by pairing each animated property with the key path to read from the subject's path: `(.x, \SubjectPoint.x)` and `(.y, \.y)`.

## `Menu` with a `primaryAction`
**What it is:** A button with a small arrow: clicking the button does the main thing, and the arrow opens a menu of alternatives.
**JS/TS analogy:** A "split button" component (one click handler plus a dropdown).
**In Shades:** The Video inspector's **Reframe** pans with the subject when clicked; its menu offers **Locked on the Subject**.

## Key paths (`WritableKeyPath<Crop, Double>`, `\.left`)
**What it is:** `\.left` is a reference to a property, not its value. `crop[keyPath: path]` reads or writes whichever property the path names, and `WritableKeyPath<Root, Value>` is its type: a settable `Value` inside a `Root`.
**JS/TS analogy:** Like passing the property name `"left"` and doing `crop[name]`, but checked by the compiler (TypeScript's `keyof Crop` plus the value's type).
**In Shades:** `CropControls` draws one slider per edge from a list of key paths instead of four copies of the same slider.

## Shader derivatives (`fwidth`)
**What it is:** On the GPU, pixels are shaded in little 2×2 groups, so a fragment shader can ask how fast a value changes from one pixel to the next. `fwidth(p)` is that change: the size of one pixel in `p`'s units.
**JS/TS analogy:** None in plain JS; it's like knowing the zoom level of a canvas so a 1-pixel line stays 1 pixel wide.
**In Shades:** `cropCoverage` in Layers.metal softens a crop's edge over exactly one screen pixel, so cut edges stay smooth however the layer is scaled or turned.

## `ClosedRange` (`0.1 ... 10`)
**What it is:** `a ... b` makes a range that includes both ends; `range.contains(x)`, `lowerBound` and `upperBound` read it. Stored as a `static let`, it's one constant every check shares.
**JS/TS analogy:** Like a `{ min, max }` object with an `includes(x)` helper, built into the language.
**In Shades:** `Clip.speeds` (0.1–10) validates `set_clip` and speed keyframes; `Clip.audibleSpeeds` decides when stretched sound is muted.

## Memberwise initializers (and an extra `init` in an extension)
**What it is:** A struct with no `init` of its own gets one for free, taking every stored property in order. Writing another `init` inside the struct removes it, but writing it in an `extension` keeps both.
**JS/TS analogy:** Like a class whose constructor is generated from its fields, plus an extra static factory that doesn't replace it.
**In Shades:** `MediaPiece` (ShadesEngine) is built with the free `init(source:at:duration:)`, and a private extension adds `init(from:to:over:_:)` for model times.

## Numeric integration with an exact inverse
**What it is:** Not Swift syntax, but the idea behind speed ramps: the timeline time to play a stretch of source is the sum of `1 / speed` along it. Sampling the speed curve and joining the samples with straight lines makes that sum a simple formula with an exact inverse (a square root), so turning timeline time into source time never needs guessing.
**JS/TS analogy:** Like an easing function's "time → progress" with a matching "progress → time", computed from a lookup table instead of a loop that searches.
**In Shades:** `SpeedCurve` (ShadesCore) behind `Clip.sourceTime(at:)` and `timelineTime(atSource:)`.

## Property observers (`didSet`)
**What it is:** Code attached to a stored property that runs right after it's assigned (`didSet`, with the old value as `oldValue`). It works on `@Observable` properties too.
**JS/TS analogy:** Like a setter (`set previewQuality(v) { this._q = v; this.resize() }`), but you keep a plain stored property and only add the "after" hook.
**In Shades:** `Player.previewQuality` redraws playback at the new size as soon as the viewer's menu or ⌥H changes it.

## `@Bindable`
**What it is:** Turns an `@Observable` object you already have (often from `@Environment`) into something you can make bindings from, with `$object.property`, so a control like a `Picker` can read and write it.
**JS/TS analogy:** Like passing `value={store.quality}` and `onChange={(q) => store.quality = q}` to a controlled input, packed into one `$store.quality`.
**In Shades:** `PreviewQualityMenu` binds its picker to `$player.previewQuality`.

## `ContinuousClock` and `Duration`
**What it is:** `ContinuousClock.now` is a moment that keeps counting while the Mac sleeps; subtracting two moments gives a `Duration`, which you can compare, add and divide (`.milliseconds(5)`, `.seconds(0.04)`).
**JS/TS analogy:** `performance.now()` differences, but typed: a `Duration` can't be mixed up with a plain number of seconds or milliseconds.
**In Shades:** `FrameCounter` times every frame the compositor draws, and how long a scrub or an edit waited for its frame, for the performance HUD.

## Audio taps (`MTAudioProcessingTap`)
**What it is:** A hook AVFoundation calls with each buffer of one track's sound while it plays, reads or exports, so your code can change the samples in place. It's a C API: you hand it callbacks (made, prepared, process, finished) and an object passed as a raw pointer (`Unmanaged.passRetained`), released in the "finished" callback. The callbacks run on AVFoundation's audio thread, so anything they read is fixed when the tap is made, and anything they write goes through a `Mutex`.
**JS/TS analogy:** Like an `AudioWorkletProcessor`'s `process(inputs, outputs)` in the Web Audio API: a function called with each block of samples on the audio thread.
**In Shades:** `TrackTap` (ShadesEngine) applies the master limiter's gain sample by sample to every track's sound, the same in playback, export and loudness measuring. Volume ramps can't do it: AVFoundation smooths them over about 25 ms, too slow to catch a peak.

## Named tuples as return values
**What it is:** A function can hand back several values at once as a tuple, with a name on each part: `-> (media: Media, command: AddMedia?)`. The caller reads them as `result.media` and `result.command`. It suits a small private helper; anything shared or long-lived gets a `struct`.
**JS/TS analogy:** Like returning `{ media, command }` from a function and reading its fields, without declaring an interface first.
**In Shades:** `Workspace.importing(_:)` returns the media for a file plus, when it isn't in the project yet, the `AddMedia` command that imports it; templates and overlays both use it.

## Triangle strips and `[[vertex_id]]` (Metal)
**What it is:** A GPU draws shapes from triangles. In a triangle strip every new vertex makes a triangle with the two before it, so `2 × (n + 1)` vertices cover a row of `n` quads. A vertex shader can make its corners up from `[[vertex_id]]` (0, 1, 2, …) instead of reading a vertex buffer.
**JS/TS analogy:** Like WebGL's `gl.TRIANGLE_STRIP` with positions computed from `gl_VertexID` in the shader.
**In Shades:** `layerVertex` cuts each layer into a strip of columns and moves each corner onto a cylinder, which is how `bend` curves a flat picture in 3D.

## Key paths (`\Type.field`, `WritableKeyPath`)
**What it is:** `\Qualifier.hue` is a value that *points at* a field. `thing[keyPath: path]` reads it and, for a `WritableKeyPath`, writes it. They can reach into arrays too: `\Qualifier.brightness[0]`. Swift checks the type, so a path to a `Double` can only ever read or write a `Double`.
**JS/TS analogy:** Like passing the string `"hue"` and doing `obj[key]`, but typed: TypeScript's `keyof T` plus the value type, checked at compile time.
**In Shades:** The colour inspector's slider enums (`GradeControl`, `QualifierField`, `WindowField`, `CurveChannel`) each hand back a key path, so one `ForEach` draws every slider and writes the right field.

## `Menu`, inline `Picker` and `.contextMenu`
**What it is:** `Menu` is a button that opens a list of actions. Putting a `Picker` inside it with `.pickerStyle(.inline)` turns the list into choices with a checkmark on the current one. `.contextMenu { … }` attaches a right-click menu to any view.
**JS/TS analogy:** A dropdown component; `.contextMenu` is like handling `onContextMenu` and showing your own menu, without writing the menu yourself.
**In Shades:** `KeyframeSlider`'s easing menu (a `Picker` inside a `Menu`), the timeline bar's Motion and Sounds menus, and the ruler's right-click "Remove Marker" on each marker flag.

## `DragGesture` with a start location
**What it is:** A drag reports `startLocation` (where the press began) and `location` (where the pointer is now) on every change, then once more when it ends. From the two you can grab what was under the press, or span a box between them.
**JS/TS analogy:** `pointerdown` remembering its coordinates, then `pointermove` and `pointerup`, rolled into one value.
**In Shades:** `CurvesEditor` grabs (or adds) the curve point under the press and moves it; `TrackingCanvas` draws the box to track from the press to the pointer.

## Generic functions (`func eased<Value>(…) -> Value?`)
**What it is:** A function with a type placeholder in angle brackets. Each call fills `Value` in from what you pass (here, from what the `hold` and `blend` closures return), and the compiler checks it all lines up.
**JS/TS analogy:** TypeScript generics, `function eased<V>(…, hold: (e: E) => V): V | undefined`.
**In Shades:** `Array.eased(at:time:hold:blend:)` finds where a moment falls among keyframes once, for both clip keyframes (a `Double`) and mask and window keyframes (a whole `ShapeKeyframe`).

## Signed distance fields (masks in the shader)
**What it is:** Instead of drawing a shape's pixels, each pixel works out how far it is from the shape's edge: negative inside, positive outside. A soft edge is then just "fade over this distance", growing the shape is "subtract a distance", and inverting is "1 − coverage".
**JS/TS analogy:** None built in; it's like testing `isPointInPath` for every pixel, but getting a distance back instead of a yes/no.
**In Shades:** `maskCoverage` in Layers.metal measures each mask (box, ellipse or polygon) this way, which gives feather, expansion, invert, opacity and add/subtract in a few lines.

## `MTLBuffer` and `[[flat]]` (more data for a shader)
**What it is:** `setFragmentBytes` copies a small struct (up to 4 KB) to the GPU for one draw; an `MTLBuffer` is GPU memory of any size you fill yourself and bind by index. `[[flat]]` on a vertex output means "don't blend it across the triangle", for values that are the same everywhere.
**JS/TS analogy:** Like a WebGL uniform versus a uniform buffer or texture holding a whole array.
**In Shades:** `MetalRenderer` puts a layer's masks and their path points in buffers 1 and 2; the picture's aspect ratio reaches the fragment shader as a `[[flat]]` value.

## Named coordinate spaces and `DragGesture`
**What it is:** `.coordinateSpace(.named("masks"))` names a view's space; a `DragGesture(coordinateSpace: .named("masks"))` inside it then reports the finger's location in that space, wherever the dragged view sits.
**JS/TS analogy:** Like reading `event.clientX` minus the container's `getBoundingClientRect()` on every `pointermove`, done for you.
**In Shades:** `MaskOverlay` measures handle drags and the Draw Mask lasso in the viewer's space, then turns them into points of the clip's picture.

## Video colour tags (YCbCr matrix, primaries, transfer)
**What it is:** Video codecs store pictures as YCbCr (brightness plus two colour differences), not RGB. The file's colour tags say which maths turns that back into RGB: the YCbCr matrix (BT.601 or BT.709), the primaries and the transfer curve. Without tags, each Mac guesses, and a wrong matrix shifts saturated colours while greys stay put.
**JS/TS analogy:** Like an image without an embedded colour profile: browsers may assume different profiles, so the same file looks slightly different on two machines.
**In Shades:** `VideoFixture` tags its test videos as Rec.709, the same as iPhone footage, so golden frames match on the dev Mac and on CI. `PixelProbe` and `GoldenFrame` read frames in their own colour space so nothing gets colour-matched.

## `indirect enum` (recursive enums)
**What it is:** An enum whose cases can hold values of the enum itself, like a tree. `indirect` tells Swift to store those cases by reference so the type has a fixed size.
**JS/TS analogy:** A recursive union type: `type Change = { value: … } | { fields: Record<string, Change> }`.
**In Shades:** `ProjectChange` is a tree of what an edit changed: a field holds more changes, down to single values. Undoing a request walks the tree and puts back only those values.

## Catching one case of a typed error (`catch .editedSince`)
**What it is:** With typed throws the compiler knows the error's type, so a `catch` can match one case by name and leave the rest to a plain `catch`.
**JS/TS analogy:** `catch (e) { if (e.kind === "editedSince") … else … }`, but checked by the compiler.
**In Shades:** The History pane's Undo catches `.editedSince` to offer reverting to the snapshot, and shows any other error as is.

## `@discardableResult`
**What it is:** Marks a function whose return value callers may ignore without a compiler warning.
**JS/TS analogy:** None needed in JS; every return value can be ignored silently there.
**In Shades:** `ProjectFile.snapshot` returns the snapshot it saved. Claude's request snapshot keeps its name; the autosave timer ignores it.

## `.alert(_:isPresented:presenting:)`
**What it is:** An alert built from a value: while the value is set, the alert shows and its buttons and message get that value.
**JS/TS analogy:** `{blocked && <Dialog request={blocked} />}` in React.
**In Shades:** The History pane keeps the request Undo couldn't take back alone, and the alert offers to revert to its snapshot.

## HDR transfer functions and tone mapping
**What it is:** The transfer tag (see "Video colour tags") says how a number becomes light. SDR uses Rec.709's curve; HDR uses HLG (iPhones) or PQ, which hold light far brighter than an SDR screen can show. *Tone mapping* squeezes that light into SDR: here, everything up to 70% of "reference white" (203 nits) stays as it is, and brighter light rolls off smoothly towards white.
**JS/TS analogy:** Like fitting a value with a huge range into 0…1 with a soft `1 - exp(-x)` curve instead of `Math.min(x, 1)`, so bright values keep their differences instead of all clipping to 1.
**In Shades:** `MediaLoader` reads each file's tags into `VideoColor` (for the HDR badge and Claude); `toWorkingSpace` in Layers.metal converts the gamut and tone-maps HLG and PQ.

## `CVBuffer` attachments
**What it is:** Key–value notes carried on a pixel buffer, like its colour tags. `CVBufferCopyAttachment` reads one and `CVBufferSetAttachment` writes one; whoever displays or encodes the buffer reads them.
**JS/TS analogy:** Like the metadata on a `Blob` (its MIME type): the bytes are the same, the label tells the next step how to read them.
**In Shades:** `SourceColor(of:)` reads each frame's transfer and primaries tags to know what to convert, and `MetalCompositor` re-tags its output as SDR.

## Task-local values (`TaskLocal`)
**What it is:** A value attached to the current task and everything it awaits, set for a stretch of code with `withValue(_:operation:)` and read anywhere inside with `get()`. Code deep in another module can use it without it being passed through every function.
**JS/TS analogy:** Like Node's `AsyncLocalStorage`: `storage.run(value, fn)`, and any async code `fn` calls can read `storage.getStore()`.
**In Shades:** `JobQueue` runs each job with a pause gate as a task-local, so `JobQueue.pausePoint()` in a cut-out or stem loop knows which job it's in and waits while that job should pause.

## IOKit power sources (`IOPSCopyPowerSourcesInfo`)
**What it is:** A C API from IOKit that reports the Mac's power: `IOPSGetProvidingPowerSourceType` says whether it's on AC power or its battery. C functions hand back `Unmanaged` objects, and `takeRetainedValue()` / `takeUnretainedValue()` say who frees them ("Copy" functions give you one to free, "Get" functions don't).
**JS/TS analogy:** Like the browser's Battery Status API (`navigator.getBattery()` and `charging`), but synchronous and from C.
**In Shades:** `JobQueue.systemPause(pausesOnBattery:)` holds analysis jobs while a MacBook is unplugged.

## Process CPU time (`getrusage`)
**What it is:** A Unix call that fills in how much processor time this process has used so far, in user code and in the system. Two readings a few seconds apart, divided by the wall-clock time between them, give how busy the app is (100% is one full core).
**JS/TS analogy:** Node's `process.cpuUsage()`, compared between two calls.
**In Shades:** `CPUMeter` (ShadesEngine) for the HUD's CPU figure and the idle-CPU performance gate.

## `for case let` (pattern-matching loops)
**What it is:** `for case let (track?, pieces) in groups` loops only over the elements that match the pattern, unwrapping as it goes: here, pairs whose first part isn't `nil`, with `track` already unwrapped.
**JS/TS analogy:** Like `for (const [track, pieces] of entries) { if (track == null) continue; … }`, with the skip and the unwrap folded into the loop's header.
**In Shades:** `JoinClips` joins the pieces of a clip's linked sound, grouped by the track they're on.

## Characters and Unicode scalars
**What it is:** A Swift `Character` is what a reader sees as one letter, which can be several Unicode scalars (code points) joined: "कि" is the consonant क plus the vowel sign ि. `string.unicodeScalars` walks the code points one by one, and each scalar's `properties.generalCategory` says whether it's a letter, a combining mark, a number or punctuation.
**JS/TS analogy:** Like iterating `[...str]` (code points) instead of `str.split("")`, and testing each with `/\p{L}|\p{M}|\p{N}/u`.
**In Shades:** `PolishPlanner.normalized` keeps letters, marks and numbers scalar by scalar, so Hindi vowel signs and viramas survive while punctuation like the danda (।) goes, and "मतलब।" matches the filler "मतलब".

## Instanced drawing (`[[instance_id]]`)
**What it is:** One `drawPrimitives(…, instanceCount: n)` call draws the same shape `n` times; the vertex shader reads `[[instance_id]]` (0 … n−1) to tell the copies apart and place each one differently.
**JS/TS analogy:** Like WebGL2's `drawArraysInstanced` with `gl_InstanceID`, or rendering one React component in a `map` with a different `index` prop, all in a single call.
**In Shades:** Solid 3D letters are the text's picture drawn as up to 96 instanced slices, each pushed a little further back (`solidVertex`), so turning the text shows its depth.

## Distance fields
**What it is:** A picture whose every pixel holds how far it is from the edge of a shape (positive inside, negative outside). Comparing it with a number grows or shrinks the shape, and its slope says which way the edge faces.
**JS/TS analogy:** none built in; like computing, for every cell of a grid, the distance to the nearest wall with a BFS, then reading it back as a lookup table.
**In Shades:** `MetalRenderer.distanceField` measures the text's letters on the GPU by jump flooding (each pass, every pixel takes the nearest edge point known to pixels a halving step away); the solid-letter shader uses it to bevel the front edges and to light the sides.

## Self-similar zooms with logarithms (the Droste effect)
**What it is:** A picture that holds a smaller copy of itself in its middle, forever. For any point, `log` of its distance from the centre (in units of the copy's size) says how many copies deep it is; scaling it back up by that many whole copies lands it in the outer ring, which is just the picture. Zooming in by exactly one copy shows the same picture again, so the zoom can run forever.
**JS/TS analogy:** none built in; it's the maths behind CSS-free "infinite zoom" canvas demos: `Math.floor(-Math.log(size) / Math.log(nesting))`.
**In Shades:** `portalUV` in Layers.metal maps each point of a clip with a `portal` effect into that ring; keyframing `portal` (the travel) flies in through the copies.

## Compute kernels (`kernel`, `dispatchThreads`)
**What it is:** A Metal function marked `kernel` runs once per point of a grid you choose (here, once per pixel), reading and writing textures directly, with no triangles or blending; `dispatchThreads` launches it over the grid in groups of threads.
**JS/TS analogy:** Like a WebGPU compute shader, or `array.map` run on thousands of GPU cores at once.
**In Shades:** The solid-letter distance field: `edgeSeeds`, `jumpFlood` (a few times) and `signedDistance` run as kernels before the letters' slices are drawn.

