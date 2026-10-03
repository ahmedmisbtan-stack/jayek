# JAYEK Security / Reliability v0.9

- Bearer access tokens are short-lived; refresh tokens are random, hashed at rest, rotated and revocable.
- `ALLOW_DEV_HEADERS=true` must never be enabled in production.
- Set a strong random `JWT_SECRET` in production.
- API has a bounded in-memory rate limiter; use a shared Redis-backed limiter when horizontally scaling.
- Audit logs capture authentication refresh/logout and can be extended to order/admin mutations.
- `/api/v1/health` is liveness; `/api/v1/health/ready` verifies PostgreSQL readiness.
- `infra/backup.sh` creates PostgreSQL custom-format backups. Store backups outside the application host and encrypt them according to deployment policy.
- `infra/restore.sh` restores a backup into the configured database; test restores regularly in a staging environment.
- External SMS, maps, payment and push providers must receive secrets through the deployment secret manager, not source control.
