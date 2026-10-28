// Catalog tab: search, brand filter and the list of parts (GET /api/parts).

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/search.dart';
import '../../core/text_utils.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import '../../widgets/search_field.dart';
import '../../widgets/segmented.dart';
import '../home/tab_header.dart';
import '../special/special_request_screen.dart';
import 'part_card.dart';
import 'part_details_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _search = TextEditingController();
  String _brand = '';

  // The last filter run, reused while neither the catalog, the text nor the brand changed (the cart changes
  // often, and re-filtering a long catalog on every tap would be wasted work).
  List<Part>? _cachedSource;
  String _cachedQuery = '';
  String _cachedBrand = '';
  List<Part> _cachedResult = const <Part>[];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Part> _filtered(List<Part> source) {
    final String query = _search.text;
    if (identical(source, _cachedSource) && query == _cachedQuery && _brand == _cachedBrand) {
      return _cachedResult;
    }
    final List<Part> result = filterParts(source, query: query, brand: _brand);
    _cachedSource = source;
    _cachedQuery = query;
    _cachedBrand = _brand;
    _cachedResult = result;
    return result;
  }

  void _openDetails(Part part) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => PartDetailsScreen(partId: part.id),
      ),
    );
  }

  /// Opens a special request filled in from what was typed in the search box.
  void _requestFromSearch(String query) {
    final bool code = _looksLikeCode(query);
    openSpecialRequest(
      context,
      brand: _brand.isEmpty ? null : _brand,
      partName: code ? '' : query,
      partNumber: code ? query : '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final AppState state = AppScope.of(context);
    final List<Part> all = state.parts;
    final List<String> brands = catalogBrands(all);
    if (_brand.isNotEmpty && !brands.contains(_brand)) {
      _brand = '';
    }
    final List<Part> shown = _filtered(all);

    return Column(
      children: <Widget>[
        TabHeader(
          title: 'متجر اليورو',
          subtitle: 'ابحث برقم القطعة أو رقم الشاصي واحصل على السعر فورًا',
          actions: <Widget>[
            RoundIconButton(
              onTap: () => openSpecialRequest(context),
              tooltip: 'طلب قطعة خاصة',
              icon: Icons.playlist_add_rounded,
              iconColor: p.primary,
              size: 44,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: SearchField(
            controller: _search,
            hint: 'رقم القطعة أو اسمها أو رقم الشاصي (VIN)',
            onChanged: (String value) => setState(() {}),
            onClear: () {
              _search.clear();
              setState(() {});
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: SegmentedTrack<String>(
            layout: SegmentLayout.scroll,
            selected: _brand,
            onChanged: (String value) => setState(() => _brand = value),
            options: <SegmentOption<String>>[
              const SegmentOption<String>(value: '', label: 'الكل'),
              for (final String brand in brands) SegmentOption<String>(value: brand, label: brand),
            ],
          ),
        ),
        if (state.partsLoaded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                shown.length == all.length ? '${all.length} قطعة' : '${shown.length} من ${all.length} قطعة',
                style: TextStyle(color: p.muted, fontSize: 12.5),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: p.accent,
            backgroundColor: p.panel,
            onRefresh: () => state.loadParts(),
            child: _list(context, state, shown),
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, AppState state, List<Part> shown) {
    if (!state.partsLoaded) {
      final String? error = state.partsError;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          if (error != null)
            NoticeBanner(
              message: error,
              kind: NoticeKind.error,
              onRetry: () => state.loadParts(),
            )
          else
            const LoadingBlock(message: 'جارٍ تحميل الكتالوج...'),
        ],
      );
    }

    final String query = _search.text.trim();
    final String? refreshError = state.partsError;
    final List<Widget> top = <Widget>[
      if (refreshError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: NoticeBanner(
            message: refreshError,
            kind: NoticeKind.error,
            onRetry: () => state.loadParts(),
          ),
        ),
      if (isVinLike(query))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: NoticeBanner(
            message: 'هذا يبدو رقم شاصي (VIN). لا يمكن البحث في الكتالوج بهذا الرقم، لذلك نعرض كل القطع. '
                'أرسله مع طلب خاص لنؤمّن لك القطعة المطابقة لسيارتك.',
            onRetry: () => openSpecialRequest(context, partNumber: query.toUpperCase()),
            retryLabel: 'طلب خاص',
          ),
        ),
    ];

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: top.length + (shown.isEmpty ? 1 : shown.length),
      itemBuilder: (BuildContext context, int index) {
        if (index < top.length) {
          return top[index];
        }
        if (shown.isEmpty) {
          return _emptyResult(state, query);
        }
        final Part part = shown[index - top.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PartCard(
            key: ValueKey<String>(part.id),
            part: part,
            onOpen: () => _openDetails(part),
            onRequest: () => openSpecialRequestForPart(context, part),
          ),
        );
      },
    );
  }

  Widget _emptyResult(AppState state, String query) {
    if (state.parts.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'لا توجد قطع في الكتالوج حالياً',
        message: 'اسحب للأسفل للتحديث، أو ارفع طلباً خاصاً لما تحتاجه.',
        actionLabel: 'ارفعها كطلب خاص',
        onAction: () => openSpecialRequest(context),
      );
    }
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'لا توجد قطع مطابقة',
      message: 'لم تجد القطعة؟ نؤمّنها لك ولو من خارج البلد.',
      actionLabel: 'ارفعها كطلب خاص',
      onAction: () => _requestFromSearch(query),
    );
  }
}

final RegExp _codePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ._/-]*$');

/// True for text such as "A 276 180 09 09" or "1K0-615-301": it is more likely a part number than a name.
bool _looksLikeCode(String text) {
  final String value = toWesternDigits(text.trim());
  return value.isNotEmpty && _codePattern.hasMatch(value) && RegExp(r'[0-9]').hasMatch(value);
}
