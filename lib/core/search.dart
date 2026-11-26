// Catalog filtering by text and brand.

import 'config.dart';
import 'models.dart';
import 'text_utils.dart';

/// Parts matching the query, the chosen brand (an empty brand means all brands) and the chosen section, i.e.
/// category (an empty category means all sections).
///
/// Every word of the query must appear in the part's name, brand, OEM number, model, years or branch; or the
/// query, reduced to letters and digits, must appear inside the OEM number. A VIN-like query (17 characters)
/// cannot be matched against the catalog, so it does not hide anything (same as the web app).
List<Part> filterParts(
  List<Part> parts, {
  String query = '',
  String brand = '',
  String category = '',
}) {
  final String normalized = normalizeSearch(query);
  final String compact = compactCode(query);
  final bool vin = isVinLike(query);
  final List<String> words = normalized.isEmpty ? const <String>[] : normalized.split(' ');

  final List<Part> result = <Part>[];
  for (final Part part in parts) {
    if (brand.isNotEmpty && part.brand != brand) {
      continue;
    }
    if (category.isNotEmpty && (part.category ?? '') != category) {
      continue;
    }
    if (words.isNotEmpty && !vin) {
      bool everyWord = true;
      for (final String word in words) {
        if (!part.searchText.contains(word)) {
          everyWord = false;
          break;
        }
      }
      final bool codeHit = compact.length >= 3 && part.pnCompact.contains(compact);
      if (!everyWord && !codeHit) {
        continue;
      }
    }
    result.add(part);
  }
  return result;
}

/// Brands shown as filter chips: the known car brands first, then any other brand present in the catalog.
List<String> catalogBrands(List<Part> parts) {
  final List<String> brands = List<String>.from(carBrands);
  for (final Part part in parts) {
    final String brand = part.brand.trim();
    if (brand.isNotEmpty && !brands.contains(brand)) {
      brands.add(brand);
    }
  }
  return brands;
}

/// Sections (categories) present in the catalog, sorted; parts without a category belong to no section.
List<String> catalogCategories(List<Part> parts) {
  final Set<String> found = <String>{};
  for (final Part part in parts) {
    final String category = (part.category ?? '').trim();
    if (category.isNotEmpty) {
      found.add(category);
    }
  }
  final List<String> list = found.toList()..sort();
  return list;
}
