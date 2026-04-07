# Claude Daemon (cd)

A cheap, observable, autonomous agent system built on `claude -p`, filesystem messaging, and circuit breakers.

## Philosophy

- Bash + JSON files. No frameworks, no dependencies beyond claude CLI and jq.
- Agents sleep for free (filesystem polling, zero tokens during idle).
- Full observability: every action logged, every dollar tracked, every decision auditable.
- Circuit breakers prevent runaway cost. Token budgets enforced per-hour.
- Haiku for triage/routing, Sonnet for work, Opus only when stuck.

## Architecture

```
~/.claude-daemon/
├── daemon.sh              # Main loop (cron or long-running)
├── config.json            # Global config (budgets, models, fleet)
├── tasks/                 # Task board (JSON files)
│   ├── task-001.json      # { status, owner, subject, result }
│   └── task-002.json
├── inbox/                 # JSONL message inboxes per agent
│   ├── conductor.jsonl
│   ├── worker-1.jsonl
│   └── worker-2.jsonl
├── logs/                  # Observability
│   ├── activity.jsonl     # Every action taken
│   ├── cost.jsonl         # Token usage per call
│   ├── errors.jsonl       # Failures and circuit breaker events
│   └── lessons.md         # Cross-session learning
├── state/                 # Runtime state
│   ├── circuit.json       # Circuit breaker state
│   └── budget.json        # Hourly token budget tracker
└── bin/
    ├── cd-start           # Start the daemon
    ├── cd-stop            # Stop gracefully
    ├── cd-status          # Show everything at a glance
    ├── cd-add             # Add a task
    ├── cd-logs            # Tail activity log
    └── cd-cost            # Show cost breakdown
```

## Core Loop

```
every POLL_INTERVAL (default 30s):
  1. Check circuit breaker state -> OPEN? sleep and skip
  2. Check hourly token budget -> exhausted? sleep and skip
  3. Scan inbox/ for messages -> process any found
  4. Scan tasks/ for unclaimed pending tasks -> claim one
  5. If claimed task: run claude -p with task prompt
  6. Log result to activity.jsonl
  7. Track tokens to cost.jsonl
  8. Update task status (completed/failed)
  9. On failure: increment circuit breaker counter
  10. On success: reset circuit breaker counter
  11. Capture lessons if failure (append to lessons.md)
```

## Cost Controls

| Control | Default | Description |
|---------|---------|-------------|
| MAX_TOKENS_PER_HOUR | 200000 | Hard token budget per hour |
| MAX_CALLS_PER_HOUR | 20 | Max claude -p invocations per hour |
| CB_NO_PROGRESS_THRESHOLD | 3 | Circuit opens after N failed loops |
| CB_COOLDOWN_MINUTES | 30 | How long circuit stays open |
| POLL_INTERVAL | 30 | Seconds between idle polls |
| DEFAULT_MODEL | sonnet | Model for standard work |
| TRIAGE_MODEL | haiku | Model for routing/summaries |

## Observability

### activity.jsonl (every action)
```json
{"ts": "2026-04-04T01:00:00Z", "action": "claim_task", "task_id": "001", "agent": "worker-1"}
{"ts": "2026-04-04T01:00:05Z", "action": "run_claude", "task_id": "001", "model": "sonnet", "tokens_in": 1200, "tokens_out": 3400, "duration_ms": 8500, "cost_usd": 0.012}
{"ts": "2026-04-04T01:00:06Z", "action": "task_complete", "task_id": "001", "result": "success"}
```

### cost.jsonl (money tracking)
```json
{"ts": "2026-04-04T01:00:05Z", "model": "sonnet", "tokens_in": 1200, "tokens_out": 3400, "cost_usd": 0.012, "budget_remaining_usd": 0.488, "budget_remaining_tokens": 195400}
```

### cd-status output
```
Claude Daemon Status
====================
State:    RUNNING (circuit: CLOSED)
Uptime:   2h 15m
Budget:   $0.49 / $0.50 remaining (this hour)
Tokens:   195,400 / 200,000 remaining

Tasks:    3 pending, 1 in_progress, 12 completed, 1 failed
Workers:  1 active (worker-1 on task-014)

Last 5 actions:
  01:00  task-014 claimed by worker-1
  00:55  task-013 completed (sonnet, 4.2k tokens, $0.01)
  00:50  task-012 completed (sonnet, 8.1k tokens, $0.02)
  00:45  task-011 failed -> lesson captured
  00:40  task-010 completed (haiku, 0.8k tokens, $0.001)

Cost today: $0.23 (18 tasks completed)
```

## Task Format

```json
{
  "id": "001",
  "subject": "Check fleet health",
  "description": "SSH to each machine in the fleet, check disk/mem/services, report issues",
  "status": "pending",
  "owner": null,
  "model": "sonnet",
  "created_at": "2026-04-04T00:00:00Z",
  "completed_at": null,
  "result": null,
  "tokens_used": 0,
  "cost_usd": 0,
  "attempts": 0,
  "max_attempts": 3
}
```

## Message Format (JSONL inbox)

```json
{"type": "task_result", "from": "worker-1", "task_id": "001", "status": "completed", "summary": "All 5 machines healthy", "ts": "2026-04-04T01:00:00Z"}
{"type": "alert", "from": "worker-1", "message": "your-homelab disk at 92%", "severity": "warning", "ts": "2026-04-04T01:05:00Z"}
```

## Feedback Loop

When a task fails:
1. Log error details to errors.jsonl
2. Increment circuit breaker counter
3. Auto-append to lessons.md:
   ```
   ### 2026-04-04 | task-011: Deploy gridwatch
   - What: SSH connection refused to your-homelab
   - Root: sshd not running after reboot
   - Fix: Added systemctl enable sshd to post-reboot checklist
   - Prevention: Health check should verify SSH before deploy tasks
   ```
4. Next time a similar task is claimed, the agent reads lessons.md first

## Usage

```bash
# Start daemon (background)
cd-start

# Add tasks
cd-add "Check fleet health" "SSH to each machine, check disk/mem/services"
cd-add "Review PR #42" "Read the diff, check for issues, post comment"

# Monitor
cd-status        # Dashboard
cd-logs          # Tail activity
cd-cost          # Cost breakdown

# Stop
cd-stop
```

## Self-Improvement Tasks

The daemon doesn't just run operational tasks. It also runs self-improvement tasks that measure and improve its own effectiveness.

### Skill Quality Check
Periodically run a prompt through `claude -p` with and without a skill, compare the outputs using the analysis script, and log whether the skill is still producing measurable improvement.

### Lesson Review
Periodically read lessons.md and check if the same failures keep recurring. If a lesson isn't preventing the failure it describes, the lesson needs rewriting or the system needs a hook.

### Dead Weight Detection
Periodically check which skills, hooks, and commands exist but never trigger. Report candidates for removal. Every token of unused skill frontmatter is attention budget wasted.

### Field Report Collection
Periodically message peers asking for feedback on pain points. Aggregate responses into skill improvement candidates.
