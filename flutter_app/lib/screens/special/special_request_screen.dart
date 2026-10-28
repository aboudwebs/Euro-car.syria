// Special request: ask EURO CARS to source a part that is not in the catalog
// (POST /api/special-requests, same fields and rules as the web page).
//
// The look follows the web form: one glass card, the brand picker as an inset segmented grid, inset fields and a
// dashed photo box.

import 'dart:typed_data';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';
import '../../widgets/pickers.dart';
import '../../widgets/segmented.dart';

/// Opens the special request form, optionally filled in from a part or a search the user just made.
void openSpecialRequest(
  BuildContext context, {
  String? brand,
  String partName = '',
  String partNumber = '',
}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext routeContext) => SpecialRequestScreen(
        initialBrand: brand,
        initialPartName: partName,
        initialPartNumber: partNumber,
      ),
    ),
  );
}

/// Opens the form for a catalog part (used when the part is out of stock or its fitment must be checked).
void openSpecialRequestForPart(BuildContext context, Part part) {
  openSpecialRequest(
    context,
    brand: part.brand,
    partName: part.name,
    partNumber: part.pn,
  );
}

class SpecialRequestScreen extends StatefulWidget {
  const SpecialRequestScreen({
    super.key,
    this.initialBrand,
    this.initialPartName = '',
    this.initialPartNumber = '',
  });

  final String? initialBrand;
  final String initialPartName;
  final String initialPartNumber;

  @override
  State<SpecialRequestScreen> createState() => _SpecialRequestScreenState();
}

class _SpecialRequestScreenState extends State<SpecialRequestScreen> {
  final TextEditingController _partName = TextEditingController();
  final TextEditingController _partNumber = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _otherBrand = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  String _brand = carBrands.first;
  Uint8List? _image;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final String brand = (widget.initialBrand ?? '').trim();
    if (brand.isNotEmpty) {
      if (carBrands.contains(brand)) {
        _brand = brand;
      } else {
        _brand = otherLabel;
        _otherBrand.text = brand;
      }
    }
    _partName.text = widget.initialPartName;
    _partNumber.text = widget.initialPartNumber;
    _nameFocus.addListener(_onNameFocusChanged);
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onNameFocusChanged);
    _nameFocus.dispose();
    _partName.dispose();
    _partNumber.dispose();
    _notes.dispose();
    _otherBrand.dispose();
    super.dispose();
  }

  void _onNameFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _reset() {
    _partName.clear();
    _partNumber.clear();
    _notes.clear();
    _otherBrand.clear();
    setState(() {
      _brand = carBrands.first;
      _image = null;
      _error = null;
      _sent = false;
    });
  }

  /// Names of catalog parts that contain what was typed, so a known part is named the way the store names it.
  List<String> _suggestions(List<Part> parts) {
    final String typed = _partName.text.trim();
    if (!_nameFocus.hasFocus || typed.isEmpty) {
      return const <String>[];
    }
    final List<String> names = <String>[];
    for (final Part part in parts) {
      if (part.name.contains(typed) && part.name != typed && !names.contains(part.name)) {
        names.add(part.name);
        if (names.length >= 6) {
          break;
        }
      }
    }
    return names;
  }

  Future<void> _pickImage() async {
    final ImagePickResult result = await pickPhoto(context);
    if (!mounted) {
      return;
    }
    final Uint8List? bytes = result.bytes;
    final String? failure = result.error;
    setState(() {
      if (bytes != null) {
        _image = bytes;
        _error = null;
      } else if (failure != null) {
        _error = failure;
      }
    });
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final String name = _partName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'يرجى إدخال اسم القطعة.');
      return;
    }
    if (_brand == otherLabel && _otherBrand.text.trim().isEmpty) {
      setState(() => _error = 'يرجى كتابة نوع السيارة.');
      return;
    }
    final AppState state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.submitSpecialRequest(
        brand: _brand,
        partName: name,
        otherBrand: _brand == otherLabel ? _otherBrand.text : '',
        partNumber: _partNumber.text,
        notes: _notes.text,
        image: _image,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _sent = true;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      // Everything the user typed stays in the form so they can try again.
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = unexpectedMessage;
      });
    }
  }

  void _showMyRequests() {
    AppScope.read(context).showSpecialRequests();
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final AppState state = AppScope.of(context);
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildScreenBar(context, 'طلب قطعة خاصة'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: _sent ? _successView(p) : _formView(p, state),
          ),
        ),
      ),
    );
  }

  List<Widget> _successView(Palette p) {
    return <Widget>[
      const SizedBox(height: 24),
      Panel(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(child: Icon(Icons.check_circle_rounded, color: p.ok, size: 56)),
            const SizedBox(height: 12),
            Text(
              'وصلنا طلبك',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.text,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'سنؤمّن القطعة ونرسل لك السعر.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 14.5, height: 1.5),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'عرض طلباتي الخاصة',
              icon: Icons.receipt_long_rounded,
              onPressed: _showMyRequests,
            ),
            const SizedBox(height: 10),
            SecondaryButton(label: 'طلب جديد', icon: Icons.add_rounded, onPressed: _reset),
          ],
        ),
      ),
    ];
  }

  Widget _label(Palette p, String text) {
    return Text(
      text,
      style: TextStyle(color: p.muted, fontSize: 13, fontWeight: FontWeight.w700),
    );
  }

  List<Widget> _formView(Palette p, AppState state) {
    final List<String> suggestions = _suggestions(state.parts);
    final Uint8List? photo = _image;
    final String? error = _error;
    return <Widget>[
      Text(
        'القطعة غير متوفرة؟ نؤمّنها لك ونسعّرها ونسلّمها، حتى من خارج البلد.',
        style: TextStyle(color: p.muted, fontSize: 14, height: 1.6),
      ),
      const SizedBox(height: 14),
      Panel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _label(p, 'ماركة السيارة'),
            const SizedBox(height: 8),
            SegmentedTrack<String>(
              layout: SegmentLayout.grid,
              selected: _brand,
              onChanged: (String brand) => setState(() => _brand = brand),
              options: <SegmentOption<String>>[
                for (final String brand in <String>[...carBrands, otherLabel])
                  SegmentOption<String>(value: brand, label: brand),
              ],
            ),
            if (_brand == otherLabel) ...<Widget>[
              const SizedBox(height: 16),
              AppTextField(
                controller: _otherBrand,
                label: 'نوع السيارة',
                hint: 'مثال: بورش، سكودا...',
                icon: Icons.directions_car_outlined,
                maxLength: 80,
                textInputAction: TextInputAction.next,
              ),
            ],
            const SizedBox(height: 16),
            AppTextField(
              controller: _partName,
              focusNode: _nameFocus,
              label: 'اسم القطعة',
              hint: 'اكتب للبحث عن اقتراحات...',
              icon: Icons.build_circle_outlined,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              onChanged: (String _) => setState(() {}),
            ),
            if (suggestions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Panel(
                color: p.menuBg,
                radius: 16,
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < suggestions.length; i++)
                      InkWell(
                        onTap: () {
                          _partName.text = suggestions[i];
                          _nameFocus.unfocus();
                          setState(() {});
                        },
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: i > 0 ? Border(top: BorderSide(color: p.line)) : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                suggestions[i],
                                style: TextStyle(color: p.text.withValues(alpha: 0.85), fontSize: 14.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            AppTextField(
              controller: _partNumber,
              label: 'رقم القطعة أو رقم الشاصي (VIN)',
              icon: Icons.pin_outlined,
              ltr: true,
              maxLength: 64,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _notes,
              label: 'ملاحظات',
              hint: 'الموديل، السنة، المحرك…',
              maxLength: 1000,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            _label(p, 'صورة القطعة (اختياري)'),
            const SizedBox(height: 8),
            _PhotoBox(photo: photo, onTap: _pickImage),
            if (photo != null) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SecondaryButton(
                      label: 'تغيير الصورة',
                      icon: Icons.swap_horiz_rounded,
                      compact: true,
                      onPressed: _pickImage,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SecondaryButton(
                      label: 'إزالة',
                      icon: Icons.delete_outline_rounded,
                      compact: true,
                      color: p.errText,
                      onPressed: () => setState(() => _image = null),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'يمكنك اختيار صورة محفوظة على الهاتف أو التقاط صورة جديدة من واجهة اختيار الصور.',
              style: TextStyle(color: p.muted, fontSize: 12, height: 1.6),
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: 14),
              NoticeBanner(message: error, kind: NoticeKind.error),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'إرسال الطلب',
              icon: Icons.send_rounded,
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    ];
  }
}

/// The web form's photo area: a dashed rounded box with a camera icon, or the chosen photo inside it.
class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.photo, required this.onTap});

  final Uint8List? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final Uint8List? bytes = photo;
    return Semantics(
      button: true,
      label: bytes == null ? 'إضافة صورة للقطعة' : 'تغيير صورة القطعة',
      child: Material(
        color: p.fieldBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: CustomPaint(
            foregroundPainter: _DashedBorderPainter(color: p.lineStrong, radius: 16),
            child: SizedBox(
              height: 176,
              width: double.infinity,
              child: bytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.photo_camera_outlined, color: p.primary, size: 30),
                        const SizedBox(height: 8),
                        Text(
                          'التقط صورة أو اختر صورة من المعرض',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.muted, fontSize: 14),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the 2 px dashed outline of the photo box (Flutter has no dashed borders).
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    const double dash = 7;
    const double gap = 5;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;
    final Path outline = Path()
      ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(1), Radius.circular(radius - 1)));
    for (final PathMetric metric in outline.computeMetrics()) {
      double start = 0;
      while (start < metric.length) {
        final double end = start + dash > metric.length ? metric.length : start + dash;
        canvas.drawPath(metric.extractPath(start, end), paint);
        start += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
