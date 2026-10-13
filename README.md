# Shades

**An open-source, AI-native video editor for Mac.** Lightweight, Metal-fast, and fully drivable by Claude.

> Status: planning. Nothing to install yet. See [docs/PLAN.md](docs/PLAN.md).

## The idea
- **A real editor:** timeline, media, full color grading, titles and motion graphics, audio, captions, export. Built to play 4K smoothly even on a base M1 with 8 GB of RAM.
- **AI can do anything you can.** Every edit is a command, and every command is exposed to AI through a local MCP server. Claude can cut, grade, animate, caption and export, and it renders frames to *see* its own work.
- **Bring your own Claude.** Connect Claude Code or Claude Desktop on your own plan. Shades never handles logins or keys.

## Built with
Swift · SwiftUI + AppKit · Metal · AVFoundation · Apple Silicon only.

## Where to start
| Want to… | Read |
|---|---|
| Understand the architecture, the systems and the milestones | [docs/PLAN.md](docs/PLAN.md) |
| See the target look of the app | [docs/DESIGN.md](docs/DESIGN.md) |
| Know how the app behaves (flows, keymap, Claude) | [docs/UX.md](docs/UX.md) |
| Work on the repo (agents) | [CLAUDE.md](CLAUDE.md) |
| Know what the editor needs next | [Issues](https://github.com/sazuyakun/shades/issues). Feature requests come from real editing work in [shades-playbook](https://github.com/sazuyakun/shades-playbook) (private) |

## Repo layout
This will become a monorepo: the Mac app first, the website later.

## License
[MIT](LICENSE)
