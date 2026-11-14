# ServerDeck (Flutter app)

This is the Android app. It talks to the same `server/` API you already set up
on your Ubuntu server (see the main README). Nothing changes on the server.

## Build it on your Windows PC

1. Install Flutter: https://docs.flutter.dev/get-started/install/windows/mobile
   Follow it through "Android setup" (it installs Android Studio and the Android SDK).
   Check with `flutter doctor` that Flutter and Android toolchain have green ticks.

2. Create the project (in a normal folder, e.g. `C:\dev`):

   ```
   flutter create --org com.serverdeck --project-name serverdeck serverdeck_app
   cd serverdeck_app
   flutter pub add http shared_preferences url_launcher
   ```

3. Copy the `main.dart` from this download over `serverdeck_app\lib\main.dart`
   (replace the existing file).

4. Delete the sample test (it refers to code that no longer exists):

   ```
   del test\widget_test.dart
   ```

5. Allow internet access. Open `android\app\src\main\AndroidManifest.xml` and add this
   line just above the `<application` line:

   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```

   (Optional: change `android:label="serverdeck"` to `android:label="ServerDeck"`.)

6. Build the APK:

   ```
   flutter build apk --release
   ```

   The file is `build\app\outputs\flutter-apk\app-release.apk`.
   Copy it to your phone and install it (allow "install unknown apps" if asked).

Quick test on a phone with USB debugging: `flutter run`.

## Using it

- Server address: your Cloudflare Tunnel address, e.g. `https://deck.yourdomain.com`.
- "Home address for Open buttons" is optional. The Open button on a Docker app opens
  `http://<that address>:<port>`. Use your server's LAN IP (e.g. `192.168.1.20`) and it
  works when your phone is on your home Wi-Fi. If left empty, it uses the server address,
  which usually will not work through a tunnel.
- Your role decides what you see: viewers only look; operators and administrators can
  start, stop, restart and update.

## Notes
- Not compiled or tested on a phone yet. If `flutter build` shows an error, paste it to me.
- Update pulls the newest image and restarts. It does not recreate the container.
