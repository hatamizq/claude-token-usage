# claude-token-usage

A **Claude Code status line** that keeps your token usage in view *all the time* — and shouts a warning **before** you pour a big prompt into a context that's already full.

No more running `/usage`, reading it, and exiting. No more typing out a long prompt only to hit a token/limit error on submit.

```
Opus 4.8 · ctx 150k/1.0M (15%) · room 850k tok (~638k words) · 5h 20% (reset 11:32) · week 8% (reset Wed Jul 8, 09:32) · $0.42
```

---

## The problem this solves

**1. "I wrote a huge prompt… then got a token-limit error."**
The most frustrating moment in a long session: you carefully compose a big prompt (or paste a large file), hit enter — and it fails because the context was already almost full. Effort wasted, flow broken.

This tool puts a **loud, always-visible guardrail** right at the prompt box. When your context is already getting tight, you see it *while you're still typing* — so you compact or start fresh **before** wasting the prompt:

```
 ⚠ CONTEXT 87% — getting tight, consider /compact soon    Opus 4.8 · ctx 870k/1.0M (87%) · room 130k tok (~98k words) · …
```
```
 ⛔ CONTEXT 96% — run /compact or /clear before typing more    Opus 4.8 · ctx 960k/1.0M (96%) · …
```

It also shows a **headroom readout** — `room 130k tok (~98k words)` — so you can eyeball whether the thing you're about to paste will even fit.

> **Honest limitation:** Claude Code has no per-keystroke hook, so nothing can measure the exact text you're mid-typing. This reflects how full the context *already* is (the thing that actually causes the error) and gives you a concrete remaining budget to type against. That's the real fix, and it needs no submit.

**2. "I want to know my usage without running `/usage` every time."**
`/usage` makes you run a command, read a panel, and exit. This surfaces the same information — the **5-hour** and **weekly** subscription windows, with reset times — passively, in the status line, so you always have ambient awareness of where you stand.

---

## What it shows

| Segment | Meaning |
|---|---|
| `Opus 4.8` | Current model |
| `ctx 150k/1.0M (15%)` | Context-window tokens used / total, and % (color-coded green→yellow→red) |
| `room 850k tok (~638k words)` | Remaining headroom — how much you can still type/paste |
| `5h 20% (reset 11:32)` | 5-hour subscription window used + when it resets (same data as `/usage`) |
| `week 8% (reset Wed Jul 8, 09:32)` | Weekly subscription window used + reset date |
| `$0.42` | Session cost so far |
| `⚠ / ⛔ banner` | Loud alert when context (or a usage window) is near its limit |

Reset times are smart: `11:32` if today, `tomorrow 09:00`, or `Wed Jul 8, 09:32` if further out.

---

## Example outputs (real test cases)

```text
--- SAFE (ctx 15%, no alert) ---
Opus 4.8 · ctx 150k/1.0M (15%) · room 850k tok (~638k words) · 5h 20% (reset 11:32) · week 8% (reset Wed Jul 8, 09:32) · $0.42

--- TIGHT (ctx 87% -> yellow banner) ---
 ⚠ CONTEXT 87% — getting tight, consider /compact soon   Opus 4.8 · ctx 870k/1.0M (87%) · room 130k tok (~98k words) · 5h 20% (reset 11:32) · week 8% (reset Wed Jul 8, 09:32) · $0.42

--- FULL (ctx 96% -> red banner) ---
 ⛔ CONTEXT 96% — run /compact or /clear before typing more   Opus 4.8 · ctx 960k/1.0M (96%) · room 40k tok (~30k words) · …

--- USAGE LIMIT (5h window near cap) ---
 ⛔ USAGE LIMIT 5h 97% — near cap   Opus 4.8 · ctx 400k/1.0M (40%) · 5h 97% (reset 11:32) · week 8% (reset Wed Jul 8, 09:32) · $0.42

--- BOTH (context full + weekly high) ---
 ⛔ CONTEXT 96% — run /compact or /clear before typing more  ⚠ usage high week 88%   Opus 4.8 · ctx 960k/1.0M (96%) · …
```

---

## Requirements

- [Claude Code](https://claude.com/claude-code)
- [`jq`](https://jqlang.github.io/jq/) — `brew install jq` (macOS) / `apt install jq` (Linux)
- The subscription-usage segments (`5h` / `week`) appear for Claude.ai Pro/Max plans, and only after the first reply in a session. Context, headroom, and cost always show.

---

## Install (run and done)

```bash
git clone https://github.com/hatamizq/claude-token-usage.git
cd claude-token-usage
./install.sh
```

That's it. The installer:
1. checks `jq` is present,
2. copies `statusline.sh` into `~/.claude/`,
3. merges the `statusLine` setting into `~/.claude/settings.json` **without touching your other settings** (it backs the file up first),
4. runs a smoke test so you see the output immediately.

Then **start a new Claude Code session** (or wait ~5s) and the status line appears under your prompt.

### Uninstall

```bash
./uninstall.sh
```

Removes the `statusLine` key (keeping the rest of your settings) and deletes the installed script. Your settings are backed up first.

---

## Configuration

Everything lives in one file: `~/.claude/statusline.sh`. Common tweaks:

- **Alert thresholds** — search for `-ge 85` / `-ge 95` and change the numbers.
- **Refresh rate** — `refreshInterval` in `~/.claude/settings.json` (seconds, min 1).
- **Hide/keep segments** — each segment (cost, rate limits, headroom) is a clearly-commented block you can delete.

---

## How it works

Claude Code can run a shell command as its [status line](https://docs.claude.com/en/docs/claude-code/statusline) and pipes a JSON blob to it on every render (on a timer + on events). The script reads:

- `.context_window.{context_window_size, used_percentage, current_usage}` → context usage + headroom
- `.rate_limits.{five_hour, seven_day}.{used_percentage, resets_at}` → the same windows `/usage` shows
- `.cost.total_cost_usd` → session cost

No API calls, no transcript parsing, no network — just the data Claude Code already hands the status line.

---

## License

MIT — see [LICENSE](LICENSE).
