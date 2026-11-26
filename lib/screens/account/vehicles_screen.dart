// My vehicles: cars registered with their chassis number (VIN). A saved vehicle can be searched in the catalog in
// one tap, and the VIN can be typed, pasted or scanned with the camera. Data: /api/account/vehicles (only the
// signed-in customer's own rows are ever returned by the server).

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/text_utils.dart';
import '../../core/vin.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';
import '../../widgets/pickers.dart';
import '../catalog/vin_scanner_screen.dart';
import '../../widgets/tx.dart';

/// Opens the list of registered vehicles.
void openVehicles(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (BuildContext routeContext) => const VehiclesScreen()),
  );
}

/// Opens the add / edit form. Returns true when a vehicle was saved.
Future<bool> openVehicleForm(BuildContext context, {SavedVehicle? vehicle}) async {
  final bool? saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (BuildContext routeContext) => VehicleFormScreen(vehicle: vehicle)),
  );
  return saved == true;
}

/// Searches the catalog with a vehicle's VIN: closes the pushed screens and fills the catalog's search box.
void searchWithVehicle(BuildContext context, SavedVehicle vehicle) {
  final AppState state = AppScope.read(context);
  Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  state.searchCatalogFor(vehicle.vin);
}

/// Lets the user pick one of their saved vehicles and searches the catalog by its VIN. When there is no saved
/// vehicle yet, offers to add one.
Future<void> pickVehicleAndSearch(BuildContext context) async {
  final AppState state = AppScope.read(context);
  if (!state.vehiclesLoaded) {
    await state.loadVehicles();
  }
  if (!context.mounted) {
    return;
  }
  final List<SavedVehicle> list = state.vehicles;
  if (list.isEmpty) {
    final String message = state.vehiclesReady
        ? 'لا توجد مركبات محفوظة. أضف مركبتك مع رقم الشاصي لتبحث به بنقرة واحدة.'
        : 'ميزة المركبات المحفوظة غير مفعّلة بعد على الخادم. تواصل مع الإدارة.';
    showSnack(context, message);
    if (state.vehiclesReady) {
      openVehicles(context);
    }
    return;
  }
  final SavedVehicle? picked = await showChoiceSheet<SavedVehicle>(
    context: context,
    title: 'اختر مركبتك للبحث برقم الشاصي',
    options: list,
    labelOf: (SavedVehicle v) => '${v.title} · ${v.vin}',
  );
  if (picked != null && context.mounted) {
    state.searchCatalogFor(picked.vin);
  }
}

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        AppScope.read(context).loadVehicles();
      }
    });
  }

  Future<void> _edit(SavedVehicle? vehicle) async {
    final bool saved = await openVehicleForm(context, vehicle: vehicle);
    if (saved && mounted) {
      showSnack(context, vehicle == null ? 'تمت إضافة المركبة' : 'تم حفظ التعديلات');
    }
  }

  Future<void> _delete(SavedVehicle vehicle) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Palette p = Palette.of(dialogContext);
        return AlertDialog(
          title: const Text('حذف المركبة'),
          content: Text('هل تريد حذف «${vehicle.title}» من مركباتك؟'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: p.errText),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final AppState state = AppScope.read(context);
    setState(() {
      _busyId = vehicle.id;
      _error = null;
    });
    try {
      await state.deleteVehicle(vehicle.id);
      if (mounted) {
        showSnack(context, 'تم حذف المركبة');
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = unexpectedMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final String? error = _error ?? state.vehiclesError;
    final List<SavedVehicle> list = state.vehicles;
    final bool ready = state.vehiclesReady;

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildScreenBar(context, 'مركباتي'),
        floatingActionButton: ready && state.vehiclesLoaded
            ? FloatingActionButton.extended(
                onPressed: () => _edit(null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة مركبة'),
              )
            : null,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => state.loadVehicles(silent: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                if (error != null) ...<Widget>[
                  NoticeBanner(message: error, kind: NoticeKind.error, onRetry: () => state.loadVehicles()),
                  const SizedBox(height: 12),
                ],
                if (!state.vehiclesLoaded && state.vehiclesLoading)
                  const LoadingBlock(message: 'جارٍ تحميل المركبات...')
                else if (!ready)
                  const NoticeBanner(
                    message: 'ميزة المركبات المحفوظة غير مفعّلة بعد على الخادم. تواصل مع الإدارة.',
                    kind: NoticeKind.warning,
                  )
                else if (state.vehiclesLoaded && list.isEmpty)
                  EmptyState(
                    icon: Icons.directions_car_outlined,
                    title: 'لا توجد مركبات مسجلة',
                    message: 'سجّل مركبتك مع رقم الشاصي (VIN) لتبحث عن قطعها بنقرة واحدة.',
                    actionLabel: 'إضافة مركبة',
                    onAction: () => _edit(null),
                  )
                else
                  for (final SavedVehicle vehicle in list) ...<Widget>[
                    _VehicleCard(
                      vehicle: vehicle,
                      busy: _busyId == vehicle.id,
                      onSearch: () => searchWithVehicle(context, vehicle),
                      onEdit: () => _edit(vehicle),
                      onDelete: () => _delete(vehicle),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.busy,
    required this.onSearch,
    required this.onEdit,
    required this.onDelete,
  });

  final SavedVehicle vehicle;
  final bool busy;
  final VoidCallback onSearch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final String description = vehicle.description;
    final String notes = vehicle.notes ?? '';
    final bool showDescription = description.isNotEmpty && description != vehicle.title;
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.directions_car_filled_outlined, color: p.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  vehicle.title,
                  style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
                ),
            ],
          ),
          if (showDescription) ...<Widget>[
            const SizedBox(height: 4),
            Text(description, style: TextStyle(color: p.muted, fontSize: 13.5)),
          ],
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  vehicle.vin,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              RoundIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'نسخ رقم الشاصي',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: vehicle.vin));
                  if (context.mounted) {
                    showSnack(context, 'تم نسخ رقم الشاصي');
                  }
                },
              ),
            ],
          ),
          if (notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(notes, style: TextStyle(color: p.muted, fontSize: 13, height: 1.5)),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: PrimaryButton(
              label: 'بحث عن قطع هذه المركبة',
              icon: Icons.search_rounded,
              compact: true,
              onPressed: busy ? null : onSearch,
            ),
          ),
          const SizedBox(height: 2),
          Wrap(
            children: <Widget>[
              TextButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('تعديل'),
              ),
              TextButton.icon(
                onPressed: busy ? null : onDelete,
                style: TextButton.styleFrom(foregroundColor: p.errText),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('حذف'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, this.vehicle});

  final SavedVehicle? vehicle;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _vin;
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _notes;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final SavedVehicle? v = widget.vehicle;
    _name = TextEditingController(text: v?.name ?? '');
    _vin = TextEditingController(text: v?.vin ?? '');
    _make = TextEditingController(text: v?.make ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _year = TextEditingController(text: v?.year?.toString() ?? '');
    _notes = TextEditingController(text: v?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _vin.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final String? scanned = await scanVin(context, confirmLabel: 'استخدام الرقم لهذه المركبة');
    if (scanned != null && mounted) {
      setState(() {
        _vin.text = scanned;
        _vin.selection = TextSelection.collapsed(offset: scanned.length);
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final String vin = _vin.text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (!isAcceptableChassis(vin)) {
      setState(() => _error = 'رقم الشاصي غير صالح: أحرف وأرقام إنجليزية فقط (من 5 إلى 32 خانة).');
      return;
    }
    final String yearText = toWesternDigits(_year.text).trim();
    int? year;
    if (yearText.isNotEmpty) {
      year = int.tryParse(yearText);
      if (year == null || year < 1900 || year > 2100) {
        setState(() => _error = 'سنة الصنع غير صالحة.');
        return;
      }
    }
    final AppState state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await state.saveVehicle(
        id: widget.vehicle?.id,
        vin: vin,
        name: _name.text,
        make: _make.text,
        model: _model.text,
        year: year,
        notes: _notes.text,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = unexpectedMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? error = _error;
    final bool editing = widget.vehicle != null;
    final VinShape shape = checkVin(_vin.text);
    final String? hint = switch (shape) {
      VinShape.standardLength => 'الرقم من 17 خانة لكنه يحتوي على I أو O أو Q، راجعه قبل الحفظ.',
      VinShape.other => 'ليس من 17 خانة: يُقبل إن كان رقماً قديماً أو خاصاً.',
      _ => null,
    };
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildScreenBar(context, editing ? 'تعديل المركبة' : 'إضافة مركبة'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: <Widget>[
              Panel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    AppTextField(
                      controller: _name,
                      label: 'اسم المركبة (اختياري)',
                      hint: 'مثال: سيارة الورشة',
                      icon: Icons.label_outline_rounded,
                      maxLength: 80,
                      radius: 12,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _vin,
                      label: 'رقم الشاصي (VIN)',
                      icon: Icons.pin_outlined,
                      ltr: true,
                      maxLength: maxChassisLength,
                      radius: 12,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
                      ],
                      onChanged: (String value) => setState(() {}),
                      suffix: RoundIconButton(
                        icon: Icons.document_scanner_outlined,
                        tooltip: 'مسح الرقم بالكاميرا',
                        onTap: _scan,
                      ),
                    ),
                    if (hint != null) ...<Widget>[
                      const SizedBox(height: 8),
                      NoticeBanner(message: hint, kind: NoticeKind.warning),
                    ],
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _make,
                      label: 'الماركة (اختياري)',
                      icon: Icons.directions_car_outlined,
                      maxLength: 60,
                      radius: 12,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _model,
                      label: 'الموديل (اختياري)',
                      icon: Icons.commute_outlined,
                      maxLength: 80,
                      radius: 12,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _year,
                      label: 'سنة الصنع (اختياري)',
                      icon: Icons.event_outlined,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      ltr: true,
                      radius: 12,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _notes,
                      label: 'ملاحظات (اختياري)',
                      icon: Icons.notes_rounded,
                      maxLength: 300,
                      maxLines: 3,
                      radius: 12,
                    ),
                    if (error != null) ...<Widget>[
                      const SizedBox(height: 14),
                      NoticeBanner(message: error, kind: NoticeKind.error),
                    ],
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: editing ? 'حفظ التعديلات' : 'حفظ المركبة',
                      icon: Icons.save_outlined,
                      radius: 12,
                      busy: _saving,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
