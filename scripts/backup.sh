#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_db
mkdir -p "${BACKUP_DIR}"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_file="${BACKUP_DIR}/${POSTGRES_DB}_${timestamp}.dump"
manifest_file="${backup_file}.manifest"
partial_file="${backup_file}.partial"

trap 'rm -f "${partial_file}"' EXIT

log "dumping database '${POSTGRES_DB}'"
"${COMPOSE[@]}" exec -T "${DB_SERVICE}" \
  pg_dump -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
  --format=custom --compress=6 --no-owner --no-privileges \
  > "${partial_file}"

[[ -s "${partial_file}" ]] || die "dump is empty"
mv "${partial_file}" "${backup_file}"

log "writing manifest"
{
  for table in "${TABLES[@]}"; do
    table_fingerprint "${POSTGRES_DB}" "${table}"
  done
  printf 'sha256 %s\n' "$(file_sha256 "${backup_file}")"
} > "${manifest_file}"

if [[ -n "${BACKUP_RETENTION_DAYS}" ]]; then
  log "pruning backups older than ${BACKUP_RETENTION_DAYS} days"
  find "${BACKUP_DIR}" -maxdepth 1 -type f -name "${POSTGRES_DB}_*" -mtime "+${BACKUP_RETENTION_DAYS}" -delete
fi

log "backup complete: ${backup_file}"
log "size: $(wc -c < "${backup_file}" | tr -d ' ') bytes"
cat "${manifest_file}"
