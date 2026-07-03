# todo_app

Personal task manager with NLP input, Google Calendar sync, and push notifications.

## Setup

This repo does not include real Firebase/Google credentials — they're gitignored.
Before running the app:

1. Create a Firebase project (or use an existing one) with Firestore, Auth (Anonymous
   sign-in enabled), and Cloud Messaging turned on.
2. Generate your config:
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This writes `lib/firebase_options.dart` and `android/app/google-services.json`
   (see the `.example` versions of these files for the expected shape if you'd
   rather fill them in by hand).
3. Deploy the Firestore rules and indexes in this repo:
   ```
   firebase deploy --only firestore:rules,firestore:indexes
   ```
4. (Optional) Deploy the scheduled notification functions in `functions/`:
   ```
   firebase deploy --only functions
   ```
5. `flutter pub get`, then run the app.

Google Calendar sync uses Google Sign-In — no extra client secret file is needed.
