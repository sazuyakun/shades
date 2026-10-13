# Shades: launch checklist

Things that are fine to fake during development but **must** be done before Shades goes out to real users. Claude flags these when launch gets close.

- [ ] **Real app icon** (a temporary placeholder is used until then). No broken or placeholder icon at launch.
- [ ] Final bundle ID (currently `com.sazuyakun.shades`).
- [ ] Code signing (Developer ID) and notarization, so macOS opens the download without warnings.
- [ ] Download page and hosting on the Shades website (`apps/web`).
- [ ] Auto-updates (Sparkle or similar).
- [ ] Privacy stance written down (proposed: no telemetry).
- [ ] Crash reporting decision.
