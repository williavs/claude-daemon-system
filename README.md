# claude-daemon

Autonomous Claude Code operations system. Runs nightly analysis, opportunity scanning, session persistence, and self-improvement -- all from bash + `claude -p`.

## What It Does

**Nightly Pipeline** (systemd timers, runs while you sleep):
- `3:00am` -- Collect signals (GitHub, git activity) + run opus meta-agent review
- `5:30am` -- Snapshot Claude Code docs, diff against yesterday for new features
- `6:00am` -- Scan Claude Code changelog for features to adopt or dead weight to remove
- `7:30am` -- Opportunity scanner: finds one validated buildable idea, emails it to the team

**Session Persistence** (hooks in `~/.claude/settings.json`):
- `PostToolUse` -- Trace every Edit/Write/Bash/Agent call
- `UserPromptSubmit` -- Capture user intent + extract design decisions for subagents
- `SessionEnd` -- Distill session into digest for meta-agent
- `PreCompact` / `PostCompact` -- Re-inject critical context before compression, log what survived
- `Stop` -- Persist mode: blocks Claude from stopping until goal is complete
- `StopFailure` -- Alert on rate limits and API errors
- `PostToolUseFailure` -- Auto-capture lessons from tool failures
- `SubagentStart` -- Inject session design decisions into every subagent

**Token Analysis:**
- `cd-tokens` -- Analyze token usage across all projects, find where costs come from

## Setup

```bash
git clone https://github.com/williavs/claude-daemon-system.git ~/projects/claude-daemon
cd ~/projects/claude-daemon
./cd-setup
```

The setup script creates `config.json` from the template, links the daemon home, and optionally installs systemd timers.

## Commands

```bash
cd-start              # Start the daemon loop
cd-stop               # Stop gracefully
cd-status             # Dashboard: tasks, budget, circuit breaker, cost
cd-add "task" "desc"  # Add a task (--model=haiku --tools="Bash(ssh:*)" --turns=3)
cd-logs [activity|cost|errors|lessons|daemon]
cd-cost               # Cost breakdown by model
cd-review             # Full performance review
cd-persist on|off|status  # Session persistence mode
cd-feedback fire|good|meh|dead "reason"  # Rate today's opportunity idea
cd-tokens             # Token usage analysis across all projects
```

## Configuration

Copy `config.template.json` to `config.json` and edit:

```json
{
  "email": { "recipients": "you@example.com" },
  "searxng": { "enabled": false },
  "fleet": { "enabled": false },
  "scan": { "model": "claude-opus-4-6", "max_budget_usd": 2.00 }
}
```

Fleet monitoring, searxng, and email are all optional. The core system (daemon engine, hooks, meta-agent) works without them.

## Architecture

```
~/.claude-daemon/
├── config.json           # Your settings (from config.template.json)
├── program.md            # The daemon's brain (from program.template.md)
├── tasks/                # Task queue (JSON files)
├── logs/
│   ├── activity.jsonl    # Every action
│   ├── cost.jsonl        # Token usage per call
│   ├── errors.jsonl      # Failures + API errors
│   ├── reviews.jsonl     # Self-review scores
│   ├── lessons.md        # Learned from failures
│   ├── digests.jsonl     # Session summaries
│   ├── compactions.jsonl # What survived each compaction
│   ├── meta/             # Nightly meta-agent output
│   ├── signals/          # Daily signal aggregation
│   ├── scans/            # Opportunity scanner output + feedback
│   └── docs/             # Claude Code docs change reports
├── traces/               # Tool call traces (daily JSONL)
├── prompts/              # User prompts (daily JSONL)
└── state/                # Runtime: circuit breaker, budget, persist mode, subagent cache
```

## Hooks

18 hooks across 10 lifecycle events. All hooks are in `hooks/` and referenced from `~/.claude/settings.json`:

| Hook | Event | What it does |
|---|---|---|
| `trace-collector.sh` | PostToolUse | Log every tool call |
| `capture-prompt.sh` | UserPromptSubmit | Capture user intent |
| `extract-decisions.sh` | UserPromptSubmit | Cache design decisions for subagents (async) |
| `subagent-context.sh` | SubagentStart | Inject cached decisions into subagents (instant) |
| `morning-briefing.sh` | SessionStart | Surface overnight briefing |
| `session-end.sh` | SessionEnd | Distill session to digest |
| `pre-compact.sh` | PreCompact | Re-inject state before compression |
| `post-compact.sh` | PostCompact | Log what compaction preserved |
| `persist-stop.sh` | Stop | Block stop if persist goal active |
| `stop-failure.sh` | StopFailure | Log + alert on API errors |
| `tool-failure.sh` | PostToolUseFailure | Auto-capture failure lessons |

## Cost Controls

| Control | Default |
|---------|---------|
| Token budget | 200K/hr |
| Call budget | 20/hr |
| Circuit breaker | 3 failures, 30min cooldown |
| Meta-agent cap | $2.00 |
| Scan cap | $2.00 |
| Self-review | 180 chars max |

## Fleet Monitoring (Optional)

For multi-machine setups with Tailscale or SSH access. Each machine runs a health reporter that dumps state to a central host. See `fleet/` for install scripts.

To set up manually:
1. Set `fleet.enabled: true` and `fleet.health_dest` in config.json
2. Run `fleet/install-reporter.sh` on each Linux machine (or `install-reporter-macos.sh` for macOS)
3. The reporter runs every 5 min, dumps health to the destination host
4. `cd-signals` reads the dumps and includes them in the nightly signal digest

## The Nightly Meta-Agent

Opus with max thinking, $2 cap. Reads session digests, task results, self-review scores, lessons, and daily signals. Produces: morning briefing, program.md updates, skill candidates, and new daemon tasks.

## The Opportunity Scanner

Multi-pass pipeline: bash collects signals (HN, GitHub, Lobsters, Reddit via searxng + MCP) -> opus drafts with citations -> haiku fact-checks -> email. Uses clean-room methodology: find behaviors people pay for, strip hidden assumptions, rebuild AI-native.
