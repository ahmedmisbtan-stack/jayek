# بيّنات — Android Native

مشروع مستقل لتطبيق **بيّنات** باستخدام Kotlin وJetpack Compose.

- Application ID: `com.bayynat.app`
- Android minimum: 8.0 (API 26)
- Compile/Target SDK: 35
- JDK: 17
- UI: Jetpack Compose + Material 3
- Palette: gold orange `#D99A32`, dark green `#176B55`, warm ivory `#FFF5E5`

## Build locally
Open this directory as a Gradle project in Android Studio, or run:
`gradle :app:assembleDebug`

## Current foundation
Arabic RTL-ready Compose shell, bottom navigation, home dashboard, Quran section placeholder, prayer-times placeholder, and interactive tasbeeh counter.

## Production work still required
The current commit is a buildable UI foundation, not a finished religious-content application. Before release:
1. Integrate verified Quran text and metadata with required attribution/license.
2. Implement local prayer-time calculation from device coordinates and configurable calculation method; validate Egypt defaults.
3. Implement prayer notifications/audio with Android runtime permissions and exact-alarm/background limitations handled correctly.
4. Implement Qibla direction using location and device sensors, including calibration and sensor-availability handling.
5. Add sourced azkar and the complete Asma Allah al-Husna dataset with references.
6. Add Hijri conversion and user-adjustable day offset.
7. Add persistence, accessibility, tests, app icon, privacy policy, and release signing.

No secret keys are required for this foundation.
