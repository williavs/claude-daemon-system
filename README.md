# claude-daemon

Autonomous Claude Code operations system for HFL. Runs nightly analysis, fleet monitoring, opportunity scanning, and session persistence -- all from bash + `claude -p`.

## What It Does

**Nightly Pipeline** (systemd timers, runs while you sleep):
- `2:55am` -- Auto-enroll new Tailscale machines into fleet monitoring
- `3:00am` -- Collect signals (GitHub, fleet health, git activity) + run opus meta-agent review
- `6:00am` -- Scan Claude Code changelog for features to adopt or dead weight to remove  
- `7:30am` -- Opportunity scanner: finds one validated buildable idea, emails it to the team

**Session Persistence** (hooks in `~/.claude/settings.json`):
- `PostToolUse` -- Trace every Edit/Write/Bash/Agent call
- `UserPromptSubmit` -- Capture user intent (the most valuable signal)
- `SessionEnd` -- Distill session into 3-5 line digest
- `PreCompact` -- Re-inject critical context before compression
- `Stop` -- Persist mode: blocks Claude from stopping until goal is complete

**Fleet Monitoring** (push-based, 5 machines):
- Each machine reports health every 5 min to your-homelab
- Haiku reads raw dumps and finds problems for $0.002
- Auto-enrollment via Tailscale discovery

## Commands

```bash
cd-start              # Start the daemon loop
cd-stop               # Stop gracefully
cd-status             # Dashboard: tasks, budget, circuit breaker, cost
cd-add "task" "desc"  # Add a task (--model=haiku --tools="Bash(ssh:*)" --turns=3)
cd-logs [activity|cost|errors|lessons|daemon]
cd-cost               # Cost breakdown by model
cd-review             # Full performance review for Jim
cd-persist on|off|status  # Session persistence mode
cd-feedback fire|good|meh|dead "reason"  # Rate today's opportunity idea
```

## Architecture

```
~/.claude-daemon/
├── config.json           # Budgets, models, fleet hosts
├── program.md            # The daemon's brain (meta-agent updates this)
├── tasks/                # Task queue (JSON files)
├── logs/
│   ├── activity.jsonl    # Every action
│   ├── cost.jsonl        # Token usage per call
│   ├── errors.jsonl      # Failures
│   ├── reviews.jsonl     # Self-review scores
│   ├── lessons.md        # Learned from failures
│   ├── digests.jsonl     # Session summaries
│   ├── meta/             # Nightly meta-agent output
│   ├── signals/          # Daily signal aggregation
│   ├── scans/            # Opportunity scanner output + feedback
│   ├── changelog/        # Claude Code release analysis
│   └── briefings/        # Morning briefings from meta-agent
├── traces/               # Tool call traces (daily JSONL)
├── prompts/              # User prompts (daily JSONL)
├── state/                # Runtime: circuit breaker, budget, persist mode
└── staging/              # Meta-agent proposals for Jim's review
```

## Cost Controls

| Control | Default | Description |
|---------|---------|-------------|
| Token budget | 200K/hr | Hard cap per hour |
| Call budget | 20/hr | Max `claude -p` calls per hour |
| Circuit breaker | 3 failures | Opens after 3 consecutive failures, 30min cooldown |
| Per-task tools | `Read,Grep,Glob,Bash` | Each task gets scoped permissions |
| Meta-agent cap | $2.00 | Max budget for nightly opus review |
| Scan cap | $2.00 | Max budget for opportunity scanner |
| Self-review | 180 chars | Haiku reviews fit capture limit |

## Key Design Decisions

Built on the [effective-claude](https://github.com/Human-Frontier-Labs-Inc/claude-daemon/blob/master/program.md) methodology:

- **Bash collects, models reason.** Signal collection via curl/ssh/searxng is free. Only pay for the reasoning step.
- **Consumer backwards.** Every pipeline stage reduces 80% and keeps the signal. Raw traces -> session digests -> daily briefing -> 3 bullets.
- **Checklists in prompts.** A/B tested: fleet health with checklist covers 5/5 machines in 1 turn. Without: 2/5 in 4 turns.
- **Few-shot examples.** Self-assessment with examples produces 3x more actionable output at lower cost.
- **Minimum 2 turns.** Any task using tools needs turn 1 for the tool call, turn 2 for synthesis.
- **Self-improving feedback loop.** `cd-feedback` rates ideas, meta-agent updates program.md, lessons.md prevents repeat failures.

## Setup

Requires: `claude` CLI, `jq`, `python3`, `ssh` access to fleet machines, `resend-email` for opportunity scanner.

```bash
# Link the daemon home
ln -s ~/projects/claude-daemon ~/.claude-daemon

# Install systemd timers
# (see fleet/install-reporter.sh for fleet machines)

# Add hooks to ~/.claude/settings.json
# (see hooks/ directory for all hook scripts)
```

## The Nightly Meta-Agent

Opus with max thinking, $2 cap, 30 turns. Reads:
- Session digests (what happened today)
- Task results + self-review scores
- Lessons from failures
- Daily signals (GitHub, fleet, changelog)

Produces:
- Morning briefing (3 bullets for Willy)
- program.md updates (patterns that work, known issues)
- Skill candidates (repeated patterns worth codifying)
- New daemon tasks

## The Opportunity Scanner

Opus, $2 cap. Runs daily at 7:30am:
1. Bash collects signals: HN, GitHub trending, Lobsters, Reddit demand, X power users (via searxng)
2. Opus reasons with HFL's design methodology baked in
3. One validated idea emailed to the team
4. `cd-feedback` closes the loop for continuous improvement
