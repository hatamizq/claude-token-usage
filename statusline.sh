#!/bin/bash
# Claude Code status line — shows model, context-window usage, and the same
# subscription rate-limit windows that /usage displays (5-hour + weekly).
# Reads the status JSON from stdin. Configured via settings.json -> statusLine.

input=$(cat)

# --- helpers ---------------------------------------------------------------
# Human-readable token counts: 1234 -> 1.2k, 1500000 -> 1.5M
human() {
  local n=$1
  if [ -z "$n" ] || [ "$n" = "null" ]; then echo "0"; return; fi
  if   [ "$n" -ge 1000000 ]; then awk "BEGIN{printf \"%.1fM\", $n/1000000}"
  elif [ "$n" -ge 1000 ];    then awk "BEGIN{printf \"%.0fk\", $n/1000}"
  else echo "$n"; fi
}

# Color a percentage: green <70, yellow <90, red >=90
pct_color() {
  local p=${1%%.*}; p=${p:-0}
  if   [ "$p" -ge 90 ]; then printf '\033[31m'   # red
  elif [ "$p" -ge 70 ]; then printf '\033[33m'   # yellow
  else printf '\033[32m'; fi                      # green
}

# Format an epoch (resets_at) for humans, blank if absent.
#   today            -> "18:38"
#   tomorrow         -> "tomorrow 09:00"
#   further out      -> "Sat Jul 5, 09:00"
reset_at() {
  local e=$1
  [ -z "$e" ] || [ "$e" = "null" ] && return
  local rday tday nday
  rday=$(date -r "$e" +%Y%m%d 2>/dev/null) || return
  tday=$(date +%Y%m%d)
  nday=$(date -v+1d +%Y%m%d 2>/dev/null)   # tomorrow (BSD/macOS date)
  if   [ "$rday" = "$tday" ]; then date -r "$e" +%H:%M
  elif [ "$rday" = "$nday" ]; then date -r "$e" "+tomorrow %H:%M"
  else date -r "$e" "+%a %b %-d, %H:%M"
  fi
}

DIM='\033[2m'; BOLD='\033[1m'; CYAN='\033[36m'; RESET='\033[0m'; SEP="${DIM} · ${RESET}"
REDBG='\033[41m\033[1m\033[97m'   # white-on-red, bold — the loud alert
YELBG='\033[43m\033[1m\033[30m'   # black-on-yellow, bold — the heads-up

# strip fractional part of a percent -> integer, default 0
as_int() { local p=${1%%.*}; echo "${p:-0}"; }

# --- model -----------------------------------------------------------------
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
out="${BOLD}${CYAN}${MODEL}${RESET}"

# --- context window --------------------------------------------------------
WIN=$(echo "$input"  | jq -r '.context_window.context_window_size // 0')
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
# tokens counted toward context = input + cache_read + cache_creation (not output)
CUR=$(echo "$input" | jq -r '
  (.context_window.current_usage) as $u
  | if $u == null then (.context_window.total_input_tokens // 0)
    else (($u.input_tokens // 0) + ($u.cache_read_input_tokens // 0) + ($u.cache_creation_input_tokens // 0))
    end')

if [ "$WIN" != "0" ] && [ -n "$WIN" ]; then
  c=$(pct_color "${CTX_PCT:-0}")
  p=${CTX_PCT%%.*}; p=${p:-0}
  # Headroom: tokens left and a rough word budget (~0.75 words per token)
  REMAIN=$(( WIN - CUR )); [ "$REMAIN" -lt 0 ] && REMAIN=0
  WORDS=$(( REMAIN * 3 / 4 ))
  out="${out}${SEP}${DIM}ctx${RESET} ${c}$(human "$CUR")/$(human "$WIN") (${p}%)${RESET}"
  out="${out}${DIM} · room $(human "$REMAIN") tok (~$(human "$WORDS") words)${RESET}"
else
  out="${out}${SEP}${DIM}ctx —${RESET}"
fi

# --- subscription rate limits (what /usage shows) --------------------------
FIVE=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_R=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_R=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

if [ -n "$FIVE" ]; then
  c=$(pct_color "$FIVE"); r=$(reset_at "$FIVE_R")
  lbl="5h ${FIVE%%.*}%"; [ -n "$r" ] && lbl="${lbl}${DIM} (reset ${r})"
  out="${out}${SEP}${c}${lbl}${RESET}"
fi
if [ -n "$WEEK" ]; then
  c=$(pct_color "$WEEK"); r=$(reset_at "$WEEK_R")
  lbl="week ${WEEK%%.*}%"; [ -n "$r" ] && lbl="${lbl}${DIM} (reset ${r})"
  out="${out}${SEP}${c}${lbl}${RESET}"
fi
# If the subscription rate-limit block isn't present yet, hint once it's live
if [ -z "$FIVE" ] && [ -z "$WEEK" ]; then
  out="${out}${SEP}${DIM}usage: after 1st reply${RESET}"
fi

# --- session cost (optional, small) ----------------------------------------
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$COST" ]; then
  out="${out}${SEP}${DIM}\$$(awk "BEGIN{printf \"%.2f\", $COST}")${RESET}"
fi

# --- LIVE GUARDRAIL: loud alert while you're still typing -------------------
# The status line refreshes on a timer, so this warning is visible BEFORE you
# submit — it tells you when the context (or a rate window) is already so full
# that your next prompt is likely to hit the limit.
CTX_INT=$(as_int "${CTX_PCT:-0}")
FIVE_INT=$(as_int "${FIVE:-0}")
WEEK_INT=$(as_int "${WEEK:-0}")
alert=""

# Context window — the token budget your prompt actually competes for.
if   [ "$CTX_INT" -ge 95 ]; then
  alert="${REDBG} ⛔ CONTEXT ${CTX_INT}% — run /compact or /clear before typing more ${RESET}"
elif [ "$CTX_INT" -ge 85 ]; then
  alert="${YELBG} ⚠ CONTEXT ${CTX_INT}% — getting tight, consider /compact soon ${RESET}"
fi

# Subscription windows — these also block execution when maxed.
if   [ "$FIVE_INT" -ge 95 ] || [ "$WEEK_INT" -ge 95 ]; then
  wmsg="⛔ USAGE LIMIT"; [ "$FIVE_INT" -ge 95 ] && wmsg="${wmsg} 5h ${FIVE_INT}%"; [ "$WEEK_INT" -ge 95 ] && wmsg="${wmsg} week ${WEEK_INT}%"
  alert="${alert:+$alert }${REDBG} ${wmsg} — near cap ${RESET}"
elif [ "$FIVE_INT" -ge 85 ] || [ "$WEEK_INT" -ge 85 ]; then
  wmsg="⚠ usage high"; [ "$FIVE_INT" -ge 85 ] && wmsg="${wmsg} 5h ${FIVE_INT}%"; [ "$WEEK_INT" -ge 85 ] && wmsg="${wmsg} week ${WEEK_INT}%"
  alert="${alert:+$alert }${YELBG} ${wmsg} ${RESET}"
fi

# Prepend the alert so it's the first, most visible thing at the prompt box.
[ -n "$alert" ] && out="${alert}  ${out}"

printf '%b' "$out"
