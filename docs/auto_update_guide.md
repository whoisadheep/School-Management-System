# Auto-Update System Deployment Guide

This document outlines the steps to build, bundle, and release a new version of the School Management System desktop app using the HTTP + GitHub auto-update system.

## 1. Update Server Setup (Firebase Hosting)

The app checks for updates by fetching a static `version.json` file hosted on Firebase Hosting at:
**`https://sms-updates-hosting.web.app/version.json`**

### `version.json` Structure
Your `version.json` should look like this:
```json
{
  "latest_version": "1.2.0",
  "download_url": "https://github.com/your-repo/releases/download/v1.2.0/SMS_Installer_v1.2.0.exe",
  "changelog": "Bug fixes and performance improvements.",
  "mandatory_update": false
}
```

### One-Time Setup
1. Go to your Firebase project console and enable **Hosting**.
2. Initialize Firebase hosting in a local directory (this can be outside your app directory):
   ```bash
   firebase init hosting
   ```
   *Select the public directory (usually `public`), and choose NO to configuring as a single-page app.*
3. Inside the `public` directory, create `version.json` with the structure above.
4. Deploy the initial version:
   ```bash
   firebase deploy --only hosting
   ```

### How to Redeploy After Editing
Whenever you edit `version.json`, just open a terminal in the folder containing your `firebase.json` and run:
```bash
firebase deploy --only hosting
```

## 2. Compiling the Updater

The `Updater.exe` handles the silent installation of the new app version while the main app is closed.

1. Open your terminal in the project root.
2. Compile the Dart script to a native Windows executable:
   ```bash
   dart compile exe bin/updater.dart -o Updater.exe
   ```

## 3. Bundling the App

When you build your Windows application for distribution, you must include `Updater.exe` in the final build folder (where your `school_management_system.exe` is located).

1. Build the Flutter app:
   ```bash
   flutter build windows
   ```
2. Copy `Updater.exe` into the `build\windows\x64\runner\Release\` directory.
3. Bundle this entire directory using your installer builder (e.g., Inno Setup).
   - *Important*: Ensure your installer is configured to silently replace files and not fail if `Updater.exe` is briefly locked, or instruct it to terminate `Updater.exe` if needed, though `Updater.exe` will close itself after launching the installer.

## 4. Releasing an Update

Whenever you want to ship a new version to your users:

1. Update the `version` in your `pubspec.yaml` (e.g., `version: 1.2.0+2`).
2. Build your app and bundle it into an installer (e.g., `SMS_Installer_v1.2.0.exe`).
3. Create a new **GitHub Release** in your repository.
4. Attach the `SMS_Installer_v1.2.0.exe` to the GitHub Release.
5. Right-click the uploaded asset in GitHub and copy the **direct download link**.
6. Edit your local `version.json` file:
   - Update `latest_version` to your new version (e.g., `1.2.0`).
   - Update `download_url` with the copied GitHub asset link.
   - Update `changelog` and `mandatory_update` fields as needed.
7. Run `firebase deploy --only hosting` to push the updated file live.
8. Confirm the live URL now returns the updated JSON:
   Open `https://sms-updates-hosting.web.app/version.json` in a browser or run:
   ```bash
   curl https://sms-updates-hosting.web.app/version.json
   ```

Users will automatically receive the update prompt within a few hours (based on the cache duration) or on their next fresh app launch!
