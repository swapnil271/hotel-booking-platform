#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_db

for file in "${ROOT_DIR}"/db/migrations/*.sql; do
  log "applying $(basename "${file}")"
  psql_exec "${POSTGRES_DB}" < "${file}"
done

log "migrations applied"
