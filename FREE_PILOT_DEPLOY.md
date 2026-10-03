# JAYEK Free Pilot Deployment

## Target
GitHub -> Render Free API/Postgres -> HTTPS -> JAYEK APK.

## Render
1. Sign in to Render and connect GitHub.
2. Create **New -> Blueprint**.
3. Select `ahmedmisbtan-stack/jayek`.
4. Select branch `main`.
5. Review the Blueprint: `jayek-api` (Free Web Service) + `jayek-db` (Free Postgres).
6. Click **Apply**.
7. Wait until the web service is **Live**.
8. Open:
   `https://jayek-api.onrender.com/api/v1/health/ready`
   It should return JSON with `status: ready`.

## Pilot login
The Blueprint is intentionally configured for a test-only OTP:
- Phone: `01000000004`
- OTP: `2468`

Do not use the fixed demo OTP configuration for a public production launch. Replace it with a real OTP provider before production.

## APK
The release workflow defaults to:
`https://jayek-api.onrender.com/api/v1`

After Render is Live, GitHub Actions builds customer and rider release APKs against that HTTPS endpoint.

## Free-tier caveats
Render Free web services sleep after inactivity and can take about a minute to wake. Free Postgres expires after 30 days. This setup is for the pilot/test environment, not permanent production.
