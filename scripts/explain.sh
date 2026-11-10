#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

mode="${1:-with-index}"
query_file="${ROOT_DIR}/db/queries/city_last_30_days.sql"

require_db

case "${mode}" in
  with-index)
    {
      printf 'EXPLAIN (ANALYZE, BUFFERS)\n'
      cat "${query_file}"
    } | psql_exec "${POSTGRES_DB}"
    ;;
  without-index)
    {
      printf 'BEGIN;\n'
      printf 'DROP INDEX %s;\n' "${REPORTING_INDEX}"
      printf 'EXPLAIN (ANALYZE, BUFFERS)\n'
      cat "${query_file}"
      printf 'ROLLBACK;\n'
    } | psql_exec "${POSTGRES_DB}"
    ;;
  *)
    die "usage: explain.sh [with-index|without-index]"
    ;;
esac
