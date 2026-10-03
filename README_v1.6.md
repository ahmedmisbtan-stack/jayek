# JAYEK v1.6

Customer-facing Flutter release focused on the real pilot path: login → browse → cart → address → coupon → COD order → tracking → review/reorder.

Run locally:

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter run --dart-define=JAYEK_API=http://10.0.2.2:3000/api/v1
```

For a physical Android device, use the API host reachable from the device instead of `10.0.2.2`.
