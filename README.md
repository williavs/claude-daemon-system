<p align="center">
  <img src="assets/logo.svg" width="120" alt="claude-daemon"/>
</p>

<h3 align="center">claude-daemon</h3>
<p align="center">Claude Code forgets everything between sessions.<br/>This system makes it remember.</p>

---

## The problem

```
 Session 1                         Session 2
 ┌────────────────────┐            ┌────────────────────┐
 │  12 hours of work  │            │  Who am I?         │
 │  Bugs found        │──(lost)──▶ │  What project?     │
 │  Decisions made    │            │  Start over.       │
 │  Lessons learned   │            │                    │
 └────────────────────┘            └────────────────────┘
```

Sessions die. Context vanishes. Subagents ignore your instructions. Nobody reviews the work while you sleep. Lessons from failures evaporate.

## The fix

```
 Session 1                         Overnight                    Session 2
 ┌──────────────┐                  ┌──────────────┐            ┌──────────────────────┐
 │ Your work    │─── hooks ───────▶│ meta-agent   │──────────▶ │ Morning briefing:    │
 │              │  capture:        │ (opus, 3am)  │            │ "3 things happened.  │
 │              │  • prompts       │ reviews it   │            │  Here's what to fix. │
 │              │  • tool traces   │ all, updates │            │  PR #18 needs merge."│
 │              │  • decisions     │ the brain    │            │                      │
 │              │  • failures      │              │            │ Subagents know your  │
 │              │  • digests       │              │            │ design decisions.    │
 └──────────────┘                  └──────────────┘            └──────────────────────┘
```

## How it works

**18 hooks run silently every session:**

```
 You type a prompt
  │
  ├──▶ prompt captured (intent is the signal)
  ├──▶ design decisions extracted for subagents
  │
 Claude works
  │
  ├──▶ every tool call traced
  ├──▶ failures auto-captured as lessons
  ├──▶ subagents get your decisions injected (0.05s)
  │
 Session ends
  │
  ├──▶ session distilled to 3-line digest
  ├──▶ compaction survival logged
  └──▶ persist mode: blocks stop until goal is done
```

**Nightly pipeline runs while you sleep:**

```
 3:00am ── signals + meta-agent review (opus)
 5:30am ── Claude Code docs diff (catch new features)
 6:00am ── changelog analysis (adopt or remove)
 7:30am ── opportunity scanner → email
```

## The subagent fix

This was the pain that started it all:

```
 Before                              After
 ──────                              ─────

 You: "use shadcn registry"          You: "use shadcn registry"
       │                                   │
       ▼                                   ▼
 Subagent can't see                  Hook extracts decision,
 your conversation                   caches it (async, background)
       │                                   │
       ▼                                   ▼
 Hand-rolls everything               Subagent reads cache (0.05s)
       │                             Sees: "use shadcn registry"
       ▼                                   │
 You: "I said use shadcn!"                 ▼
                                     Uses shadcn ✓
```

Design decisions extracted after every prompt. Injected into every subagent. No delay.

## Quick start

```bash
git clone https://github.com/williavs/claude-daemon-system.git ~/claude-daemon
cd ~/claude-daemon
./cd-setup
```

## Commands

| Command | What it does |
|---------|-------------|
| `cd-status` | Dashboard: tasks, budget, circuit breaker |
| `cd-persist on "goal"` | Don't let Claude stop until done |
| `cd-tokens` | Where your tokens go (hint: subagents) |
| `cd-feedback good "reason"` | Rate today's idea, scanner learns |
| `cd-cost` | Daemon cost breakdown |
| `cd-review` | Full performance dashboard |

## What it costs

```
 Where tokens actually go (9.3B tokens analyzed):

 ████████████████████████████████████████████  Interactive sessions
 ██████████████████████████████               Subagents (hidden cost)
 ▎                                            claude-daemon ($0.05/day)
```

The daemon is a rounding error. Your interactive sessions and subagents are the real cost. `cd-tokens` shows you exactly where.

## Config

Everything is optional. Start with hooks only, add nightly pipeline later.

```bash
cp config.template.json config.json
# Edit: email, searxng (optional), fleet (optional), scan model
```

## Design principles

Built on the [effective-claude](program.template.md) methodology:

| Principle | What it means |
|-----------|--------------|
| Consumer backwards | Each stage reduces 80%. Traces → digests → briefing → 3 bullets |
| Match model to task | Haiku for scans ($0.005). Opus for the brain |
| Halt, don't flail | Circuit breakers everywhere. Budget caps. Max loops |
| Persist intent, not noise | Your prompts are the signal. Raw tool calls are not |

---

<p align="center">
  <sub>bash + <code>claude -p</code>. no frameworks. no databases. just files.</sub>
</p>
