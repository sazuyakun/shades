#!/bin/bash
# Claude Code PostToolUse hook: format and lint every Swift file Claude edits.
# Remaining lint violations are sent back to Claude (exit 2) so it fixes them.
export PATH="/opt/homebrew/bin:$PATH"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

file=$(jq -r '.tool_input.file_path // empty')
[[ "$file" == *.swift && -f "$file" ]] || exit 0

root="${CLAUDE_PROJECT_DIR:-$(git -C "$(dirname "$file")" rev-parse --show-toplevel)}"
swiftformat "$file" --config "$root/.swiftformat" --quiet

if ! violations=$(swiftlint lint --strict --quiet --config "$root/.swiftlint.yml" "$file" 2>&1); then
  echo "SwiftLint violations in $file (fix them, see /CLAUDE.md):" >&2
  echo "$violations" >&2
  exit 2
fi
