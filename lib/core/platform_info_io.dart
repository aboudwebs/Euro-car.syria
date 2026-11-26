import 'dart:io' show Platform;

/// Preserves the native iOS/Android platform distinction.
bool get isIOS => Platform.isIOS;
