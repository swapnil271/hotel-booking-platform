#!/usr/bin/env bash

apply_sql_directory() {
  local directory="$1"
  local file

  for file in "${directory}"/*.sql; do
    [ -e "${file}" ] || continue
    echo "init: applying ${file}"
    psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" --file "${file}"
  done
}

apply_sql_directory /db/migrations
apply_sql_directory /db/seed
