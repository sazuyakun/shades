# Shades: launch checklist

Things that are fine to fake during development but **must** be done before Shades goes out to real users. Claude flags these when launch gets close.

- [ ] **Real app icon** (a temporary placeholder is used until then). No broken or placeholder icon at launch.
- [ ] Final bundle ID (currently `com.sazuyakun.shades`).
- [ ] Code signing (Developer ID) and notarization, so macOS opens the download without warnings. Needs the **Apple Developer Program ($99/year)**; not needed during development.
- [ ] Download page and hosting on the Shades website (`apps/web`).
- [ ] Auto-updates (Sparkle or similar).
- [ ] Privacy stance written down (proposed: no telemetry).
- [ ] Crash reporting decision.
- [ ] Licenses for anything bundled inside the app (fonts, LUTs, SFX, templates) allow redistribution. Personal Epidemic Sound downloads can't ship in the app.
- [ ] Third-party library licenses listed in the app's About/Acknowledgements (WhisperKit, Sparkle, MCP Swift library, etc.).
- [ ] Website domain (~$10–15/year); app downloads can be hosted on GitHub Releases for free.
