# Android app, cloud saves and the Play Store

The game code is ready for all of this. Cloud saves switch on by themselves once Firebase is set up.
Until then everything works exactly as before, saving on the device.
These are the steps only you can do, because they need your Google account and your computer.
Work through them in order; the whole thing takes about an hour the first time.

## 1. Tools (once)

1. **Update Flutter**: `flutter upgrade`. The Firebase packages need a recent Flutter.
2. **Android Studio**: install it from developer.android.com/studio. Open it once and let it install the
   Android SDK. Then run `flutter doctor --android-licenses` (answer `y` to each) and `flutter doctor`.
   The Android line should be green.
3. **Node.js** (LTS) from nodejs.org, then in a terminal:
   ```
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   ```

## 2. Add the Android app

In `C:\scorchedknight`, double-click **`tool\setup_android.bat`** (or run it in a terminal). It:

- creates the `android` folder;
- sets the app name, icon and dark launch screen;
- turns on internet access for cloud saves and sets Android 7.0 as the minimum;
- adds release signing.

To try it, plug in an Android phone with USB debugging on (or start an emulator from Android Studio)
and run `flutter run`.

> The app's ID is `com.scorchedknight.scorchedknight`. Once it's on the Play Store it can never change,
> so if you want a different one, change `--org` in `tool\setup_android.bat` before the first run.

## 3. Create the Firebase project

1. Go to **console.firebase.google.com**, then **Add project**. Name it `Scorched Knight`.
   Google Analytics is optional; you can switch it off.
2. **Build → Authentication → Get started → Sign-in method → Google → Enable**.
   Pick your email as the support email, then **Save**.
3. **Build → Firestore Database → Create database**. Pick the location `europe-west2 (London)` and
   **Start in production mode**.
4. Open the **Rules** tab, replace everything with the contents of **`firestore.rules`** from the game
   folder, then **Publish**. This lets each player read and write only their own save.

## 4. Connect the game to Firebase

In `C:\scorchedknight`, run:

```
flutterfire configure
```

Choose the Scorched Knight project. When it asks for platforms, choose **android** and **web**.
It does three things:

- writes the real `lib\firebase_options.dart`, replacing the stand-in that keeps cloud saves off;
- adds `android\app\google-services.json`;
- adds Google's Gradle plugin to the Android build.

That's the code side finished.

## 5. Let Android sign in with Google (the SHA fingerprints)

Google sign-in on Android only works for app builds whose signing key Firebase knows.

1. Get your debug key's fingerprints:
   ```
   cd android
   .\gradlew signingReport
   ```
   Find the `Variant: debug` block and copy its **SHA1** and **SHA-256**.
2. In Firebase, open **Project settings** (the cog), go to the Android app, click **Add fingerprint**,
   and paste both.
3. Run `flutterfire configure` again, so `google-services.json` picks up the change.

Do the same later for your release key (step 7) and for Google Play's own signing key. You'll find
Google Play's key in Play Console under **Test and release → App integrity → App signing**.

## 6. Try it

1. In the browser, start the game as usual (`run_web.bat`). Open **Settings (cog) → Sign in with Google**.
   It should say "Signed in as …".
2. On the phone, run `flutter run`, open Settings and sign in with the same Google account.
   Your hero comes across. If both devices have progress, the game asks which hero to keep.

How saves move:

- Saves go up at most every 20 seconds while you play.
- They also go up straight away when the app or tab is put away.
- The newer save wins when you sign in. If the cloud's save is newer and this device also has
  progress, you choose which to keep.

On the web, `localhost` is already allowed for sign-in. When you put the game on a real website,
add that domain under **Authentication → Settings → Authorized domains**.

## 7. The Play Store

1. **Make your upload key** (once; keep the file and passwords safe, you can't replace them easily):
   ```
   keytool -genkey -v -keystore C:\keys\scorchedknight-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. **Create `android\key.properties`**. It's ignored by git, so never commit it.
   ```
   storePassword=your-store-password
   keyPassword=your-key-password
   keyAlias=upload
   storeFile=C:/keys/scorchedknight-upload.jks
   ```
3. Add this key's SHA-1 and SHA-256 to Firebase, as in step 5. `gradlew signingReport` lists it
   under `Variant: release`.
4. **Build**: `flutter build appbundle`. The file is
   `build\app\outputs\bundle\release\app-release.aab`.
   Before each new upload, raise `version:` in `pubspec.yaml` (e.g. `0.1.0+1` to `0.1.1+2`). The
   number after `+` must always go up.
5. **Play Console** (play.google.com/console; one-off $25):
   - Create the app.
   - Fill in the store listing and content rating.
   - Add a privacy policy link. It needs to say that you store a game save and the Google account
     ID it belongs to.
   - Upload the `.aab` to **Closed testing**.
6. **The 12-tester rule**: new personal accounts need at least 12 testers opted in to the closed test
   for 14 days in a row before you can apply for production access. Invite friends early.

## 8. (Optional) Put the web version online with Firebase Hosting

```
flutter build web --release
firebase deploy --only hosting
```

`firebase.json` is already set up to serve `build\web`. The first time, run `firebase use --add` and
pick the project. You get a free `https://<project>.web.app` link that anyone can play on, phone or
desktop, and it installs to the home screen like an app.

If `flutterfire configure` ever rewrites `firebase.json`, make sure the `hosting` and `firestore`
sections are still there.
