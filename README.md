# Lecture Reminder App

Reads your bell timings + your personal timetable (both fully editable inside
the app — nothing hardcoded) and sends:
- a morning summary of the day's lectures
- a reminder 20 minutes before each lecture ("get ready")
- a reminder 5 minutes before each lecture ("start walking to class")

## What's already done for you
- `lib/` — full app source (models, storage, notification scheduling, 3 screens)
- `pubspec.yaml` — all dependencies listed
- `codemagic.yaml` — cloud build config (no local Android SDK needed)

## What YOU need to do once, to get the `android/` and `ios/` platform folders
Flutter itself has to generate these — they're boilerplate that's specific to
your Flutter version, so it's more reliable than hand-editing them.

**Lightest possible way (Ubuntu, no Android Studio needed for this step):**
```bash
# 1. Download Flutter (just the SDK, ~1GB, no emulator/Android Studio)
cd ~
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$HOME/flutter/bin"

# 2. Go into this project folder and generate platform folders
cd path/to/timetable_reminder
flutter create .

# 3. Sanity check
flutter pub get
```
`flutter create .` will NOT overwrite the `lib/`, `pubspec.yaml`, or
`codemagic.yaml` files you already have — it only adds `android/`, `ios/`,
and a couple of test/config files that were missing.

After this, open `android/app/src/main/AndroidManifest.xml` and add these two
lines inside the `<manifest>` tag (above `<application>`), so scheduled
reminders still fire even if the phone is in doze mode:
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

## Push to GitHub
```bash
git init
git add .
git commit -m "Lecture reminder app"
git branch -M main
git remote add origin https://github.com/<your-username>/timetable-reminder.git
git push -u origin main
```

## Build the APK in the cloud (no local SDK needed)
1. Go to https://codemagic.io and sign up (free tier is enough).
2. Connect your GitHub account and select this repo.
3. Codemagic will detect `codemagic.yaml` automatically — just click **Start
   new build** on the `android-apk` workflow.
4. When it finishes, download the `.apk` from the build artifacts.
5. On your phone: transfer the APK (or download it directly from Codemagic in
   your phone's browser), open it, allow "install from unknown sources" when
   prompted, and install.

## Using the app
1. Open **Bell Timings** → tap **+** → add every row from your bell timing
   sheet (Assembly, Circle Time, 1st Period ... Break ... 9th Period) for
   **Mon-Thu**, then switch "Applies to" and repeat for **Friday**. Mark
   Assembly/Circle Time/Break as "non-teaching period".
2. Open **My Timetable** → tap **+** → for each day, pick the period and type
   in the class (e.g. "NUR-N", "Jr. I C") — exactly like your PDF timetable.
3. Set your preferred **morning summary time** on the home screen.
4. Tap **Sync notifications**. Re-tap it any time you edit something, and at
   least once a week (it schedules 7 days ahead at a time).

## Known limitations (worth knowing)
- If you reboot your phone, scheduled notifications inside the next 7-day
  window are usually preserved by Android, but to be safe, open the app and
  hit "Sync notifications" after any reboot for now.
- Android may ask you to disable battery optimization for this app so it's
  allowed to fire exact alarms reliably — accept that prompt if it appears.
