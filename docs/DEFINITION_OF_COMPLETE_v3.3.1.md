# JAYEK v3.3.1 — Definition of Complete

This file is the completion contract for the current COD-only pilot.

## The app is considered complete for the pilot when all of these gates are green

1. **Backend**
   - NestJS API builds successfully.
   - Unit/domain/integration/contract tests pass.
   - Database schema and migrations apply cleanly.
   - Health and readiness endpoints pass.
   - Production configuration rejects missing/unsafe required settings.

2. **Customer app**
   - Flutter analyze and tests pass.
   - Debug and release Android APKs build.
   - Customer package is `com.jayek.app`.
   - Login/session handling, address/GPS, merchant/product browsing, single-merchant cart, checkout and COD order creation work against the real API.

3. **Rider app**
   - Flutter analyze and tests pass.
   - Debug and release Android APKs build.
   - Rider package is `com.jayek.rider`.
   - Authentication/refresh, task acceptance, order status progression and GPS location updates work against the real API.

4. **Order lifecycle**
   - Customer creates a COD order.
   - Merchant accepts/prepares it.
   - Rider is assigned and accepts it.
   - Rider picks up and delivers it.
   - COD payment changes from PENDING to PAID only at delivery.
   - Customer can review only an eligible delivered order.
   - Ownership/IDOR checks pass for customer, merchant, rider and admin roles.

5. **Reliability/security**
   - Authorization and malformed-input smoke tests pass.
   - Idempotency and stock reservation tests pass.
   - Security headers are present.
   - OWASP ZAP baseline scan runs in CI.
   - No production secrets/private keys are committed.
   - Refresh-token rotation/revocation is enforced.

6. **Pilot deployment**
   - A reachable API deployment exists.
   - PostgreSQL and Redis are reachable from the API.
   - Customer and Rider apps point to the deployed API URL.
   - Final release APKs are produced and installable on Android.
   - Firebase configuration is present for both apps.

## Explicit pilot scope

- Payment: **Cash on Delivery only**.
- OTP: demo/console mode for the free pilot; real SMS is a later production integration.
- Maps: GPS coordinates/haversine for the pilot; paid routing can be added later.
- Domain: optional for the pilot.
- Hosting: free-tier hosting may be used for testing, but it is not represented as permanent production infrastructure.

## Completion rule

We do not call the project complete merely because code exists or CI compiles. The final completion state requires the automated gates above **plus a real end-to-end pilot run against the deployed API using both Android apps**.

Until those two conditions are satisfied, remaining work is explicitly tracked as a launch blocker rather than silently treated as complete.
