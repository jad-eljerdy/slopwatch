#!/bin/sh
set -eu
umask 077
root=${CLAUDE_CONFIG_DIR:-"$HOME/.claude"}
tmp=$(/usr/bin/mktemp "$root/.slopwatch-limits.XXXXXX")
trap '/bin/rm -f "$tmp"' EXIT
/usr/bin/jq -ce '
  {observed: (now | floor), rate_limits: (
      (.rate_limits // {}) | with_entries(
        select(.key == "five_hour" or .key == "seven_day" or .key == "seven_day_fable")
        | select(.value.used_percentage | type == "number")
        | .value |= {used_percentage, resets_at}
      )
  )}
  | select(.rate_limits | length > 0)
' > "$tmp" || exit 0
/bin/mv -f "$tmp" "$root/slopwatch-limits.json"
/usr/bin/jq -r '[.rate_limits | to_entries[] |
  (if .key == "five_hour" then "5h" elif .key == "seven_day_fable" then "Fable 7d" else "7d" end) + " " + (.value.used_percentage | round | tostring) + "%"] | join(" · ")' "$root/slopwatch-limits.json"
