#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  source "${ROOT_DIR}/.env"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-app}"
POSTGRES_DB="${POSTGRES_DB:-hotel}"
RESTORE_DB="${RESTORE_DB:-hotel_restore}"
BACKUP_DIR="${BACKUP_DIR:-${ROOT_DIR}/backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-}"
DB_SERVICE="${DB_SERVICE:-db}"
REPORTING_INDEX="idx_hotel_bookings_city_created_at_cover"
TABLES=(hotel_bookings booking_events)

COMPOSE=(docker compose --project-directory "${ROOT_DIR}")

log() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

die() {
  log "ERROR: $*" >&2
  exit 1
}

require_db() {
  command -v docker >/dev/null 2>&1 || die "docker is not installed or not on PATH"
  "${COMPOSE[@]}" exec -T "${DB_SERVICE}" \
    pg_isready -h 127.0.0.1 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1 \
    || die "service '${DB_SERVICE}' is not running or not ready, start it with: docker compose up -d --wait"
}

psql_exec() {
  local database="$1"
  shift
  "${COMPOSE[@]}" exec -T "${DB_SERVICE}" \
    psql -U "${POSTGRES_USER}" -d "${database}" -X -q -v ON_ERROR_STOP=1 "$@"
}

table_fingerprint() {
  local database="$1"
  local table="$2"
  psql_exec "${database}" -A -t -F ' ' \
    -c "SELECT '${table}', count(*), coalesce(md5(string_agg(t::text, '|' ORDER BY id)), 'empty') FROM ${table} t" \
    | tr -d '\r'
}

file_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}
