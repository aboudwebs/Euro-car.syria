# EURO CARS — Flutter Android

Native Flutter client (Arabic, RTL, dark and light themes) for the existing EURO CARS platform. It talks to the
current Next.js API (`https://control-panel-euro-cars.onrender.com`) with the signed mobile session token kept in Android secure
storage. It never connects to Supabase directly. The admin role is web only: an admin account cannot sign in here.

## Public privacy and account deletion
- Privacy policy: `https://control-panel-euro-cars.onrender.com/privacy`
- External account deletion: `https://control-panel-euro-cars.onrender.com/delete-account`
- The About screen links to both pages. The external deletion flow verifies phone ownership by SMS and applies the same 30-day deletion process as the app.

## What the app does

| Area | Workshop | Marketer |
|------|----------|----------|
| Sign-in / registration | sign-in; registration waits for admin approval; optional signed referral link | sign-in; registration is instant |
| Catalog | search by name, brand, OEM number (any separators), model, years, branch; brand chips; stock badges | same |
| Cart and orders | quantity limits (stock, 100 per line, 50 lines); cash on delivery, Sham Cash (receipt photo), full/partial cashback and debt ledger (server-checked limit) | cash on delivery and Sham Cash only |
| Orders | status, payment, items and rejection reason; cancel pending orders; Sham Cash refund status; special requests with a photo | same |
| Dashboard | server-authoritative loyalty tier and 90-day season progress, cashback, debt balance and 30-day window, ledger | referral code/share link, workshops, 2% commissions, payout requests and payout history |
| Account | profile photo; currency (USD / SYP using the admin-published rate) and language; account data; saved addresses and vehicles (VIN); active/previous orders, tracking and Sham Cash refund status; in-app notifications for orders, debt, cashback, loyalty and payouts; About EURO; support; sign-out; account deletion | same |
| Catalog extras | sections (categories), VIN search by camera (on-device text reading) or from a saved vehicle | same |
| Sign-in | forgot password by MsgPlus SMS code | same |

The server stays the authority for prices, stock, totals, roles and limits; the app only sends part ids and quantities.

## Layout

```
lib/core      API client, models, cart rules, search, formatting, session store (no Flutter widgets)
lib/state     AppState: one ChangeNotifier for session, catalog, cart, orders, dashboards, profile
lib/theme     palette and ThemeData (dark and light)
lib/widgets   shared inputs, panels, pickers, feedback
lib/screens   auth, home shell, catalog (+ VIN scanner), cart, orders, special request, dashboard, account (+ data, addresses, vehicles, About)
test          unit tests (core + AppState with a scripted server) and widget tests
tool          prepare_android.py, verify_apk.sh, make_icons.py (rebuilds the launcher icons from branding/source)
branding      launcher icons (adaptive + legacy) and launch background copied into the generated Android project;
              source/euro_icon_source.jpg is the logo artwork they are made from
```

## Build

The Android folder is generated, not committed. Run these commands from the repository root with Flutter 3.47 (stable) and JDK 17:

```sh
flutter create --platforms=android --org com.eurocars --project-name euro_cars .
python3 tool/prepare_android.py          # INTERNET permission, label, icons, optional signing
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm,android-arm64
bash tool/verify_apk.sh build/app/outputs/flutter-apk/app-release.apk
```

Use another API with `--dart-define=EURO_API_URL=https://your-api.example.com`.

`prepare_android.py` is needed: Flutter's template only grants the INTERNET permission to debug and profile builds, so
without it a release APK cannot reach the server.

## Continuous integration

`.github/workflows/build-design-apk.yml` runs the steps above on every relevant push to `main` and manually
(Actions → "Build EURO CARS APK (main)" → Run workflow).

* `flutter analyze` and `flutter test` are hard gates. If either fails, the job stops before building the APK.
* The APK is uploaded as the artifact **`euro-cars-main-apk`** (with its `.sha256` and report) only after
  `verify_apk.sh` passed: archive integrity, Android signature, package name, label, INTERNET permission, minSdk,
  exactly the architectures `armeabi-v7a` and `arm64-v8a`, engine and Dart libraries, the bundled font, zip alignment.
* The verification report is uploaded in every run as `euro-cars-apk-verification-report`, and the run summary shows
  the result of each check, so a failure can be read without building again. Artifacts are kept for 14 days.

### Release signing

The CI release workflow requires all four signing secrets and fails closed if any are missing; it never falls back to a debug key.
For local test builds only, omitting `android/key.properties` uses the debug key, which is not acceptable for Play Store uploads.
To sign with the release key, create a keystore and add these repository secrets: `ANDROID_KEYSTORE_BASE64` (`base64 -w0 release.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`. Locally, put `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`)
next to the generated project; keep both files out of git.

## Acceptance test on a phone

Nothing automatic installs and runs the APK, so try this once before handing the app over (the hosted API can take
up to a minute to wake up on the first request):

1. Install the APK (the launcher icon must be the EURO logo: silver "E", gold orbit, "EURO" on the navy tile, in the
   home-screen shape of the phone), open it with the phone online, sign in as a workshop.
2. Catalog: search by name and by an OEM number, open a part, add it to the cart, change the quantity.
3. Order: place one with cash on delivery, one with Sham Cash and a receipt photo, and (if the account has credit) one
   on the debt ledger. Check all of them under "طلباتي".
4. Special request with a photo; dashboard (tier, debt, cashback); account (profile photo, theme, currency, language).
   Also try: add an address and pick it in the cart; add a vehicle with a VIN and search with it; scan a VIN with the
   camera (deny the permission once to see the message); open a section in the catalog; Sham Cash in the cart (barcode,
   copy the address); About EURO (the two icons open Instagram and TikTok); forgot password (requires MsgPlus SMS to be configured on the server). Features that need the database update are listed in `FEATURE_PRESERVATION_CHECKLIST.md` K-12.
5. Close and reopen the app: the session and the cart must still be there. Sign out must clear them.
6. Sign in as a marketer: referral code and share link, workshops, commissions; the debt option must not be offered.
7. Sign in with an admin account: the app must refuse it (admin is web only).

## Notes

* The hosted API sleeps when idle, so reads are retried once and timeouts are generous. Orders are never resent
  automatically after a dropped connection: the app tells the user to check "طلباتي" first.
* The saved session keeps the keys `token` and `user`, so an installed session survives the update.
* `GET` and `PUT /api/auth` only read the session cookie, so those two calls also send `Cookie: euro_session=<token>`.
  Letting the server accept the Bearer token there would be a small backend improvement (not required).
* Fonts: Tajawal (SIL Open Font License, `assets/fonts/OFL.txt`).
