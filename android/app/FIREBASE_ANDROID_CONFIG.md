# Firebase Android Configuration

The Android app uses `google-services.json` at build time. This file must come
from the same Firebase project as the backend service-account JSON.

Current production Firebase project:

```text
push-notification-ucm-producti
```

Required Firebase Android package name:

```text
ultracoachmatrix.in
```

When changing Firebase projects:

1. Open the production Firebase project.
2. Add/open the Android app for `ultracoachmatrix.in`.
3. Download the Android `google-services.json`.
4. Replace `FrontEnd/ultracoachmatrix/android/app/google-services.json`.
5. Rebuild and reinstall the APK.
6. Log in again so the app registers a fresh FCM token for this project.

Do not use the backend service-account JSON here. The Android app needs the
public Android `google-services.json` only.
