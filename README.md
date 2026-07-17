# Ultra Coach Matrix Flutter App

Student/parent mobile frontend for Ultra Coach Matrix.

## Production Defaults

- Default API: `https://ultracoachmatrix.in`
- Override API at build time with `--dart-define=API_BASE_URL=https://your-domain`
- Debug builds use local Django first, then production as a fallback.
- Firebase web push VAPID key can be provided with `--dart-define=FIREBASE_WEB_VAPID_KEY=...`
- Android release builds do not allow cleartext HTTP traffic.
- Android release signing is read from `android/key.properties`.

## Local Django Testing

Start Django from `BackEnd/UltraCoachMatrix`:

```powershell
python manage.py runserver 0.0.0.0:8000
```

Then run Flutter from `FrontEnd/ultracoachmatrix`:

```powershell
flutter run
```

Debug defaults:

- Android emulator: `http://10.0.2.2:8000`
- Flutter web, Windows, macOS, Linux, and iOS simulator: `http://127.0.0.1:8000`

To force a specific local backend:

```powershell
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
flutter run --dart-define=API_BASE_URL=http://YOUR-LAN-IP:8000
```

For a physical phone, replace `YOUR-LAN-IP` with your computer IP, for example
`http://192.168.1.10:8000`, and add that IP to Django's `DJANGO_ALLOWED_HOSTS`
in `BackEnd/UltraCoachMatrix/.env`.

To try multiple hosts in order:

```powershell
flutter run --dart-define=API_BASE_URLS=http://127.0.0.1:8000,http://10.0.2.2:8000,https://ultracoachmatrix.in
```

## Android Release Signing

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Set the real keystore path, passwords, and key alias.
3. Keep `android/key.properties` out of source control.

Example:

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://ultracoachmatrix.in
```

For APK testing:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://ultracoachmatrix.in
```

## Quality Checks

Run these before shipping:

```powershell
flutter analyze
flutter test
```
