// Euro Parts - native app for workshops and marketers.

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/push_notifications.dart';

export 'app.dart' show EuroApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await PushNotifications.initialize();
  } catch (error) {
    // Push is optional; Firebase setup must never prevent sign-in or offline app use.
    debugPrint('Euro Parts push initialization failed: $error');
  }
  await _activateAppCheck();
  runApp(const EuroApp());
}

/// Firebase App Check, MONITOR ONLY: it lets the Firebase Console show how many requests come from a genuine app
/// (Play Integrity in release; the debug provider, which logs a debug token, in debug builds).
///
/// Enforcement must stay OFF in the Firebase Console until Play Integrity / the SHA-256 fingerprints are configured
/// there and the Console's metrics show that real traffic is verified; enforcing earlier would lock users out of
/// Firebase Authentication and Cloud Messaging. The app does not send App Check tokens to the EURO server and
/// nothing here depends on the result: a failure (or a slow answer) must never block app start.
Future<void> _activateAppCheck() async {
  try {
    if (Firebase.apps.isEmpty) {
      return; // Firebase is not configured on this device (push setup failed): nothing to attest.
    }
    await FirebaseAppCheck.instance
        .activate(
          providerAndroid: kReleaseMode ? const AndroidPlayIntegrityProvider() : const AndroidDebugProvider(),
        )
        .timeout(const Duration(seconds: 5));
  } catch (error) {
    debugPrint('Euro Parts App Check activation failed: $error');
  }
}
