# Shades: design (main window)

Locked target look: [design/mockup.png](design/mockup.png) (source: [design/mockup.html](design/mockup.html)).

![Shades main window mockup](design/mockup.png)

## Decisions
| Topic | Decision |
|---|---|
| Overall feel | Final Cut-like: calm, native, few panels, big viewer |
| Layout | FCP classic: media browser top-left, viewer top-center, inspector right, timeline across the bottom |
| Look | Classic pro dark: solid dark grey panels, no translucency, so the footage stays the focus |
| Pages | One screen. Color, audio and info live as inspector tabs (Video · Color · Audio · Info); scopes open beside the viewer when needed |
| Timeline | FCP-style rounded clips with filmstrips and waveforms, plus slim track headers (T1, V2, V1, A1, A2 with visibility / lock / mute / solo) |
| Accent | The user's macOS system accent color for selection and highlights; white playhead |
| Density | FCP density: small system font, compact controls |
| Media browser | Thumbnail grid by default, with hover-scrub |
| AI placement | No permanent panel. Select clips and a pop-up prompt appears next to them, showing what it will send (clips, range, transcript, frames) |
| AI changes | Clips Claude changed get a soft purple glow that fades after a few seconds, plus a toast ("Claude · added 2 B-roll clips") with Undo. Purple is reserved for AI so it never looks like a selection |

## Inspiration
- Final Cut Pro (layout, timeline, overall calm): https://www.apple.com/final-cut-pro/
- Logic Pro (dense but native pro controls): https://www.apple.com/logic-pro/
- DaVinci Resolve (track headers, used only lightly): https://www.blackmagicdesign.com/products/davinciresolve/edit
