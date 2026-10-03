
> Current release: **JAYEK v3.3.1 — COD-Only Pilot**

# JAYEK Platform — v0.9 Production Security & Reliability

Brand: جايك / JAYEK — "طلبك جايك"

Pilot: الديسمي، مركز الصف، الجيزة. Architecture remains modular monolith first.

## v0.9 additions
- Rotating refresh-token sessions with hashed token storage.
- Logout/revocation endpoint.
- Basic API rate limiting.
- Liveness and database readiness checks.
- Audit log storage and admin audit endpoint.
- PostgreSQL/Redis Docker health checks.
- Backup/restore scripts.
- Production security checklist.

## Run
1. Copy `.env.example` to `.env` and set a strong `JWT_SECRET`.
2. `docker compose -f infra/docker-compose.yml up --build`
3. API: `http://localhost:3000/api/v1/health`
4. Readiness: `http://localhost:3000/api/v1/health/ready`

## Important
Dependencies are declared but may need installation in the target environment. A full build was not claimed here because the current execution environment has no installed `node_modules`.


## v1.1 — External Services Integration Layer

The API now uses provider-neutral adapters for:
- OTP/SMS (`console` or generic HTTP)
- Push notifications (`console` or generic HTTP)
- Maps/routing (`haversine` or generic HTTP)
- Payments (`cod` or generic hosted HTTP + HMAC webhook verification)
- Object storage (`local` or S3-compatible presign bridge)

Local defaults require no third-party credentials. Production/staging examples are under `infra/.env.staging.example` and `infra/.env.production.example`.

Admin endpoint: `GET /api/v1/integrations/status`.

## v1.2 Release Engineering

CI/CD foundations are in `.github/workflows/`. Local/staging checks are available through `infra/scripts/smoke.sh` and `infra/scripts/verify-config.sh`. See `docs/RELEASE_CHECKLIST_v1.2.md` before pilot release.

## v2.1 — Production Launch Readiness
- Hardened production API container with non-root runtime user and healthcheck.
- Production config verification script.
- One-command production deployment helper with readiness wait.
- Release gates for API, Docker, DB, Customer APK, Rider APK, providers, backup/restore, and E2E order lifecycle.
- Production launch guide: `docs/PRODUCTION_LAUNCH_v2.1.md`.


## v3.3.0 verification
- Customer Android package: `com.jayek.app`
- Rider Android package: `com.jayek.rider`
- Backend: NestJS + PostgreSQL + Redis-ready integrations
- COD-only pilot payment path; online payment confirmation is disabled until a real provider is configured.
- Customer address creation uses device GPS.
- Rider location can use device GPS instead of the old demo coordinates.
- CI builds debug and release APKs and runs Flutter analysis/tests.
- Security smoke covers authentication/RBAC, malformed input, IDOR/idempotency replay, payment abuse, order lifecycle, review replay, and security headers.
- OWASP ZAP baseline scanning is included in CI.

## v3.3.1 — COD-only pilot
- Checkout accepts **cash on delivery only**.
- Every new order records a `CASH` payment as `PENDING`.
- A COD payment is marked `PAID` only when the assigned rider marks the order `DELIVERED`.
- Online card/wallet checkout is rejected by the API until a future payment provider is intentionally enabled.
- App checkout displays the COD payment method directly; no online-payment selection is exposed.


## Pilot gate verification
- Latest automated gate target: API build/tests, Customer APK debug+release, Rider APK debug+release, closed-loop gate, authorization/input-abuse smoke, and OWASP ZAP baseline scan.
