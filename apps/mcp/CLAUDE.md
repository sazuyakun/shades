# apps/mcp: the Claude relay (`shades-mcp`)

> **Being removed in M2.** Shades will serve MCP over HTTP itself (`docs/SYSTEM.md` §7), so this relay and its folder get deleted then. Don't extend it.

A tiny command-line program that connects Claude to Shades. **Claude Code and Claude Desktop both launch it** (they talk to local MCP servers over stdin/stdout), and it passes every byte to and from the MCP server running **inside Shades.app** on `127.0.0.1:4747`. Root rules (git workflow, Swift conventions) in `/CLAUDE.md` still apply.

## Why it's an app, not part of a package
It's a separate program that runs on its own, so it lives in `apps/`. The real MCP server (`ShadesMCP`) is a package module, because it has to run inside Shades.app to see the open project, the selection and rendered frames.

## Rules
- Keep it dumb: forward bytes both ways, with no editing logic and no MCP library. All tools live in `ShadesMCP`.
- The wire format is newline-delimited JSON-RPC, the same on both sides, so no translation is needed.
- If Shades.app isn't running, print "Shades isn't running. Open Shades, then try again." to stderr and exit 1.
- `Relay.port` must match `MCPServer.port` in ShadesMCP.
- Main-actor default isolation, like every app.

## Build and connect
- Build: `swift build -c release --package-path apps/mcp` → `apps/mcp/.build/release/shades-mcp`
- Claude Code: `claude mcp add shades -- <absolute path to shades-mcp>`
- Later it ships inside Shades.app, and the Claude setup sheet (M2) registers it automatically.
