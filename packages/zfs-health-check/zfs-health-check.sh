# shellcheck shell=bash
# Checks every imported ZFS pool and posts to Discord only when something changes:
# new problems (pinging the admin role), a reminder while they persist, recovery,
# and an occasional all-clear summary. `zfs-health-check --print` shows the report
# without posting or touching state.
#
# Environment (set by the NixOS module):
#   EXPECTED_POOLS      space-separated pools that must be imported
#   MAX_CAPACITY        percent used that counts as a problem
#   SCRUB_MAX_AGE_DAYS  a finished scrub older than this is overdue
#   REMIND_HOURS        re-post unresolved problems this often
#   SUMMARY_DAYS        post an all-clear summary this often; 0 disables it
#   DISCORD_ROLE_ID     role pinged on problems; empty pings no one
#   CREDENTIALS_DIRECTORY/webhook, STATE_DIRECTORY  from systemd

print_only=false
[ "${1:-}" = --print ] && print_only=true

host=$(</proc/sys/kernel/hostname)
now=$(date +%s)
status=$(zpool status -j --json-int)
list=$(zpool list -j --json-int -o capacity)

# One object per problem; `key` stays stable while the problem lasts, so a change in the
# set of keys is what triggers an alert.
issues=$(jq -n -c \
  --argjson status "$status" \
  --argjson list "$list" \
  --argjson now "$now" \
  --argjson maxCap "${MAX_CAPACITY:-90}" \
  --argjson scrubDays "${SCRUB_MAX_AGE_DAYS:-10}" \
  --arg expected "${EXPECTED_POOLS:-}" '
  ($status.pools // {}) as $pools
  | [
      ($expected | split(" ")[] | select(. != "" and $pools[.] == null)
        | {key: "\(.):missing", text: "`\(.)` is not imported"}),
      ($pools | to_entries[] | .key as $p | .value as $v
        | (select($v.state != "ONLINE")
            | {key: "\($p):state", text: "`\($p)` is **\($v.state)**"}),
          ($v | .. | objects | select(has("vdev_type") and .vdev_type != "root")
            | (select(.state | IN("ONLINE", "AVAIL", "INUSE") | not)
                | {key: "\($p):vdev:\(.name)", text: "`\($p)`: `\(.name)` is **\(.state)**"}),
              (select(.read_errors + .write_errors + .checksum_errors > 0)
                | {key: "\($p):errors:\(.name)",
                   text: "`\($p)`: `\(.name)` has \(.read_errors) read, \(.write_errors) write, \(.checksum_errors) checksum errors"})),
          (select(($v.error_count // 0) > 0)
            | {key: "\($p):data-errors",
               text: "`\($p)` has \($v.error_count) data errors; see `zpool status -v \($p)`"}),
          ($v.scan_stats as $scan
            | if $scan == null then
                {key: "\($p):scrub", text: "`\($p)` has never been scrubbed"}
              elif $scan.function == "SCRUB" and $scan.state == "SCANNING" then empty
              elif $scan.function == "SCRUB" and ($now - $scan.end_time) > $scrubDays * 86400 then
                {key: "\($p):scrub",
                 text: "`\($p)` was last scrubbed \(($now - $scan.end_time) / 86400 | floor) days ago"}
              else empty end),
          (select(($v.scan_stats.errors // 0) > 0)
            | {key: "\($p):scrub-errors", text: "`\($p)`: the last scan hit \($v.scan_stats.errors) errors"}),
          ($list.pools[$p].properties.capacity.value as $cap
            | select($cap >= $maxCap)
            | {key: "\($p):capacity", text: "`\($p)` is \($cap)% full"})
        )
    ]')

summary=$(jq -n -r --argjson status "$status" --argjson list "$list" '
  ($status.pools // {}) | to_entries[] | .key as $p | .value
  | "`\($p)` \(.state) · \($list.pools[$p].properties.capacity.value)% used · "
    + (.scan_stats as $s
       | if $s == null then "never scrubbed"
         elif $s.state == "SCANNING" then "\($s.function | ascii_downcase) in progress"
         else "last \($s.function | ascii_downcase) \($s.end_time | strflocaltime("%Y-%m-%d")), \($s.errors) errors" end)')

if $print_only; then
  jq -r 'if length == 0 then "No problems." else .[].text end' <<<"$issues"
  echo
  echo "$summary"
  exit 0
fi

state=$STATE_DIRECTORY
webhook=$(cat "$CREDENTIALS_DIRECTORY/webhook")
role=${DISCORD_ROLE_ID:-}
touch "$state/issues"
read_stamp() { cat "$state/$1" 2>/dev/null || echo 0; }

current=$(jq -r '.[].key' <<<"$issues" | sort)
previous=$(sort "$state/issues")
new=$(comm -23 <(printf '%s\n' "$current" | sed '/^$/d') <(printf '%s\n' "$previous" | sed '/^$/d'))

# post <title> <body> <color> <ping:true|false>
post() {
  jq -n --arg title "$1" --arg body "$2" --argjson color "$3" --arg role "$role" --argjson ping "$4" '
    {
      content: (if $ping and $role != "" then "<@&\($role)>" else "" end),
      allowed_mentions: {roles: (if $ping and $role != "" then [$role] else [] end)},
      embeds: [{title: $title, description: ($body | .[0:4000]), color: $color}]
    }' | curl -fsS -H 'Content-Type: application/json' -d @- "$webhook" >/dev/null
}

red=14495300
green=7909721

if [ -n "$current" ]; then
  body=$(jq -r --arg new "$new" '
    ($new | split("\n")) as $n
    | .[] | .key as $k | (if any($n[]; . == $k) then "🆕 " else "• " end) + .text' <<<"$issues")
  if [ -n "$new" ]; then
    post "🚨 ZFS on $host needs attention" "$body" "$red" true
    echo "$now" >"$state/alerted-at"
  elif [ $((now - $(read_stamp alerted-at))) -ge $((${REMIND_HOURS:-24} * 3600)) ]; then
    post "🚨 ZFS on $host still needs attention" "$body" "$red" true
    echo "$now" >"$state/alerted-at"
  fi
elif [ -n "$previous" ]; then
  post "✅ ZFS on $host is healthy again" "$summary" "$green" false
  echo "$now" >"$state/summary-at"
elif [ "${SUMMARY_DAYS:-7}" -gt 0 ] &&
  [ $((now - $(read_stamp summary-at))) -ge $((${SUMMARY_DAYS:-7} * 86400)) ]; then
  post "💾 ZFS on $host is healthy" "$summary" "$green" false
  echo "$now" >"$state/summary-at"
fi

printf '%s\n' "$current" | sed '/^$/d' >"$state/issues"
