// Saved delivery addresses: list, add, edit, delete and pick the default one. The cart's address chooser reuses
// [openAddressForm] and the same AppState list (GET/POST/PUT/DELETE /api/account/addresses).

import 'package:flutter/material.dart' hide Text;

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';
import '../../widgets/pickers.dart';
import '../../widgets/select_field.dart';
import '../../widgets/tx.dart';

/// Opens the list of saved addresses.
void openAddresses(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (BuildContext routeContext) => const AddressesScreen()),
  );
}

/// Opens the add / edit form. Returns true when an address was saved.
Future<bool> openAddressForm(BuildContext context, {SavedAddress? address}) async {
  final bool? saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (BuildContext routeContext) => AddressFormScreen(address: address)),
  );
  return saved == true;
}

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        AppScope.read(context).loadAddresses();
      }
    });
  }

  Future<void> _run(String id, Future<void> Function() action, String doneMessage) async {
    setState(() {
      _busyId = id;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        showSnack(context, doneMessage);
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

  Future<void> _delete(SavedAddress address) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Palette p = Palette.of(dialogContext);
        return AlertDialog(
          title: const Text('حذف العنوان'),
          content: Text('هل تريد حذف العنوان «${address.label}»؟ لن تتأثر طلباتك السابقة.'),
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
    await _run(address.id, () => state.deleteAddress(address.id), 'تم حذف العنوان');
  }

  Future<void> _makeDefault(SavedAddress address) {
    final AppState state = AppScope.read(context);
    return _run(address.id, () => state.setDefaultAddress(address.id), 'تم تعيين العنوان الافتراضي');
  }

  Future<void> _edit(SavedAddress? address) async {
    final bool saved = await openAddressForm(context, address: address);
    if (saved && mounted) {
      showSnack(context, address == null ? 'تمت إضافة العنوان' : 'تم حفظ التعديلات');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final String? error = _error ?? state.addressesError;
    final List<SavedAddress> list = state.addresses;
    final bool ready = state.addressesReady;

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildScreenBar(context, 'عناويني'),
        floatingActionButton: ready && state.addressesLoaded
            ? FloatingActionButton.extended(
                onPressed: () => _edit(null),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('إضافة عنوان'),
              )
            : null,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => state.loadAddresses(silent: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                if (error != null) ...<Widget>[
                  NoticeBanner(
                    message: error,
                    kind: NoticeKind.error,
                    onRetry: () => state.loadAddresses(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!state.addressesLoaded && state.addressesLoading)
                  const LoadingBlock(message: 'جارٍ تحميل العناوين...')
                else if (!ready)
                  const NoticeBanner(
                    message: 'ميزة العناوين المحفوظة غير مفعّلة بعد على الخادم. تواصل مع الإدارة.',
                    kind: NoticeKind.warning,
                  )
                else if (state.addressesLoaded && list.isEmpty)
                  EmptyState(
                    icon: Icons.location_off_outlined,
                    title: 'لا توجد عناوين محفوظة',
                    message: 'احفظ عنوان الورشة أو المستودع لتختاره بسرعة عند إتمام الطلب.',
                    actionLabel: 'إضافة عنوان',
                    onAction: () => _edit(null),
                  )
                else
                  for (final SavedAddress address in list) ...<Widget>[
                    _AddressCard(
                      address: address,
                      busy: _busyId == address.id,
                      onEdit: () => _edit(address),
                      onDelete: () => _delete(address),
                      onMakeDefault: address.isDefault ? null : () => _makeDefault(address),
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

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  final SavedAddress address;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMakeDefault;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final String summary = address.summary;
    final String phone = address.phone ?? '';
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.location_on_outlined, color: p.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address.label,
                  style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (address.isDefault) const StatusChip(label: 'افتراضي', tone: StatusTone.success),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
                ),
            ],
          ),
          if (summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(summary, style: TextStyle(color: p.text, fontSize: 14, height: 1.5)),
          ],
          if (phone.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Icon(Icons.phone_outlined, size: 15, color: p.muted),
                const SizedBox(width: 6),
                Text(phone, textDirection: TextDirection.ltr, style: TextStyle(color: p.muted, fontSize: 13.5)),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            children: <Widget>[
              TextButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('تعديل'),
              ),
              if (onMakeDefault != null)
                TextButton.icon(
                  onPressed: busy ? null : onMakeDefault,
                  icon: const Icon(Icons.star_outline_rounded, size: 18),
                  label: const Text('جعله افتراضياً'),
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

class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key, this.address});

  final SavedAddress? address;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  late final TextEditingController _label;
  late final TextEditingController _area;
  late final TextEditingController _street;
  late final TextEditingController _details;
  late final TextEditingController _phone;
  String _governorate = '';
  bool _makeDefault = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final SavedAddress? a = widget.address;
    _label = TextEditingController(text: a?.label ?? '');
    _area = TextEditingController(text: a?.area ?? '');
    _street = TextEditingController(text: a?.street ?? '');
    _details = TextEditingController(text: a?.details ?? '');
    _phone = TextEditingController(text: a?.phone ?? '');
    _governorate = a?.governorate ?? '';
    _makeDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _area.dispose();
    _street.dispose();
    _details.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickGovernorate() async {
    final String? picked = await showChoiceSheet<String>(
      context: context,
      title: 'اختر المحافظة',
      options: governorates,
      labelOf: (String value) => value,
      selected: _governorate.isEmpty ? null : _governorate,
    );
    if (picked != null && mounted) {
      setState(() => _governorate = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (_label.text.trim().isEmpty) {
      setState(() => _error = 'اكتب اسماً للعنوان (مثال: الورشة).');
      return;
    }
    if (_governorate.isEmpty &&
        _area.text.trim().isEmpty &&
        _street.text.trim().isEmpty &&
        _details.text.trim().isEmpty) {
      setState(() => _error = 'أدخل تفاصيل العنوان (المحافظة أو المنطقة أو الشارع).');
      return;
    }
    final AppState state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await state.saveAddress(
        id: widget.address?.id,
        label: _label.text,
        governorate: _governorate,
        area: _area.text,
        street: _street.text,
        details: _details.text,
        phone: _phone.text,
        makeDefault: _makeDefault,
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
    final Palette p = Palette.of(context);
    final String? error = _error;
    final bool editing = widget.address != null;
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildScreenBar(context, editing ? 'تعديل العنوان' : 'إضافة عنوان'),
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
                      controller: _label,
                      label: 'اسم العنوان',
                      hint: 'مثال: الورشة، المستودع',
                      icon: Icons.label_outline_rounded,
                      maxLength: 60,
                      radius: 12,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    SelectField(
                      label: 'المحافظة',
                      value: _governorate,
                      placeholder: 'اختر المحافظة',
                      icon: Icons.location_city_outlined,
                      radius: 12,
                      onTap: _pickGovernorate,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _area,
                      label: 'المنطقة',
                      icon: Icons.map_outlined,
                      maxLength: 120,
                      radius: 12,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _street,
                      label: 'الشارع',
                      icon: Icons.signpost_outlined,
                      maxLength: 200,
                      radius: 12,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _details,
                      label: 'تفاصيل إضافية (اختياري)',
                      hint: 'بناء، طابق، أقرب معلم',
                      icon: Icons.notes_rounded,
                      maxLength: 300,
                      maxLines: 3,
                      radius: 12,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _phone,
                      label: 'رقم الهاتف أو واتساب للتواصل عند التسليم',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      maxLength: 32,
                      ltr: true,
                      radius: 12,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _makeDefault,
                      onChanged: (bool value) => setState(() => _makeDefault = value),
                      title: Text('جعله العنوان الافتراضي', style: TextStyle(color: p.text, fontSize: 14.5)),
                    ),
                    if (error != null) ...<Widget>[
                      const SizedBox(height: 8),
                      NoticeBanner(message: error, kind: NoticeKind.error),
                    ],
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: editing ? 'حفظ التعديلات' : 'حفظ العنوان',
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
