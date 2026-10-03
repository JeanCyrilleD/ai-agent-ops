#!/usr/bin/env bash
#
# fleet_healthcheck — health overview for a multi-workshop agent fleet.
#
# Reads a services file (one service per line) and prints an OK/FAIL table,
# one row per workshop. Built for cron/launchd: quiet on success, explicit
# on failure, machine-readable exit status.
#
# Usage:
#   fleet_healthcheck.sh [--services FILE] [--timeout SECONDS] [--quiet]
#
# Services file format (blank lines and '#' comments are ignored):
#   name | type | target
#     type "cmd"  — target is a shell command; healthy when it exits 0
#     type "port" — target is host:port; healthy when TCP connects
#     type "proc" — target is a process-name pattern; healthy when found running
#
# Environment:
#   FLEET_SERVICES  default services file (default: ./fleet.services)
#   FLEET_TIMEOUT   seconds allowed for each port check (default: 3)
#
# Exit status: 0 = all healthy, 1 = at least one failure, 2 = usage/config error.
#
# Example fleet.services:
#   # name   | type | target
#   api      | port | 127.0.0.1:8080
#   worker   | proc | fleet-worker
#   disk-ok  | cmd  | test "$(df / | awk 'NR==2{print $5}' | tr -d '%')" -lt 90

set -u

SERVICES="${FLEET_SERVICES:-./fleet.services}"
TIMEOUT="${FLEET_TIMEOUT:-3}"
QUIET=0

usage() {
    echo "usage: fleet_healthcheck.sh [--services FILE] [--timeout SECONDS] [--quiet]" >&2
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --services) SERVICES="${2:?missing value for --services}"; shift 2 ;;
        --timeout)  TIMEOUT="${2:?missing value for --timeout}"; shift 2 ;;
        --quiet)    QUIET=1; shift ;;
        -h|--help) usage ;;
        *) echo "unknown option: $1" >&2; usage ;;
    esac
done

case "$TIMEOUT" in ''|*[!0-9]*) echo "error: --timeout must be a positive integer" >&2; exit 2 ;; esac
[ ! -f "$SERVICES" ] && { echo "error: services file not found: $SERVICES" >&2; exit 2; }

# --- check primitives -------------------------------------------------------
check_cmd()  { bash -c "$1" >/dev/null 2>&1; }

check_port() { # $1 = host, $2 = port
    local host="$1" port="$2"
    if command -v timeout >/dev/null 2>&1; then
        timeout "$TIMEOUT" bash -c "exec 3<>/dev/tcp/${host}/${port}" >/dev/null 2>&1
    elif command -v nc >/dev/null 2>&1; then
        nc -z -w "$TIMEOUT" "$host" "$port" >/dev/null 2>&1
    else
        bash -c "exec 3<>/dev/tcp/${host}/${port}" >/dev/null 2>&1
    fi
}

check_proc() {
    # pgrep -f matches full command lines, so exclude the checker itself:
    # a pattern appearing on our own command line would otherwise
    # self-match. (The parent is intentionally NOT excluded: in
    # interactive use it is often the operator's own shell.)
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -f "$1" 2>/dev/null | grep -v -e "^$$\$" | grep -q .
    else
        ps aux 2>/dev/null | grep -F "$1" | grep -vq "grep -F $1"
    fi
}
# ----------------------------------------------------------------------------

# Colors only on a terminal.
if [ -t 1 ]; then GREEN='\033[32m'; RED='\033[31m'; RESET='\033[0m';
else GREEN=''; RED=''; RESET=''; fi

trim() { # strip leading/trailing whitespace
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

total=0; failed=0
[ "$QUIET" -eq 0 ] && printf '%-24s %-6s %s\n' "WORKSHOP" "STATUS" "DETAIL"

while IFS= read -r line || [ -n "$line" ]; do
    line="$(trim "$line")"
    case "$line" in ''|'#'*) continue ;; esac
    total=$((total + 1))
    name="$(trim "$(printf '%s' "$line" | cut -d'|' -f1)")"
    type="$(trim "$(printf '%s' "$line" | cut -d'|' -f2)")"
    target="$(trim "$(printf '%s' "$line" | cut -d'|' -f3-)")"
    [ -z "$name" ] && name="row-$total"

    status="FAIL"; detail=""
    case "$type" in
        cmd)
            if check_cmd "$target"; then status="OK"; else detail="exit != 0"; fi ;;
        port)
            host="${target%:*}"; port="${target##*:}"
            if [ -z "$host" ] || [ -z "$port" ]; then
                detail="bad target (want host:port)"
            elif check_port "$host" "$port"; then status="OK"
            else detail="no TCP connect"; fi ;;
        proc)
            if check_proc "$target"; then status="OK"; else detail="not running"; fi ;;
        *)
            detail="unknown type '$type'" ;;
    esac

    if [ "$status" = "OK" ]; then
        [ "$QUIET" -eq 0 ] && printf '%-24s %s\n' "$name" "${GREEN}OK${RESET}"
    else
        failed=$((failed + 1))
        printf '%-24s %s %s\n' "$name" "${RED}FAIL${RESET}" "$detail"
    fi
done < "$SERVICES"

healthy=$((total - failed))
echo "fleet_healthcheck: ${healthy}/${total} healthy"
[ "$failed" -gt 0 ] && exit 1
exit 0
