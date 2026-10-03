#!/usr/bin/env bash
#
# log_rotate — compress and prune agent log files with a retention policy.
#
# Keeps a fleet's log directory from growing forever: plain logs older than
# N days are gzip-compressed in place, and compressed archives older than
# M days are deleted. Safe to run from cron/launchd.
#
# Usage:
#   log_rotate.sh [--dir DIR] [--pattern GLOB] [--compress-after DAYS]
#                 [--keep DAYS] [--dry-run]
#
# Defaults: --dir ./logs, --pattern '*.log', --compress-after 7, --keep 30.
#
# Behavior:
#   1. Files matching PATTERN (and not already .gz) older than
#      COMPRESS_AFTER days are compressed with gzip -9 in place
#      (app.log -> app.log.gz). The original is removed by gzip itself.
#   2. '*.gz' archives older than KEEP days are deleted.
#   3. --dry-run prints every action without touching anything.
#
# Exit status: 0 on success, 2 on usage error.

set -u

DIR="./logs"
PATTERN="*.log"
COMPRESS_AFTER=7
KEEP=30
DRYRUN=0

usage() {
    echo "usage: log_rotate.sh [--dir DIR] [--pattern GLOB] [--compress-after DAYS] [--keep DAYS] [--dry-run]" >&2
    exit 2
}

is_posint() { case "$1" in ''|*[!0-9]*) return 1 ;; *) [ "$1" -ge 1 ] ;; esac; }

while [ $# -gt 0 ]; do
    case "$1" in
        --dir)            DIR="${2:?missing value for --dir}"; shift 2 ;;
        --pattern)        PATTERN="${2:?missing value for --pattern}"; shift 2 ;;
        --compress-after) COMPRESS_AFTER="${2:?missing value for --compress-after}"; shift 2 ;;
        --keep)           KEEP="${2:?missing value for --keep}"; shift 2 ;;
        --dry-run)        DRYRUN=1; shift ;;
        -h|--help)        usage ;;
        *) echo "unknown option: $1" >&2; usage ;;
    esac
done

is_posint "$COMPRESS_AFTER" || { echo "error: --compress-after must be a positive integer (days)" >&2; exit 2; }
is_posint "$KEEP"           || { echo "error: --keep must be a positive integer (days)" >&2; exit 2; }
[ -d "$DIR" ] || { echo "error: not a directory: $DIR" >&2; exit 2; }

n_compressed=0; n_deleted=0; bytes_saved=0

# find -mtime +N matches files older than N+1 days; +0 would also match
# "yesterday", so --compress-after 1 means "older than 24h".
older_than() { printf '+%s' "$(( $1 - 1 ))"; }

# --- 1. compress plain logs ---------------------------------------------------
while IFS= read -r -d '' f; do
    if [ "$DRYRUN" -eq 1 ]; then
        echo "would compress: $f"
    else
        size=$(wc -c <"$f" | tr -d ' ')
        if gzip -9 "$f"; then
            echo "compressed: ${f}.gz"
            n_compressed=$((n_compressed + 1))
            bytes_saved=$((bytes_saved + size))
        else
            echo "error compressing: $f" >&2
        fi
    fi
done < <(find "$DIR" -maxdepth 1 -type f -name "$PATTERN" ! -name '*.gz' \
              -mtime "$(older_than "$COMPRESS_AFTER")" -print0)

# --- 2. delete old archives ----------------------------------------------------
while IFS= read -r -d '' f; do
    if [ "$DRYRUN" -eq 1 ]; then
        echo "would delete: $f"
    else
        if rm -f "$f"; then
            echo "deleted: $f"
            n_deleted=$((n_deleted + 1))
        else
            echo "error deleting: $f" >&2
        fi
    fi
done < <(find "$DIR" -maxdepth 1 -type f -name '*.gz' \
              -mtime "$(older_than "$KEEP")" -print0)

echo "log_rotate: compressed=${n_compressed} deleted=${n_deleted} bytes_saved=${bytes_saved} dir=${DIR}"
exit 0
