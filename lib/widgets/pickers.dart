// Pickers and system hand-offs: choice sheet, photo from camera or gallery, opening links, snack bars.

import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/images.dart';
import '../theme/palette.dart';
import 'tx.dart';

void showSnack(BuildContext context, String message) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

/// A bottom sheet with one tappable row per option. Returns the chosen option, or null when dismissed.
Future<T?> showChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T value) labelOf,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      final Palette p = Palette.of(sheetContext);
      final double maxHeight = MediaQuery.of(sheetContext).size.height * 0.7;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  title,
                  style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final T option in options)
                      ListTile(
                        title: Text(labelOf(option)),
                        trailing: option == selected
                            ? Icon(Icons.check_rounded, color: p.primary)
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(option),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Result of asking the user for a photo.
class ImagePickResult {
  const ImagePickResult.cancelled()
      : bytes = null,
        error = null;

  const ImagePickResult.picked(Uint8List this.bytes) : error = null;

  const ImagePickResult.failed(String this.error) : bytes = null;

  final Uint8List? bytes;
  final String? error;
}

/// Asks whether to use the camera or the gallery, then returns the chosen photo. The photo is resized and
/// compressed by the picker, which also converts formats such as HEIC to JPEG.
Future<ImagePickResult> pickPhoto(
  BuildContext context, {
  double maxSide = 1600,
  int quality = 85,
}) async {
  final ImageSource? source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );
  if (source == null) {
    return const ImagePickResult.cancelled();
  }
  try {
    final XFile? file = await ImagePicker().pickImage(
      source: source,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
    );
    if (file == null) {
      return const ImagePickResult.cancelled();
    }
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return const ImagePickResult.failed('تعذر قراءة الصورة. جرّب صورة أخرى.');
    }
    if (bytes.length > maxImageBytes) {
      return const ImagePickResult.failed('حجم الصورة يجب ألا يتجاوز 5 ميغابايت.');
    }
    if (imageExtension(bytes) == null) {
      return const ImagePickResult.failed('صيغة الصورة غير مدعومة (JPG أو PNG أو WebP).');
    }
    return ImagePickResult.picked(bytes);
  } catch (_) {
    return const ImagePickResult.failed(
      'تعذر فتح الكاميرا أو المعرض. تحقق من أذونات التطبيق وحاول مجدداً.',
    );
  }
}

/// Opens a link in the browser or the matching app (for example WhatsApp). Returns false when nothing can open it.
Future<bool> openExternalUrl(String url) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// WhatsApp chat with Euro Parts support, with the same greeting the web app uses.
String supportUrl() {
  return 'https://wa.me/$supportWhatsApp?text=${Uri.encodeComponent(supportMessage)}';
}
