# Building BedLock into an IPA via GitHub

Since Screen Time restriction actually shipping on a real phone requires Apple's
**Family Controls** entitlement — which only works on a build signed with your
own paid ($99/yr) Apple Developer account and Team ID — there's no shortcut
here. This guide gets you from "code on GitHub" to "signed .ipa in hand" using
GitHub Actions' macOS runners (which include Xcode), so you don't need a Mac.

## 0. Prerequisites (do these once, in your Apple Developer account)

1. Enroll in the **Apple Developer Program** if you haven't (developer.apple.com/programs).
2. Request the **Family Controls (Distribution) capability**: https://developer.apple.com/contact/request/family-controls-distribution — this can take a few days, start it first.
3. In **Certificates, Identifiers & Profiles**:
   - Create an **App ID** for the main app (e.g. `com.yourname.bedlock`) with the **App Groups** and **Family Controls** capabilities turned on.
   - Create a second **App ID** for the extension (e.g. `com.yourname.bedlock.BedLockMonitor`) with **App Groups** turned on.
   - Create an **App Group** (e.g. `group.com.yourname.bedlock`) and add it to both App IDs.
   - Create/download an **iOS Distribution certificate** (or Development certificate — see note on export method below) and export it from Keychain Access as a `.p12` file with a password.
   - Register your iPhone's UDID as a device, then create two **provisioning profiles** (one per App ID above) that include that device, and download both `.mobileprovision` files.

## 1. Push this project to GitHub

From the folder containing this project (the one with `BedLock.xcodeproj` in it):

```bash
git init                      # skip if already a repo
git add .
git commit -m "Initial BedLock project"
```

Create a new repo on github.com (leave it empty, no README/license), then:

```bash
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

(If you use GitHub CLI instead: `gh repo create <name> --private --source=. --push`.)

## 2. Add signing secrets to the repo

In your GitHub repo: **Settings → Secrets and variables → Actions → New repository secret.** Add each of these:

| Secret name | Value |
|---|---|
| `TEAM_ID` | Your 10-character Apple Team ID (Membership page on developer.apple.com) |
| `APP_BUNDLE_ID` | e.g. `com.yourname.bedlock` |
| `EXT_BUNDLE_ID` | e.g. `com.yourname.bedlock.BedLockMonitor` |
| `APP_GROUP_ID` | e.g. `group.com.yourname.bedlock` |
| `BUILD_CERTIFICATE_BASE64` | `base64 -i YourCert.p12 \| pbcopy` (paste the result) |
| `P12_PASSWORD` | The password you set when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Any random password — used only to protect the temporary CI keychain |
| `APP_PROVISION_PROFILE_BASE64` | `base64 -i AppProfile.mobileprovision \| pbcopy` |
| `EXT_PROVISION_PROFILE_BASE64` | `base64 -i ExtProfile.mobileprovision \| pbcopy` |

(On macOS, `base64 -i file \| pbcopy` copies the encoded text straight to your clipboard so you can paste it into the GitHub secret field. On Linux, use `base64 -w0 file`.)

## 3. Run the build

The workflow at `.github/workflows/build-ipa.yml` is set to run manually so a
build only happens (and only touches your signing secrets) when you ask it to:

1. Go to your repo's **Actions** tab.
2. Click **Build BedLock IPA** in the left sidebar → **Run workflow** → **Run workflow**.
3. Wait for it to finish (5-10 minutes). Open the completed run and download the **BedLock-ipa** artifact — it's a zip containing `BedLock.ipa`.

## 4. Install the IPA on your phone

The exported IPA is signed **ad-hoc**, meaning it already trusts your specific
device's UDID (since that's baked into the provisioning profile) — most
sideloading tools can install it as-is:

- **Sideloadly** (Windows/Mac): plug in your phone, drag the `.ipa` in, sign in with your Apple ID if prompted, install.
- **AltStore / AltStore PAL**: add the IPA, install through the AltStore app.
- **Xcode itself**: Window → Devices and Simulators → your iPhone → drag the `.ipa` into the Installed Apps list.

Ad-hoc/development-signed apps installed this way still expire after **7 days**
(free-tier signing) unless installed via a paid-account ad-hoc profile, in
which case they last until the provisioning profile expires (up to a year) —
you'll need to reinstall periodically either way.

### If you'd rather use a Development profile instead of Ad Hoc
Some sideloading tools work more smoothly with `method = development` in the
export step. Open `.github/workflows/build-ipa.yml` and change:
```
<key>method</key>
<string>ad-hoc</string>
```
to
```
<key>method</key>
<string>development</string>
```
and use a Development certificate/profile pair instead of Distribution ones
in the secrets above.

## 5. After installing: trust the developer certificate

On your iPhone: **Settings → General → VPN & Device Management** → tap your
Apple ID / developer profile → **Trust**. Without this the app will refuse to
launch ("Untrusted Developer").

## Troubleshooting

- **"No profiles for 'com.yourname.bedlock' were found"** — the bundle ID in the secret doesn't exactly match the App ID the profile was created for, or the profile expired/wasn't regenerated after adding a capability.
- **Family Controls errors at runtime** — the capability request in step 0.2 hasn't been approved yet by Apple; this is an account-level approval, not something CI or code can work around.
- **Build fails at "Configure bundle identifiers"** — check that all five ID/team secrets are set; the sed commands are no-ops (and later steps fail) if they're empty.
