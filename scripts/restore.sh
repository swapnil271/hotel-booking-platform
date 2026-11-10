#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

backup_file="${1:-}"

if [[ -z "${backup_file}" ]]; then
  backup_file="$( (find "${BACKUP_DIR}" -maxdepth 1 -type f -name "${POSTGRES_DB}_*.dump" 2>/dev/null || true) | sort | tail -n 1)"
fi

[[ -n "${backup_file}" ]] || die "no backup found in ${BACKUP_DIR}, run ./scripts/backup.sh first"
[[ -f "${backup_file}" ]] || die "backup file not found: ${backup_file}"
[[ "${RESTORE_DB}" != "${POSTGRES_DB}" ]] || die "RESTORE_DB must differ from POSTGRES_DB"
[[ "${RESTORE_DB}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || die "RESTORE_DB contains unsupported characters"

manifest_file="${backup_file}.manifest"

require_db

if [[ -f "${manifest_file}" ]]; then
  expected_sha="$(awk '$1 == "sha256" {print $2}' "${manifest_file}")"
  actual_sha="$(file_sha256 "${backup_file}")"
  [[ "${expected_sha}" == "${actual_sha}" ]] || die "checksum mismatch for ${backup_file}"
  log "checksum verified"
else
  log "WARNING: no manifest for ${backup_file}, integrity comparison will be skipped"
fi

log "recreating database '${RESTORE_DB}'"
psql_exec postgres -c "DROP DATABASE IF EXISTS \"${RESTORE_DB}\" WITH (FORCE)"
psql_exec postgres -c "CREATE DATABASE \"${RESTORE_DB}\""

log "restoring ${backup_file} into '${RESTORE_DB}'"
"${COMPOSE[@]}" exec -T "${DB_SERVICE}" \
  pg_restore -U "${POSTGRES_USER}" -d "${RESTORE_DB}" \
  --no-owner --no-privileges --exit-on-error \
  < "${backup_file}"

status=0

for table in "${TABLES[@]}"; do
  actual="$(table_fingerprint "${RESTORE_DB}" "${table}")"
  if [[ -f "${manifest_file}" ]]; then
    expected="$(awk -v t="${table}" '$1 == t {print $0}' "${manifest_file}")"
    if [[ "${expected}" == "${actual}" ]]; then
      log "OK   ${actual}"
    else
      log "FAIL expected '${expected}' got '${actual}'" >&2
      status=1
    fi
  else
    log "INFO ${actual}"
  fi
done

index_count="$(psql_exec "${RESTORE_DB}" -A -t -c "SELECT count(*) FROM pg_indexes WHERE schemaname = 'public' AND indexname = '${REPORTING_INDEX}'" | tr -d '\r')"
if [[ "${index_count}" == "1" ]]; then
  log "OK   index ${REPORTING_INDEX} present"
else
  log "FAIL index ${REPORTING_INDEX} missing" >&2
  status=1
fi

if [[ "${status}" -ne 0 ]]; then
  die "restore verification failed"
fi

log "restore verified: '${RESTORE_DB}' matches ${backup_file}"
