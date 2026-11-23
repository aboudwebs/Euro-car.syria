import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';

class WorkshopsScreen extends StatefulWidget {
  const WorkshopsScreen({super.key});

  @override
  State<WorkshopsScreen> createState() => _WorkshopsScreenState();
}

class _WorkshopsScreenState extends State<WorkshopsScreen> {
  final TextEditingController _search = TextEditingController();
  List<_Workshop> _workshops = const <_Workshop>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final AppState state = AppScope.read(context);
      final Map<String, dynamic> data = await state.api.getJson('/api/workshops', auth: false);
      final Object? raw = data['workshops'];
      final List<_Workshop> items = raw is List
          ? raw.whereType<Map<String, dynamic>>().map(_Workshop.fromJson).where((w) => w.name.isNotEmpty && w.phone.isNotEmpty).toList()
          : <_Workshop>[];
      if (mounted) setState(() { _workshops = items; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'تعذر تحميل الورشات. تحقق من الاتصال وحاول مجدداً.'; _loading = false; });
    }
  }

  List<_Workshop> get _filtered {
    final String q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _workshops;
    return _workshops.where((w) => '${w.name} ${w.city} ${w.specs.join(' ')}'.toLowerCase().contains(q)).toList();
  }

  Future<void> _openPhone(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone) async {
    String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = '963${digits.substring(1)}';
    final Uri uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final List<_Workshop> shown = _filtered;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('ورشات الصيانة')),
      body: SafeArea(
        child: Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('اعثر على ورشة وتواصل معها مباشرة', style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو المحافظة أو الاختصاص',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: p.panel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: p.primary,
            child: _loading
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const <Widget>[SizedBox(height: 150), Center(child: CircularProgressIndicator())])
                : _error != null
                    ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20), children: <Widget>[
                        const SizedBox(height: 80),
                        Icon(Icons.wifi_off_rounded, size: 42, color: p.muted),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: p.text)),
                        const SizedBox(height: 12),
                        Center(child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))),
                      ])
                    : shown.isEmpty
                        ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(24), children: <Widget>[
                            const SizedBox(height: 80),
                            Icon(Icons.storefront_outlined, size: 46, color: p.muted),
                            const SizedBox(height: 12),
                            Text(_workshops.isEmpty ? 'لا توجد ورشات معتمدة حالياً' : 'لا توجد نتائج مطابقة', textAlign: TextAlign.center, style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('اسحب للأسفل للتحديث', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
                          ])
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                            itemCount: shown.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) => _WorkshopCard(
                              workshop: shown[index],
                              onCall: () => _openPhone(shown[index].phone),
                              onWhatsApp: () => _openWhatsApp(shown[index].phone),
                            ),
                          ),
          ),
        ),
      ],
    )),
    );
  }
}

class _Workshop {
  const _Workshop({required this.id, required this.name, required this.phone, required this.city, required this.specs});

  factory _Workshop.fromJson(Map<String, dynamic> json) => _Workshop(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString().trim() ?? '',
    phone: json['phone']?.toString().trim() ?? '',
    city: json['city']?.toString().trim() ?? '',
    specs: json['specs'] is List ? (json['specs'] as List).whereType<String>().toList() : const <String>[],
  );

  final String id;
  final String name;
  final String phone;
  final String city;
  final List<String> specs;
}

class _WorkshopCard extends StatelessWidget {
  const _WorkshopCard({required this.workshop, required this.onCall, required this.onWhatsApp});

  final _Workshop workshop;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(width: 46, height: 46, decoration: BoxDecoration(color: p.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.home_repair_service_rounded, color: p.primary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(workshop.name, style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w900)),
                if (workshop.city.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: <Widget>[Icon(Icons.location_on_outlined, size: 15, color: p.muted), const SizedBox(width: 3), Text(workshop.city, style: TextStyle(color: p.muted, fontSize: 12))])),
              ])),
            ],
          ),
          if (workshop.specs.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Wrap(spacing: 6, runSpacing: 6, children: workshop.specs.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: p.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(20)),
              child: Text(s, style: TextStyle(color: p.text, fontSize: 11, fontWeight: FontWeight.w600)),
            )).toList()),
          ),
          const SizedBox(height: 14),
          Row(children: <Widget>[
            Expanded(child: OutlinedButton.icon(onPressed: onCall, icon: const Icon(Icons.call_outlined, size: 17), label: const Text('اتصال'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(onPressed: onWhatsApp, icon: const Icon(Icons.chat_rounded, size: 17), label: const Text('واتساب'))),
          ]),
        ],
      ),
    );
  }
}
