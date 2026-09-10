# claude-status-line

A two-line status line for [Claude Code](https://claude.com/claude-code): matching gauges for your 5-hour and 7-day quotas, a context gauge with a live token count, session cost, model and reasoning effort, prompt-cache health, git state, and a countdown to your next quota reset.

```
5h ██░░░░░░░░ 23% 7d ████░░░░░░ 41% │ ████░░░░░░ 42% 84.2k/200k │ 1h12m api:18m │ $1.23
◆ Opus·high │ cache 91% │ ⎇ main* │ +156/-23 │ claude-status-line │ ⏳ reset: 1h47m → 16:19
```

---

> [!WARNING]
> **Not an Anthropic product.** This is an unofficial, community-written shell script. It is not made by, endorsed by, affiliated with, or supported by Anthropic. "Claude" and "Claude Code" are trademarks of Anthropic, PBC, used here only to describe what this script works with. **Do not report problems with this script to Anthropic** — open an issue on this repository instead.

---

## What it does

Claude Code runs a `statusLine` command after each response and pipes it a JSON snapshot of the session. This script reads that snapshot and renders two lines.

### Line 1 — the session

| Segment | Example | Meaning |
|---|---|---|
| 5-hour gauge | `5h ██░░░░░░░░ 23%` | How much of the 5-hour quota is spent |
| 7-day gauge | `7d ████░░░░░░ 41%` | How much of the 7-day quota is spent |
| Context gauge | `████░░░░░░ 42%` | How full the context window is |
| Tokens | `84.2k/200k` | Tokens in context vs. the window size |
| Elapsed | `1h12m api:18m` | Wall-clock time in this session, in whole days/hours/minutes, and how much of it was spent waiting on the API |
| Cost | `$1.23` | Session spend in USD |

The token figure is `input + cache_creation + cache_read` — precisely what occupies the window, so it always agrees with the percentage. The 5-hour and 7-day gauges use the same ten cells and the same green→red gradient as the context gauge, so a glance tells you which budget is running out first.

### Line 2 — the workspace

| Segment | Example | Meaning |
|---|---|---|
| Model | `◆ Opus·high` | The model handling this session, and its reasoning effort when the model supports one |
| Prompt cache | `cache 91%` | Share of this session's input tokens served from the prompt cache; reads `cache cold` when the cached prefix has expired |
| Branch | `⎇ main*` | Git branch; `*` means uncommitted changes |
| Churn | `+156/-23` | Lines added/removed by Claude this session |
| Directory | `claude-status-line` | Current working directory |
| Badge | `⚙ security-reviewer` | Active subagent, or `⚙ worktree:name` |
| Quota reset | `⏳ reset: 1h47m → 16:19` | Time left on the 5-hour window, and the local clock time it resets |

### Colors

| State | Threshold | Color |
|---|---|---|
| Context | ≥ 70% | amber |
| Context | ≥ 90% | red, plus a `⚠` |
| Cost | ≥ $5 / ≥ $10 | amber / red |
| 5-hour gauge | ≥ 70% / ≥ 90% | amber / red — same gradient as the context gauge |
| 7-day gauge | ≥ 60% / ≥ 80% | amber / red |
| Quota reset | ≤ 30 min away | amber |
| Prompt cache | < 80% / < 50% hit ratio | amber / red |

Sections with nothing to say stay hidden: no cost yet, no elapsed time, no API time under a minute, no line churn, no git repo, no cache stats before the first response, and no effort on models without the setting.

The gauge gradient is drawn at whatever color depth your terminal supports, and the script works that out for itself:

| Depth | Detected from | Gauge |
|---|---|---|
| 24-bit | `COLORTERM=truecolor`/`24bit`, `TERM` containing `truecolor` or `-direct`, `WT_SESSION` (Windows Terminal), `ConEmuANSI=ON`, `MSYSTEM` (Git Bash / mintty), `KONSOLE_VERSION`, `VTE_VERSION` ≥ 3600, or `TERM_PROGRAM` naming iTerm2, WezTerm, VS Code, Hyper, Ghostty, Rio, Tabby or Warp | smooth 10-step gradient |
| 256 | `TERM` containing `256color`, or Apple Terminal | 10-step gradient from the xterm cube |
| 16 | anything else — **this is the floor, not "no color"** | green → yellow → red in the 8 base ANSI colors |
| none | `NO_COLOR` set, `FORCE_COLOR=0`, or `TERM=dumb` | plain text |

An unrecognised terminal gets 16 colors rather than none, so PuTTY, the Windows console, and bare `TERM=xterm` sessions still come out colored.

### If someone's status line looks gray

Have them run the built-in check — it prints the depth that was detected and the environment behind it:

```bash
~/.claude/statusline.sh --diagnose
```

Then set the override in their shell profile:

| Symptom | Fix |
|---|---|
| Flat or washed-out gauge, but text is colored | `export CLAUDE_STATUSLINE_COLOR=truecolor` (or `256`) |
| Colors garbled or invisible | `export CLAUDE_STATUSLINE_COLOR=16` |
| Glyphs show as `â??` or boxes | `export CLAUDE_STATUSLINE_ASCII=1` — and in PuTTY set *Window → Translation → Remote character set* to **UTF-8**, which is not the default |
| Raw `[38;2;…m` escape codes | An old Windows console without ANSI support — use Windows Terminal, or `export CLAUDE_STATUSLINE_COLOR=none` |

### Appearance options

Set these in your shell profile:

| Variable | Effect |
|---|---|
| `CLAUDE_STATUSLINE_ASCII=1` | Pure ASCII — no Unicode, no box glyphs |
| `CLAUDE_STATUSLINE_NERDFONT=1` | Nerd Font icons for the branch, clock, and badges |
| `CLAUDE_STATUSLINE_POWERLINE=1` | Powerline separators (follows `NERDFONT` by default) |
| `CLAUDE_STATUSLINE_COLOR=` | Force a color depth: `truecolor`, `256`, `16`, or `none`. Overrides detection |
| `NO_COLOR=1` / `FORCE_COLOR=0..3` | Honored as usual; `CLAUDE_STATUSLINE_COLOR` wins over both |

## Requirements

- **bash** 3.2 or newer — the macOS system bash works, nothing newer is needed
- **[jq](https://jqlang.github.io/jq/)** — `install.sh` offers to install it for you
- **git** — optional; without it the branch segment simply stays empty

Tested on macOS, Debian/Ubuntu, and RHEL/Fedora/Rocky/Alma.

## Install

```bash
git clone https://github.com/franciscopaniskaseker/claude-status-line.git
cd claude-status-line
./install.sh
```

The installer will:

1. Install `jq` if it is missing — using `brew`, `apt-get`, `dnf`, or `yum`, **after asking you first** and showing the exact command it will run.
2. Copy `statusline.sh` to `~/.claude/statusline.sh` and `chmod 755` it.
3. Add a `statusLine` block to `~/.claude/settings.json`, leaving every other setting untouched.
4. Back up everything it touches (see below).

Then **restart Claude Code** — run `/exit` and relaunch `claude`. The status line does not appear until you do.

## Uninstall

```bash
./uninstall.sh
```

Removes the `statusLine` key from `~/.claude/settings.json`, deletes `~/.claude/statusline.sh`, and clears the cache files. Every other setting is left alone. Restart Claude Code afterwards.

## Backups

Both scripts back up every file they modify or replace, **on every run**, before touching anything. The suffix is `_backup_` followed by the Unix timestamp:

```
~/.claude/settings.json_backup_1757430000
~/.claude/statusline.sh_backup_1757430000
```

Repeated runs produce distinct files rather than overwriting each other. Nothing is ever deleted without a backup first, and nothing is cleaned up automatically — remove old backups yourself when you no longer want them.

If `~/.claude/settings.json` contains invalid JSON, the installer backs it up, refuses to modify it, and exits without changing anything else.

## About the rate-limit segments

The `5h` and `7d` gauges and the reset countdown come from data that Claude Code only sends when:

- you are on a **Claude Pro or Max** plan (or behind a gateway with a spend limit), **and**
- the session has already received **at least one response**.

Before then — and on API-key or Team/Enterprise setups — the percentages are hidden and the countdown shows the placeholder `⏳ reset: -- → --:--`. That is expected, not a bug. Claude Code also drops a window once it expires, so a just-reset window briefly shows the placeholder too.

The reset time is rendered as a 24-hour local clock, converted from the Unix timestamp Claude Code provides.

## Testing without Claude Code

```bash
./examples/test-mock.sh
```

Renders every scenario — normal, warning, danger, fresh session, near-exhausted quota, expired reset, 1M context, subagent, worktree, ASCII, Nerd Font, an empty payload, and one rendering per color depth — from mock JSON, so you can check your terminal's fonts and colors before installing.

To check color support alone:

```bash
./statusline.sh --diagnose
```

## Notes on behavior

- **Never blanks your prompt.** If `jq` is missing or the payload is unreadable, the script prints a short dim marker and exits `0`. A status line that exits non-zero leaves an empty bar.
- **Git state is cached** for 5 seconds in a per-user, per-directory file under `$TMPDIR`, so repeated renders do not re-run `git diff` on every keystroke.
- **`refreshInterval: 30`** is set in `settings.json` so the reset countdown keeps ticking between messages rather than freezing until your next prompt.

## Legal notice

Released under the [MIT License](LICENSE).

This software is provided **"as is", without warranty of any kind**, express or implied. See the LICENSE file for the full text.

`install.sh` modifies files in your home directory — specifically `~/.claude/settings.json` and `~/.claude/statusline.sh` — and, with your confirmation, may invoke your system package manager with `sudo` to install `jq`. **Read the scripts before running them.** You are responsible for reviewing any code you execute on your machine. The author accepts no liability for any loss or damage arising from its use.

See the warning at the top of this file: this project is not affiliated with Anthropic.
