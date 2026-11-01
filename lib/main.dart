// EURO CARS - native app for workshops and marketers.

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
    debugPrint('EURO CARS push initialization failed: $error');
  }
  runApp(const EuroApp());
}
