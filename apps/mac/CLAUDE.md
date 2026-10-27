# apps/mac: Shades.app

The Mac app. It's a **thin shell**: all real code lives in `packages/ShadesKit`. Root rules (git workflow etc.) in `/CLAUDE.md` still apply.

## What belongs here
- App entry point, scenes and windows (welcome window, main editor window)
- Hooking up the menus that ShadesUI provides (`FileMenu`); editor actions and their keys live in ShadesUI's `EditorAction`
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
- Run: `open apps/mac/.build/Build/Products/Debug/Shades.app`. It serves MCP at `http://127.0.0.1:4747/mcp`.
- **Soham's everyday copy** lives in `/Applications`: build with `-configuration Release` (Debug is slower), quit Shades (it saves on quit), then `ditto apps/mac/.build/Build/Products/Release/Shades.app /Applications/Shades.app`. Claude Code reaches it through the user-scope MCP server `shades` (`claude mcp add --scope user --transport http shades http://127.0.0.1:4747/mcp`).
- `AppDelegate` owns the one `Workspace` (open project, player, Claude's server) and saves it before quitting. `ShadesApp` declares the editor and welcome windows (each reopens the last project if it was open) and Settings.

## Verifying
- The user often works via Remote Control: after a build, take screenshots of the running app and send them when asked.
- Check the performance targets in `docs/PLAN.md` §8 on the M1 8 GB machine.
