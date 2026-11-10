.PHONY: up down reset migrate seed backup restore explain explain-baseline lint tf-fmt tf-init tf-validate tf-plan

ENV ?= dev
TF_DIR = infra/envs/$(ENV)

up:
	docker compose up -d --wait

down:
	docker compose down

reset:
	docker compose down -v
	docker compose up -d --wait

migrate:
	./scripts/migrate.sh

seed:
	./scripts/seed.sh

backup:
	./scripts/backup.sh

restore:
	./scripts/restore.sh

explain:
	./scripts/explain.sh with-index

explain-baseline:
	./scripts/explain.sh without-index

lint:
	shellcheck --exclude=SC1090,SC1091 scripts/*.sh db/docker-entrypoint/init.sh

tf-fmt:
	terraform fmt -check -recursive -diff infra

tf-init:
	terraform -chdir=$(TF_DIR) init -backend=false -input=false

tf-validate: tf-init
	terraform -chdir=$(TF_DIR) validate

tf-plan: tf-init
	terraform -chdir=$(TF_DIR) plan -refresh=false -input=false -var plan_only=true
