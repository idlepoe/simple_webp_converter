# GitHub release setup

CI runs static analysis and a debug APK build for pull requests and pushes to
`main` or `master`. It can also be started from the Actions page. Functional
testing remains on physical devices; workflows do not run automated tests.

Pushing a stable version tag such as `v1.0.0` builds a signed universal APK,
creates a GitHub Release with generated notes, and attaches the APK and its
SHA-256 checksum. Flutter 3.41.9 and JDK 21 are fixed in both workflows.

## One-time signing setup

Use the same release keystore for every version. Back it up securely. If an APK
has already been distributed, use its original signing key to support upgrades.

In the repository, open **Settings > Secrets and variables > Actions** and add:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded existing release keystore, without line breaks |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_STORE_PASSWORD` | Keystore password |

Encode the keystore locally in PowerShell (replace the example path):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\secure\release.jks')) | Set-Clipboard
```

Paste directly into the secret field and clear the clipboard afterward. Do not
commit the keystore, its Base64 value, passwords, or `android/key.properties`.
CI reads signing values from environment variables and fails if secrets are missing.
Local builds continue to support the existing `android/key.properties` file.

## Publish a version

1. Finish physical-device verification.
2. Update `pubspec.yaml`, for example `version: 1.0.1+2`. Increase the build
   number (`versionCode`) for every release; do not reuse or lower it.
3. Commit and push the changes, including the workflows and `pubspec.lock`.
4. Push the matching tag:

```powershell
git tag -a v1.0.1 -m "VidToWebp 1.0.1"
git push origin v1.0.1
```

The tag must exactly match the version name in `pubspec.yaml`. Publication is
automatic after a successful build. The workflow token needs `contents: write`;
repository or organization policy must allow it. No personal access token is needed.

For a failed run, correct the cause and rerun the failed job from Actions. If a
release was already published, publish the next version instead of replacing it.
Downloading a GitHub Release APK does not automatically update installed apps.
