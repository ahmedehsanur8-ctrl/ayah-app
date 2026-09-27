# App signing

Every release APK is signed with one permanent key, so each new version installs
over the old one. **Android only accepts an update if it is signed with the same
key. If the key is lost, users must uninstall the app to get updates, and you
cannot update a Play Store app that uses it as its signing key.**

## The key

| Item | Value |
| --- | --- |
| File | `ayah-reminder-release.jks` (PKCS12 keystore) |
| Key alias | `ayahreminder` |
| Algorithm | RSA 4096, valid until 2054 |
| Certificate SHA-256 | `8B:04:27:E4:2E:FC:7E:8D:19:DD:41:E3:29:52:64:E3:42:52:08:5B:58:C2:23:94:7E:62:44:8D:BB:44:EC:2A` |

The keystore file and its password are **not** in this repository. The build
reads them from four GitHub Secrets:

| Secret name | What goes in it |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the whole content of `keystore-base64.txt` (the keystore, base64-encoded) |
| `ANDROID_KEYSTORE_PASSWORD` | the password from `password.txt` |
| `ANDROID_KEY_ALIAS` | `ayahreminder` |
| `ANDROID_KEY_PASSWORD` | the same password from `password.txt` |

The build (`.github/workflows/build-apk.yml`) fails if a secret is missing, and
checks with `apksigner verify` that the APK is signed (v1, v2 and v3 schemes; v1 is needed by some phone installers such as Oppo/Realme,
v2/v3 by Android 7.0+) with
the certificate whose SHA-256 is in `android/release-signing-sha256.txt`.
Only then is the APK published.

## Backing up the key

Keep **two** copies of `ayah-reminder-release.jks` together with `password.txt`, in
two different places, for example:

1. A password manager (Bitwarden, 1Password, Google Password Manager note):
   store the password, and attach the `.jks` file if it allows attachments.
2. A private cloud folder (Google Drive / OneDrive) **and** a USB drive.

Never put the `.jks` file or the password in this repository, in email to others,
or in chat groups. Anyone with both can sign fake updates of your app.

## Google Play later

When you publish on Google Play, choose **Play App Signing**. You can either
upload this key as your app signing key (then Play updates and APK updates share
one key), or let Google create the app signing key and use this key as your
**upload key**. Either way, keep this backup.
