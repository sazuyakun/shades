# apps/mcp: the Claude Desktop relay

A tiny command-line program. **Claude Desktop launches it** (Claude Desktop talks to local MCP servers over stdio), and it relays every message to the MCP server running **inside Shades.app** over localhost. Root rules (git workflow etc.) in `/CLAUDE.md` still apply.

## Why it's an app, not part of a package
It's a separate program that runs on its own, so it lives in `apps/`. The real MCP server (`ShadesMCP`) is a package module, because it has to run inside Shades.app to see the open project, the selection and rendered frames.

## Rules
- Keep it dumb: forward messages both ways, with no editing logic. All tools live in `ShadesMCP`.
- If Shades.app isn't running, answer with a clear "Open Shades first" error.
- Claude Code doesn't need this helper; it connects to Shades.app's localhost server directly.
- Swift, built as a small executable alongside the app (ships inside Shades.app so setup can point Claude Desktop at it).
