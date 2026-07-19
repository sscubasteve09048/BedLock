# Sideloading BedLock for free (no Mac, no paid Developer account)

This is the no-cost, no-Mac path: GitHub builds an unsigned IPA for you, and
a free tool on your own computer (Windows or Mac) signs it with your regular
Apple ID and installs it straight onto your phone over USB.

## 1. Run the build on GitHub

1. Go to your repo on github.com → **Actions** tab.
2. In the left sidebar, click **Build Unsigned IPA (for Sideloadly / AltStore)**.
3. Click **Run workflow** → **Run workflow** (green button).
4. Wait for the run to finish (a few minutes) — green checkmark means it worked.
5. Open the completed run, scroll to **Artifacts**, and download **BedLock-unsigned-ipa**. Unzip it — you'll get `BedLock-unsigned.ipa`.

If this step fails on the "Archive without code signing" job, it's most
likely the `BedLockMonitor` extension target refusing to build without any
signing at all. Let me know and I'll adjust the workflow to build just the
main app target and skip embedding the extension — you'd lose the
auto-scheduling piece (which needs the paid entitlement anyway per
`FREE_LOCKING.md`) but keep everything else.

## 2. Install Sideloadly

Download it free from **sideloadly.io** (Windows and Mac both supported).
No Xcode, no Mac required for this — plain Windows works fine.

1. Install and open Sideloadly.
2. Plug your iPhone into your computer via USB/cable, unlock it, and tap
   **Trust This Computer** if prompted.
3. Sideloadly should detect your device in its device dropdown at the top.

## 3. Sign in with your Apple ID

Sideloadly needs your Apple ID to generate a **free, personal-team**
signing certificate — this is the same mechanism Xcode uses under the hood,
just without needing Xcode installed.

- If your Apple ID has two-factor authentication on (it should), generate an
  **app-specific password** at appleid.apple.com → Sign-In and Security →
  App-Specific Passwords, and use that instead of your normal password when
  Sideloadly asks.
- Your Apple ID and password/app-specific password are used locally by
  Sideloadly to talk to Apple's developer services directly — they aren't
  sent anywhere else.

## 4. Sideload the IPA

1. Drag `BedLock-unsigned.ipa` into Sideloadly's main window (or click the
   IPA file field and browse to it).
2. Make sure your Apple ID is selected below it.
3. Click **Start**.
4. Sideloadly signs the app with a fresh personal-team certificate and
   installs it. First install may take a minute or two.

## 5. Trust the developer certificate on your phone

**Settings → General → VPN & Device Management** → tap your Apple ID entry →
**Trust**. Without this step, opening the app shows "Untrusted Developer" and
refuses to launch.

## 6. What to expect

- **Camera verification, Vision-based bed detection, History, notifications,
  and the Siri/Shortcuts "Verify My Bed Is Made" intent** all work exactly as
  designed — none of that needs anything beyond a free Apple ID.
- **The automatic Screen Time shield does not work** on a free personal-team
  build — Family Controls requires Apple's paid-program approval regardless
  of how the app is signed. Use the native Screen Time Downtime approach in
  `FREE_LOCKING.md` instead for the actual "locking" behavior; BedLock
  becomes the verification/trigger app that you invoke via Siri or the
  Shortcuts app once Downtime is active.
- **The app expires after 7 days.** This is an Apple limit on free
  personal-team signing, not something Sideloadly or this project can change.
  Sideloadly has a built-in **auto-refresh** option (toggle it on before
  installing) that will silently re-sign and refresh the app in the
  background before it expires, as long as Sideloadly is running and your
  phone is connected periodically — or you can just re-run steps 4-5 every
  week manually.

## Troubleshooting

- **"Unable to install" in Sideloadly** — usually an expired/duplicate
  provisioning profile from a previous install attempt. In Sideloadly, use
  the wrench/tools icon → "Manage Certificates/Apps" to clear old ones, or
  delete the app from your phone first and reinstall.
- **App crashes immediately on launch** — double check you completed step 5
  (trusting the developer certificate); this is the most common cause.
- **Apple ID sign-in fails in Sideloadly** — make sure you're using an
  app-specific password if 2FA is on; your regular Apple ID password won't
  work for third-party tools once 2FA is enabled.
- **Only 3 free apps allowed at once** — Apple caps free personal-team
  accounts to a small number of concurrently-signed apps/App IDs
  (historically 3, tied to certificates, not app count exactly). If
  Sideloadly complains about hitting a limit, remove another sideloaded app
  or revoke certificates via Sideloadly's certificate manager.
