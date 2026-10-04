# JAYEK — Rural Food Delivery Platform

> **جايك — طلبك جايك**  
> A modular food-delivery platform built for a rural pilot in Al-Saff, Giza, Egypt.

![Status](https://img.shields.io/badge/status-pilot-0F766E)
![Payment](https://img.shields.io/badge/payment-COD%20only-0F766E)
![Backend](https://img.shields.io/badge/backend-NestJS-0F172A)
![Database](https://img.shields.io/badge/database-PostgreSQL-0F172A)
![Mobile](https://img.shields.io/badge/mobile-Flutter-06B6D4)

## Project snapshot

JAYEK is a full-stack delivery platform designed around a practical pilot workflow:

**Customer → Restaurant → Rider → Delivery → Cash collection**

The current pilot uses **Cash on Delivery (COD)**. Online payments are intentionally disabled until a real payment provider is configured.

### What is included

- Customer mobile application
- Rider mobile application
- NestJS API
- PostgreSQL data layer
- Provider-neutral integrations for OTP, push notifications, maps, payments, and storage
- Authentication, refresh-token sessions, RBAC, rate limiting, audit logging
- Order lifecycle and COD payment state management
- Health/readiness checks
- Docker-based local and production-oriented infrastructure
- CI checks, Flutter analysis/tests, security smoke tests, and OWASP ZAP baseline scanning

## Technology

| Area | Stack |
|---|---|
| Mobile | Flutter / Dart |
| API | NestJS / TypeScript |
| Database | PostgreSQL |
| Infrastructure | Docker / Docker Compose |
| Integrations | Provider-neutral adapters |
| Security | RBAC, token revocation, rate limiting, validation, audit logs |
| Quality | CI, automated tests, smoke checks, OWASP ZAP |

## Run locally

1. Copy the example environment file:

```bash
cp .env.example .env
```

2. Configure a strong `JWT_SECRET`.
3. Start the local stack:

```bash
docker compose -f infra/docker-compose.yml up --build
```

4. Check the API:

```text
http://localhost:3000/api/v1/health
http://localhost:3000/api/v1/health/ready
```

> Dependencies are intentionally not committed to the repository. Install/build them in the target environment.

## Pilot payment model

The current release is **COD-only**:

- New orders record a cash payment as `PENDING`.
- The payment becomes `PAID` when the assigned rider marks the order `DELIVERED`.
- Online card/wallet checkout remains disabled until a production provider is intentionally enabled.

## Engineering focus

This repository is also a useful foundation for operational analytics. Future analysis work can use delivery/order data to study:

- Order volume and growth
- Average delivery time
- Cancellation rate
- Rider performance
- Restaurant performance
- Customer retention
- COD collection performance
- Geographic demand patterns

No analytics results are claimed here unless they are produced from actual project data.

## Repository structure

```text
apps/
  api/              # NestJS backend
  customer/         # Customer Flutter app
  rider/            # Rider Flutter app
infra/              # Docker, schema and deployment configuration
docs/               # Release and production documentation
tools/              # Verification and closed-loop checks
.github/workflows/  # CI/CD workflows
```

## Portfolio direction

The repository represents a real software-engineering project while my professional direction is expanding toward **Data Analysis**.

Current learning path:

**Excel → SQL → Power BI → Python/Pandas → Statistics → Portfolio Projects**

The goal is to turn real business questions into clean analysis, KPIs, dashboards, and actionable insights.

## Security

Before running a production deployment:

- Never commit real secrets or production environment files.
- Use the provided example configuration files.
- Generate production secrets outside Git.
- Review the production launch checklist in `docs/`.

## Status

**JAYEK v3.3.1 — COD-only pilot**

This repository is presented as a public portfolio/project repository. Production credentials, private environment files, and runtime dependencies are not part of the repository.

---

### Visual identity

**Navy** `#0F172A` · **Teal** `#0F766E` · **Cyan** `#06B6D4` · **Slate** `#334155`

Built with a practical, data-aware engineering mindset.
