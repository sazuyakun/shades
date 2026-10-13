# apps/mac: Shades.app

The Mac app. It's a **thin shell**: all real code lives in `packages/ShadesKit`. Root rules (git workflow etc.) in `/CLAUDE.md` still apply.

## What belongs here
- App entry point, scenes and windows (welcome window, main editor window)
- Menus and wiring keyboard shortcuts to commands
- Assets (app icon, accent defaults), Info.plist, entitlements
- `project.yml`: the XcodeGen spec

Anything else (model, engine, UI views, MCP server) goes in a ShadesKit module, not here.

## Rules
- Generate the project with XcodeGen from `project.yml`. Never commit `Shades.xcodeproj`.
- Build with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Swift 6 strict concurrency, macOS 15+, Apple Silicon only.
- **Not sandboxed** (direct download, not the App Store): Shades links media in place and runs a localhost MCP server.
- **No paid Apple signing:** builds are ad-hoc signed and not notarized. Don't add Developer ID / notarization steps.
- Bundle ID `com.sazuyakun.shades`. The app icon is a **placeholder** until launch (see `docs/LAUNCH.md`).
- Look and behaviour must match `docs/DESIGN.md` and `docs/UX.md`: v2 look (warm near-black, hairlines, title pill, capsules), FCP layout, the locked keymap.

## Building and running
- `xcodegen generate --spec apps/mac/project.yml --project apps/mac`
- `xcodebuild -project apps/mac/Shades.xcodeproj -scheme Shades -derivedDataPath apps/mac/.build build`
- Run: `open apps/mac/.build/Build/Products/Debug/Shades.app`. It listens for Claude on `127.0.0.1:4747`.
- `ShadesApp.swift` only creates the `Editor`, `Player` and `MCPServer`, starts the server and opens `EditorView`.

## Verifying
- The user often works via Remote Control: after a build, take screenshots of the running app and send them when asked.
- Check the performance targets in `docs/PLAN.md` §8 on the M1 8 GB machine.
