import 'package:firebase_core/firebase_core.dart';

const String _apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
const String _appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
const String _authDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
const String _messagingSenderId = String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
const String _projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
const String _storageBucket = String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');

/// Firebase web configuration is public client metadata, not a server secret.
/// The app remains usable with phone/password when these values have not been supplied yet.
Future<void> initializeFirebaseWebIfConfigured() async {
  if (Firebase.apps.isNotEmpty) return;
  final values = <String>[
    _apiKey,
    _appId,
    _authDomain,
    _messagingSenderId,
    _projectId,
    _storageBucket,
  ];
  if (values.any((value) => value.trim().isEmpty)) return;

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      authDomain: _authDomain,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      storageBucket: _storageBucket,
    ),
  );
}
