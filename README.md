# hotel-booking-platform

Infrastructure and database reliability tooling for a hotel booking service.

- **Infrastructure**: Terraform for `Internet -> ALB -> ECS/Fargate -> RDS PostgreSQL` on AWS, with isolated `dev` and `prod` environments.
- **Database**: local PostgreSQL via Docker Compose with migrations, seed data, a tuned reporting index, and verified backup/restore scripts.
- **CI**: Terraform plan on every pull request, and an end-to-end backup/restore check for database changes.

No AWS account is needed to review this repository.

## Contents

- [Architecture](#architecture)
- [Repository layout](#repository-layout)
- [Quick start: local database](#quick-start-local-database)
- [Query optimization](#query-optimization)
- [Backup and restore](#backup-and-restore)
- [Terraform](#terraform)
- [Environments](#environments)
- [CI](#ci)
- [Design decisions](#design-decisions)
- [Known limitations](#known-limitations)

## Architecture

```
                     Internet
                        |
                  80 / 443 (allowed CIDRs)
                        |
             +----------v-----------+
             |  ALB  (public subnets)|   alb-sg
             +----------+-----------+
                        | container port, from alb-sg only
             +----------v-----------+
             | ECS Fargate tasks     |   ecs-sg
             | (private subnets)     |
             +----+-------------+---+
                  |             |
     5432, to rds-sg only    443 to NAT (image pull, Secrets Manager, logs)
                  |
             +----v-----------------+
             | RDS PostgreSQL        |   rds-sg
             | (private subnets,     |   ingress: 5432 from ecs-sg only
             |  not public)          |
             +----------------------+
```

Network controls:

| Security group | Ingress | Egress |
| --- | --- | --- |
| `alb-sg` | 80 (and 443 when a certificate is set) from `alb_ingress_cidrs` | container port to `ecs-sg` |
| `ecs-sg` | container port from `alb-sg` | 5432 to `rds-sg`, 443 to the internet via NAT |
| `rds-sg` | 5432 from `ecs-sg` | none |

RDS is created with `publicly_accessible = false`, lives in private subnets, and the only ingress rule on its security group references the ECS security group. The master password is generated and rotated by RDS in Secrets Manager (`manage_master_user_password`), so no credential appears in code, variables, or state outputs. The ECS task receives it as injected secrets.

## Repository layout

```
.
├── docker-compose.yml            local PostgreSQL 16
├── .env.example                  optional overrides for local scripts
├── Makefile                      shortcuts for common tasks
├── db/
│   ├── migrations/               ordered, idempotent schema changes
│   ├── seed/                     deterministic seed data (10,000 bookings)
│   ├── queries/                  the query being optimized
│   └── docker-entrypoint/        first-start hook: migrations, then seed
├── scripts/
│   ├── backup.sh                 timestamped dump plus integrity manifest
│   ├── restore.sh                restore into a fresh database and verify
│   ├── migrate.sh                apply migrations to a running database
│   ├── seed.sh                   apply seed data to a running database
│   ├── explain.sh                EXPLAIN ANALYZE with or without the index
│   └── common.sh                 shared helpers
├── infra/
│   ├── modules/
│   │   ├── network/              VPC, subnets, NAT, security groups
│   │   ├── ecs/                  cluster, task, service, ALB, autoscaling
│   │   └── rds/                  subnet group, parameter group, instance
│   └── envs/
│       ├── dev/                  root module: backend, variables, tfvars
│       └── prod/                 root module: backend, variables, tfvars
└── .github/workflows/
    ├── terraform-plan.yml        fmt, init, validate, plan on pull requests
    └── database.yml              shellcheck plus backup/restore end to end
```

## Quick start: local database

Requirements: Docker with the Compose plugin (v2.1 or newer for `--wait`).

```bash
docker compose up -d --wait
```

On first start the container applies every file in `db/migrations/` and then `db/seed/` in order. The healthcheck only turns healthy after that finishes, so `--wait` returns when the database is ready to use.

`./scripts/*.sh` work with no configuration. To change credentials, ports or the restore database name, copy `.env.example` to `.env`. Compose and the scripts both read it.

Verify the data:

```bash
docker compose exec db psql -U app -d hotel -c "
  SELECT count(*) AS bookings,
         count(DISTINCT city) AS cities,
         count(DISTINCT org_id) AS orgs,
         count(DISTINCT status) AS statuses
  FROM hotel_bookings;"

docker compose exec db psql -U app -d hotel -c "
  SELECT count(*) AS events,
         count(DISTINCT booking_id) AS bookings_with_events
  FROM booking_events;"
```

Expected: 10,000 bookings across 6 cities, 7 organizations, 5 statuses; roughly 18,000 events covering the 8,000 non-pending bookings.

Start over with a clean volume:

```bash
docker compose down -v && docker compose up -d --wait
```

### Schema

`hotel_bookings` and `booking_events` follow the suggested schema, with a few additions: `CHECK` constraints (checkout after checkin, non-negative amount, known statuses), `gen_random_uuid()` and `now()` defaults, and a foreign key from `booking_events.booking_id` to `hotel_bookings.id` with `ON DELETE CASCADE`. Migrations use `IF NOT EXISTS`, so `./scripts/migrate.sh` is safe to re-run.

### Seed data

`db/seed/001_seed_bookings.sql` is deterministic. IDs are derived from `md5()` so re-running it never duplicates rows, and `created_at` is generated relative to `NOW()` across the last 120 days, so the "last 30 days" query always has data. Events are only created for non-pending bookings, which leaves some bookings with no events.

## Query optimization

Target query (stored in `db/queries/city_last_30_days.sql`):

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Index added in `db/migrations/003_add_reporting_indexes.sql`:

```sql
CREATE INDEX idx_hotel_bookings_city_created_at_cover
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

Why this shape:

1. **Key columns `(city, created_at)`**: the query has an equality filter on `city` and a range filter on `created_at`. Equality column first, range column second lets PostgreSQL descend straight to `city = 'delhi'` and scan only the contiguous slice of the last 30 days. The reverse order would scan every city's recent rows and filter.
2. **`INCLUDE (org_id, status, amount)`**: these are the columns needed for `GROUP BY` and the aggregates. Storing them as non-key payload lets PostgreSQL answer the query from the index alone (an **Index Only Scan**) without visiting the table. They are `INCLUDE` columns rather than key columns because they are not used for searching, which keeps the index tree smaller and avoids needlessly sorting by them.
3. **Seed ends with `VACUUM (ANALYZE)`**: index-only scans depend on the visibility map and planner statistics, which `VACUUM` populates.

Compare plans yourself:

```bash
./scripts/explain.sh without-index
./scripts/explain.sh with-index
```

`without-index` drops the index inside a transaction, runs `EXPLAIN (ANALYZE, BUFFERS)`, and rolls back, so nothing changes permanently. Look for these differences:

| | Without index | With index |
| --- | --- | --- |
| Scan node | `Seq Scan on hotel_bookings` | `Index Only Scan using idx_hotel_bookings_city_created_at_cover` |
| Rows read from the table | all 10,000, then filtered | only the matching `delhi` / last-30-days entries |
| `Heap Fetches` | not applicable | close to 0 after `VACUUM` |

On a table this small the absolute timings are tiny. The point is the access path, which is what scales as the table grows. If the planner ever prefers a sequential scan on a very small table, that is expected behavior rather than a missing index.

## Backup and restore

```bash
./scripts/backup.sh
./scripts/restore.sh
```

### backup.sh

- Runs `pg_dump --format=custom` inside the container and streams it to `backups/hotel_<UTC timestamp>.dump`.
- Writes to a `.partial` file first and renames on success, so an interrupted backup never leaves a file that looks valid.
- Fails if the dump is empty.
- Writes `<dump>.manifest` containing a row count and an `md5` fingerprint of every row for each table, plus the SHA-256 of the dump file.
- Optional retention: set `BACKUP_RETENTION_DAYS=7` (for example in `.env`) to delete backups older than that. It is off by default.

### restore.sh

- Takes an optional dump path: `./scripts/restore.sh backups/hotel_20250101T000000Z.dump`. With no argument it uses the newest dump.
- Verifies the dump's SHA-256 against the manifest before touching the database.
- Drops and recreates a **separate** database (`hotel_restore` by default). The source database is never modified. The script refuses to run if `RESTORE_DB` equals `POSTGRES_DB`.
- Restores with `pg_restore --exit-on-error`.
- Compares row counts and row fingerprints of the restored tables against the manifest, and checks that the reporting index exists.
- Exits non-zero if anything differs.

### Verifying a restore worked

The script verifies automatically. A successful run ends with:

```
OK   hotel_bookings 10000 <fingerprint>
OK   booking_events 18000 <fingerprint>
OK   index idx_hotel_bookings_city_created_at_cover present
restore verified: 'hotel_restore' matches backups/hotel_<timestamp>.dump
```

Independent manual checks:

```bash
docker compose exec db psql -U app -d hotel_restore -c "\dt"

docker compose exec db psql -U app -d hotel_restore -c "
  SELECT (SELECT count(*) FROM hotel_bookings) AS bookings,
         (SELECT count(*) FROM booking_events) AS events;"

docker compose exec db psql -U app -d hotel -c "SELECT count(*) FROM hotel_bookings;"
```

The restored counts must match the source. Re-run the optimized query against `hotel_restore` to confirm the index came across:

```bash
docker compose exec -T db psql -U app -d hotel_restore < db/queries/city_last_30_days.sql
```

If rows are written to `hotel` between `backup.sh` and `restore.sh`, the restore is still correct, because it is compared to the manifest captured at backup time and not to the live database.

## Terraform

Requirements: Terraform 1.6 or newer.

### Reviewing without AWS credentials

`backend.tf` points at S3, which does not exist for a reviewer, so initialize with `-backend=false`. Setting `plan_only=true` makes the provider skip credential and account lookups; the configuration contains no data sources that call AWS, so `-refresh=false` plans work offline.

```bash
cd infra/envs/dev

terraform fmt -check -recursive ../..
terraform init -backend=false
terraform validate
terraform plan -refresh=false -var plan_only=true
```

Repeat in `infra/envs/prod`. The same flow is available as `make tf-fmt tf-validate tf-plan ENV=dev`.

### Real deployments

1. Create the state bucket and lock table for the environment (once per environment):

   ```bash
   aws s3api create-bucket --bucket hotel-booking-tfstate-dev --region ap-south-1 \
     --create-bucket-configuration LocationConstraint=ap-south-1
   aws s3api put-bucket-versioning --bucket hotel-booking-tfstate-dev \
     --versioning-configuration Status=Enabled
   aws s3api put-public-access-block --bucket hotel-booking-tfstate-dev \
     --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
   aws dynamodb create-table --table-name hotel-booking-tfstate-lock-dev \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST --region ap-south-1
   ```

2. Initialize with the real backend and apply:

   ```bash
   cd infra/envs/dev
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

3. Commit the generated `.terraform.lock.hcl` so provider versions are pinned for everyone.

Replace the placeholder ACM ARN in `infra/envs/prod/terraform.tfvars` with a real certificate before applying prod.

### Module overview

| Module | Creates |
| --- | --- |
| `network` | VPC, public and private subnets across AZs, internet gateway, NAT gateway(s), route tables, and the three security groups with explicit rules |
| `ecs` | ECS cluster, Fargate task definition and service, ALB with target group and listeners, IAM execution and task roles, log group, CPU target-tracking autoscaling |
| `rds` | DB subnet group, parameter group (slow query logging, forced SSL), encrypted PostgreSQL instance with managed master password |

The application image is `nginxinc/nginx-unprivileged`, a placeholder that runs as a non-root user on port 8080. Swap `container_image` for the real service.

## Environments

Each environment is its own root module with its own backend, state, variables and tfvars. They share modules and differ only in values.

| Setting | dev | prod |
| --- | --- | --- |
| State | `hotel-booking-tfstate-dev` | `hotel-booking-tfstate-prod` |
| VPC CIDR | `10.10.0.0/16` | `10.20.0.0/16` |
| Availability zones | 2 | 3 |
| NAT gateways | 1 shared | 1 per AZ |
| Fargate task | 0.25 vCPU / 512 MiB | 1 vCPU / 2 GiB |
| Task count (min / max) | 1 / 2 | 3 / 10 |
| RDS instance class | `db.t4g.micro` | `db.r6g.large` |
| RDS storage (initial / max) | 20 / 50 GiB | 100 / 500 GiB |
| RDS Multi-AZ | no | yes |
| **RDS backup retention** | **3 days** | **14 days** |
| **RDS deletion protection** | **false** | **true** |
| Final snapshot on destroy | skipped | required |
| Performance Insights | off | on |
| ALB deletion protection | off | on |
| HTTPS | HTTP only | HTTPS with HTTP redirect |
| Log retention | 7 days | 90 days |

## CI

**`terraform-plan.yml`** runs on pull requests that touch `infra/`. For both `dev` and `prod` it runs `terraform fmt -check`, `init`, `validate` and `plan`. The plan is published three ways: as a sticky pull request comment (updated on each push), as a downloadable workflow artifact, and in the job summary. Plans run offline with `-backend=false -var plan_only=true`, so the workflow needs no AWS secrets and is safe for forks. To plan against real state, switch it to OIDC role assumption and drop those two flags.

**`database.yml`** runs on changes to `db/`, `scripts/` or the compose file. It lints the scripts with ShellCheck, starts the database, checks the seed volume, then runs `backup.sh`, `restore.sh` and the query plan, failing if the plan does not use an index.

## Design decisions

- **Migrations applied by the init hook and by script.** The Postgres image runs `db/docker-entrypoint/init.sh` on first start, which makes `docker compose up` produce a ready database with no extra step. `migrate.sh` and `seed.sh` apply the same files to an already running database. Because the SQL is idempotent, both paths are safe.
- **Restore verification compares data, not just exit codes.** `pg_restore` can succeed while restoring nothing useful. The manifest fingerprint catches truncated or altered data.
- **Restore never touches the source database.** Drills should not be able to damage what they protect.
- **Private subnets for ECS and RDS, NAT for egress.** Tasks need to pull images and read secrets. Dev uses one NAT gateway to save cost; prod uses one per AZ to remove a single point of failure.
- **Separate `aws_vpc_security_group_*_rule` resources.** Security groups reference each other, and separate rule resources avoid dependency cycles and make every allowed flow a reviewable line in a plan.
- **Deployment circuit breaker with rollback** on the ECS service, and `desired_count` ignored in lifecycle so autoscaling is not fought by Terraform.
- **Managed master password** instead of a `random_password`, which keeps the secret out of Terraform state.

## Known limitations

- The configuration was written for review and plan-only validation. It has not been applied to a real AWS account.
- Container-level tuning (health endpoint, resource limits) is minimal because the workload is a placeholder.
- The local database is a single instance without WAL archiving, so it demonstrates logical backup and restore, not point-in-time recovery. In AWS, RDS automated backups provide PITR within the retention window.
- The S3 backend uses a DynamoDB lock table. On Terraform 1.10 or newer you can switch to `use_lockfile = true` and drop the table.
