#!/usr/bin/env bash
# SessionStart hook: checks for a morning briefing and injects it.
# If the nightly meta-agent left a briefing, this surfaces it.

set -uo pipefail

BRIEFING="${HOME}/.claude-daemon/logs/briefing.md"

if [ -f "$BRIEFING" ] && [ -s "$BRIEFING" ]; then
    # Only show if briefing is from today or yesterday
    briefing_date=$(head -1 "$BRIEFING" | grep -oP '\d{4}-\d{2}-\d{2}' || echo "")
    today=$(date -u +%Y-%m-%d)
    yesterday=$(date -u -d "yesterday" +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d 2>/dev/null || echo "")

    if [ "$briefing_date" = "$today" ] || [ "$briefing_date" = "$yesterday" ]; then
        # Output as system message so Claude sees it
        cat << EOF
{"systemMessage": "MORNING BRIEFING ($(cat "$BRIEFING"))"}
EOF
        # Archive it so it doesn't show twice
        mv "$BRIEFING" "${HOME}/.claude-daemon/logs/briefings/$(date -u +%Y-%m-%d).md" 2>/dev/null
    fi
fi

exit 0
