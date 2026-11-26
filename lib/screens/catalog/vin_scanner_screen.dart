// VIN scanner: photograph the chassis number (windscreen plate, door pillar or registration card), read it on the
// device, show it, let the user correct it, and hand it back to the caller (the catalog search or the vehicle form).
//
// * The camera is opened only when the user taps the button: the system asks for permission at that moment (if the
//   device needs it) and not when the app starts.
// * The number is never sent anywhere by this screen. It is shown first, can be edited by hand, and is only used when
//   the user confirms it.
// * A number that is not 17 characters long is NOT rejected: older cars and some makes have other numbers. The screen
//   only says what it looks like (see lib/core/vin.dart).

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/vin.dart';
import '../../core/vin_ocr.dart';
import '../../theme/palette.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';
import '../../widgets/tx.dart';

/// Opens the scanner and returns the number the user confirmed, or null when they left without confirming.
Future<String?> scanVin(
  BuildContext context, {
  String confirmLabel = 'استخدام هذا الرقم',
  VinTextReader reader = const MlKitVinTextReader(),
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      builder: (BuildContext routeContext) => VinScannerScreen(confirmLabel: confirmLabel, reader: reader),
    ),
  );
}

enum _Stage { start, reading, result }

const String cameraDeniedMessage =
    'لم يُمنح إذن الكاميرا. فعّله من إعدادات التطبيق في هاتفك ثم أعد المحاولة، أو اكتب الرقم يدوياً.';
const String cameraFailedMessage = 'تعذر فتح الكاميرا. جرّب اختيار صورة من المعرض أو اكتب الرقم يدوياً.';
const String ocrFailedMessage =
    'تعذرت قراءة النص من الصورة. أعد التصوير بإضاءة أفضل وبشكل أقرب، أو اكتب الرقم يدوياً.';
const String noVinFoundMessage =
    'لم نجد رقم شاصي واضحاً في الصورة. أعد التصوير بإضاءة أفضل وقرّب الكاميرا من الرقم، أو اكتبه يدوياً.';
const String partialVinMessage =
    'لم نجد رقماً كاملاً من 17 خانة. هذا أقرب نص قرأناه، صحّحه يدوياً قبل المتابعة.';

class VinScannerScreen extends StatefulWidget {
  const VinScannerScreen({
    super.key,
    required this.confirmLabel,
    this.reader = const MlKitVinTextReader(),
    this.picker,
  });

  final String confirmLabel;
  final VinTextReader reader;

  /// Replaced in tests; defaults to the system camera / gallery.
  final Future<XFile?> Function(ImageSource source)? picker;

  @override
  State<VinScannerScreen> createState() => _VinScannerScreenState();
}

class _VinScannerScreenState extends State<VinScannerScreen> {
  final TextEditingController _vin = TextEditingController();
  _Stage _stage = _Stage.start;
  List<VinCandidate> _candidates = const <VinCandidate>[];
  String? _message;
  NoticeKind _messageKind = NoticeKind.error;

  @override
  void dispose() {
    _vin.dispose();
    super.dispose();
  }

  Future<XFile?> _pick(ImageSource source) {
    final Future<XFile?> Function(ImageSource source)? custom = widget.picker;
    if (custom != null) {
      return custom(source);
    }
    return ImagePicker().pickImage(source: source, maxWidth: 2400, maxHeight: 2400, imageQuality: 92);
  }

  Future<void> _capture(ImageSource source) async {
    setState(() => _message = null);
    final XFile? file;
    try {
      file = await _pick(source);
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      final bool denied = error.code.contains('denied') || error.code.contains('restricted');
      setState(() {
        _messageKind = NoticeKind.error;
        _message = denied ? cameraDeniedMessage : cameraFailedMessage;
      });
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messageKind = NoticeKind.error;
        _message = cameraFailedMessage;
      });
      return;
    }
    if (file == null || !mounted) {
      return; // cancelled
    }
    setState(() => _stage = _Stage.reading);

    final List<String> lines;
    try {
      lines = await widget.reader.readLines(file.path);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _stage = _Stage.start;
        _messageKind = NoticeKind.error;
        _message = ocrFailedMessage;
      });
      return;
    }
    if (!mounted) {
      return;
    }

    final List<VinCandidate> found = extractVinCandidates(lines);
    String? message;
    String initial = '';
    if (found.isNotEmpty) {
      initial = found.first.value;
    } else {
      final String? partial = bestPartialVin(lines);
      if (partial != null) {
        initial = partial;
        message = partialVinMessage;
      } else {
        message = noVinFoundMessage;
      }
    }
    setState(() {
      _candidates = found;
      _vin.text = initial;
      _vin.selection = TextSelection.collapsed(offset: initial.length);
      _messageKind = NoticeKind.warning;
      _message = message;
      _stage = _Stage.result;
    });
  }

  void _confirm() {
    final String value = cleanVin(_vin.text);
    if (!isAcceptableChassis(value)) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildScreenBar(context, 'مسح رقم الشاصي (VIN)'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: <Widget>[
              switch (_stage) {
                _Stage.start => _start(context),
                _Stage.reading => const LoadingBlock(message: 'جارٍ قراءة الرقم من الصورة...'),
                _Stage.result => _result(context),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _start(BuildContext context) {
    final Palette p = Palette.of(context);
    final String? message = _message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Panel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.document_scanner_outlined, color: p.primary, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'صوّر رقم الشاصي',
                      style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'التقط صورة واضحة للرقم (على لوحة الزجاج الأمامي أو عمود الباب أو استمارة السيارة). '
                'نقرأ الرقم من الصورة على هاتفك، وسترى الرقم وتستطيع تعديله قبل أي بحث.',
                style: TextStyle(color: p.muted, fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
        if (message != null) ...<Widget>[
          const SizedBox(height: 12),
          NoticeBanner(message: message, kind: _messageKind),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'فتح الكاميرا',
          icon: Icons.photo_camera_outlined,
          onPressed: () => _capture(ImageSource.camera),
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'اختيار صورة من المعرض',
          icon: Icons.photo_library_outlined,
          onPressed: () => _capture(ImageSource.gallery),
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'كتابة الرقم يدوياً',
          icon: Icons.keyboard_alt_outlined,
          onPressed: () => setState(() {
            _vin.clear();
            _candidates = const <VinCandidate>[];
            _message = null;
            _stage = _Stage.result;
          }),
        ),
      ],
    );
  }

  Widget _result(BuildContext context) {
    final Palette p = Palette.of(context);
    final String? message = _message;
    final VinShape shape = checkVin(_vin.text);
    final int length = cleanVin(_vin.text).length;
    final List<VinCandidate> others = _candidates.length > 1 ? _candidates.sublist(1) : const <VinCandidate>[];

    final (String, NoticeKind) status = switch (shape) {
      VinShape.standard => ('رقم شاصي صحيح الشكل: 17 خانة.', NoticeKind.success),
      VinShape.standardLength => (
          'الرقم من 17 خانة لكنه يحتوي على I أو O أو Q، وهي حروف لا تُستخدم في أرقام الشاصي. '
              'غالباً قُرئ 1 أو 0 خطأً، راجعه.',
          NoticeKind.warning,
        ),
      VinShape.other => (
          'عدد الخانات $length وليس 17. يُقبل إن كان رقماً قديماً أو خاصاً، لكن تأكد منه على السيارة.',
          NoticeKind.warning,
        ),
      VinShape.invalid => ('اكتب 5 خانات على الأقل (أحرف إنجليزية وأرقام فقط).', NoticeKind.info),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (message != null) ...<Widget>[
          NoticeBanner(message: message, kind: _messageKind),
          const SizedBox(height: 12),
        ],
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                controller: _vin,
                label: 'رقم الشاصي (يمكنك تعديله)',
                icon: Icons.pin_outlined,
                ltr: true,
                maxLength: maxChassisLength,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
                ],
                onChanged: (String value) => setState(() {}),
                onSubmitted: (String value) => _confirm(),
              ),
              const SizedBox(height: 12),
              NoticeBanner(message: status.$1, kind: status.$2),
              if (others.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text('قراءات أخرى محتملة', style: TextStyle(color: p.muted, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final VinCandidate candidate in others)
                      ActionChip(
                        label: Text(candidate.value, textDirection: TextDirection.ltr),
                        onPressed: () => setState(() {
                          _vin.text = candidate.value;
                          _vin.selection = TextSelection.collapsed(offset: candidate.value.length);
                        }),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: widget.confirmLabel,
          icon: Icons.check_rounded,
          onPressed: isAcceptableChassis(_vin.text) ? _confirm : null,
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'إعادة التصوير',
          icon: Icons.refresh_rounded,
          onPressed: () => setState(() {
            _message = null;
            _stage = _Stage.start;
          }),
        ),
      ],
    );
  }
}
