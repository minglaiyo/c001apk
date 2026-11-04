/// Product parameter parsing and comparison merging.
///
/// Port of the *parsing and merging logic* (not the UI) of
/// Costben/c001apk's `ui/topic/ProductComparison.kt`
/// (`productSpecSections`, `mergeSections`, `priceLabel`) and its
/// `data/ProductComparisonStore.kt` selection rules, adapted to Dart.
/// The reference project is AGPL-3.0; this file keeps its own
/// Material rendering in `product_config_ui.dart` and does not reuse
/// any coui17 component, brand asset, or emoji asset from it.
///
/// The endpoint is the coolapk micro-page
/// `https://m.coolapk.com/mp/product/configInfo?id=<config id>`,
/// which answers `dataRows` at the top level or wrapped in `data`.
/// See `NetworkRepo.getProductConfigInfo` for the request shape.

import 'product_detail.dart';

/// One config selected for comparison: the product it came from plus
/// the config itself. Mirrors Costben's `ProductComparisonSelection`.
class ProductComparisonSelection {
  const ProductComparisonSelection({
    required this.productTitle,
    this.productLogo,
    required this.config,
  });

  final String productTitle;
  final String? productLogo;
  final ProductConfig config;
}

/// One parameter row: a name and its display value. `group` is the
/// group path (e.g. "屏幕 / 显示") the row belonged to, if any.
class ProductSpecItem {
  const ProductSpecItem({
    required this.name,
    required this.value,
    this.group,
  });

  final String name;
  final String value;
  final String? group;
}

/// One parameter section: a `dataRows` key (the section title) and
/// its rows. Empty sections are dropped by the parser.
class ProductSpecSection {
  const ProductSpecSection({required this.title, required this.items});

  final String title;
  final List<ProductSpecItem> items;
}

/// One comparison column: a selected config plus its parsed sections.
class ProductComparisonColumn {
  const ProductComparisonColumn({
    required this.selection,
    required this.sections,
  });

  final ProductComparisonSelection selection;
  final List<ProductSpecSection> sections;
}

/// One merged comparison row: the parameter name, one value per
/// column (missing values are [productMissingValue]), and its group.
class ProductComparisonItem {
  const ProductComparisonItem({
    required this.name,
    required this.values,
    this.group,
  });

  final String name;
  final List<String> values;
  final String? group;
}

/// One merged comparison section.
class ProductComparisonSection {
  const ProductComparisonSection({required this.title, required this.items});

  final String title;
  final List<ProductComparisonItem> items;
}

/// Placeholder for a column that has no value for a merged row.
const String productMissingValue = '—';

String _text(dynamic value) {
  if (value is String) return value.trim();
  if (value == null) return '';
  return value.toString().trim();
}

/// Mirrors Costben's `displayValue`: a primitive's text, a list's
/// items joined with " / ", or an object's `name: value` pairs joined
/// with " / ". Null, empty and JsonNull-equivalent inputs give null.
String? _displayValue(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
  if (value is num || value is bool) return value.toString();
  if (value is List) {
    final parts = <String>[];
    for (final item in value) {
      final text = _displayValue(item);
      if (text != null) parts.add(text);
    }
    final joined = parts.join(' / ').trim();
    return joined.isEmpty ? null : joined;
  }
  if (value is Map) {
    final parts = <String>[];
    for (final entry in value.entries) {
      final text = _displayValue(entry.value);
      if (text != null) parts.add('${entry.key}: $text');
    }
    final joined = parts.join(' / ').trim();
    return joined.isEmpty ? null : joined;
  }
  return null;
}

ProductSpecItem? _toSpecItem(Map rowData, String? group) {
  final name = _text(rowData['title']);
  if (name.isEmpty) return null;
  final shown = _displayValue(rowData['show_value']);
  if (shown == null || shown == '-') return null;
  final unit = _text(rowData['unit']);
  final mainValue = unit.isEmpty ? shown : shown + unit;
  final addition = _displayValue(rowData['addition_value']);
  final extra =
      (addition == null || addition == '-' || addition == mainValue)
          ? null
          : addition;
  final value = extra == null ? mainValue : '$mainValue\n$extra';
  return ProductSpecItem(name: name, value: value, group: group);
}

/// Parses a `configInfo` body into sections, following Costben's
/// `productSpecSections` exactly: `json["data"] ?: json`, then
/// `dataRows` (key = section title, value = row array); rows split
/// by `type` into `groupData` (a `keyName` + `depth` group-path
/// stack) and `itemData` (a `data` object turned into an item).
/// Rows whose value is "-" or empty are dropped, as are sections
/// that end up with no items.
List<ProductSpecSection> productSpecSections(dynamic json) {
  if (json is! Map) return [];
  final root = json['data'] is Map ? json['data'] as Map : json;
  final dataRows = root['dataRows'];
  if (dataRows is! Map) return [];
  final sections = <ProductSpecSection>[];
  for (final entry in dataRows.entries) {
    final rows = entry.value;
    if (rows is! List) continue;
    final groupPath = <String>[];
    final items = <ProductSpecItem>[];
    for (final element in rows) {
      if (element is! Map) continue;
      final type = _text(element['type']);
      if (type == 'groupData') {
        final groupName = _text(element['keyName']);
        if (groupName.isNotEmpty) {
          var depth = int.tryParse(_text(element['depth'])) ?? 1;
          if (depth < 1) depth = 1;
          while (groupPath.length >= depth) {
            groupPath.removeLast();
          }
          while (groupPath.length < depth - 1) {
            groupPath.add('');
          }
          groupPath.add(groupName);
        }
      } else if (type == 'itemData') {
        final data = element['data'];
        if (data is Map) {
          final group = groupPath.where((part) => part.isNotEmpty).join(' / ');
          final item = _toSpecItem(data, group.isEmpty ? null : group);
          if (item != null) items.add(item);
        }
      }
    }
    if (items.isNotEmpty) {
      final title = _text(entry.key);
      sections.add(ProductSpecSection(
        title: title.isEmpty ? '参数' : title,
        items: items,
      ));
    }
  }
  return sections;
}

/// Normalised key for aligning sections and items across columns:
/// whitespace removed, lower-cased, mirroring Costben's
/// `normalizedSpecKey`.
String normalizeSpecKey(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();

String _comparisonKey(String? group, String name) =>
    '${normalizeSpecKey(group ?? '')}\u0000${normalizeSpecKey(name)}';

/// Whether a merged row's values differ across columns (after
/// normalisation), mirroring Costben's `hasDifference`. Missing
/// values count as a difference, exactly as in the reference.
bool productValuesDiffer(List<String> values) {
  if (values.length <= 1) return false;
  return values.map(normalizeSpecKey).toSet().length > 1;
}

/// Merges columns into aligned sections, mirroring Costben's
/// `mergeSections`: section order follows first appearance, item
/// order follows first appearance within a section, and a column
/// without a value for a row gets [productMissingValue].
List<ProductComparisonSection> mergeProductSections(
  List<ProductComparisonColumn> columns,
) {
  final sectionKeys = <String>[];
  final sectionKeySet = <String>{};
  for (final column in columns) {
    for (final section in column.sections) {
      final key = normalizeSpecKey(section.title);
      if (sectionKeySet.add(key)) sectionKeys.add(key);
    }
  }
  final sectionMaps = columns
      .map((column) => <String, ProductSpecSection>{
            for (final section in column.sections)
              normalizeSpecKey(section.title): section,
          })
      .toList();
  final merged = <ProductComparisonSection>[];
  for (final sectionKey in sectionKeys) {
    final sections = sectionMaps.map((map) => map[sectionKey]).toList();
    final itemKeys = <String>[];
    final itemKeySet = <String>{};
    for (final section in sections) {
      if (section == null) continue;
      for (final item in section.items) {
        final key = _comparisonKey(item.group, item.name);
        if (itemKeySet.add(key)) itemKeys.add(key);
      }
    }
    final itemMaps = sections
        .map((section) => <String, ProductSpecItem>{
              if (section != null)
                for (final item in section.items)
                  _comparisonKey(item.group, item.name): item,
            })
        .toList();
    final items = <ProductComparisonItem>[];
    for (final itemKey in itemKeys) {
      ProductSpecItem? source;
      for (final map in itemMaps) {
        source = map[itemKey];
        if (source != null) break;
      }
      items.add(ProductComparisonItem(
        name: source?.name ?? '',
        values: itemMaps
            .map((map) => map[itemKey]?.value ?? productMissingValue)
            .toList(),
        group: source?.group,
      ));
    }
    if (items.isNotEmpty) {
      String title = '';
      for (final section in sections) {
        if (section != null) {
          title = section.title;
          break;
        }
      }
      merged.add(ProductComparisonSection(title: title, items: items));
    }
  }
  return merged;
}

/// Whether a config price string is a positive number. A leading
/// "¥" and thousand separators are stripped before parsing, since
/// `configRows` prices are not guaranteed to be bare numbers.
bool isPositiveProductPrice(String? price) {
  if (price == null) return false;
  final cleaned = price.trim().replaceAll('¥', '').replaceAll(',', '');
  if (cleaned.isEmpty) return false;
  final value = double.tryParse(cleaned);
  return value != null && value > 0;
}

/// Display label for a config price: "¥…" for a positive price,
/// "暂无价格" otherwise, mirroring Costben's `priceLabel`.
String productPriceLabel(String? price) {
  if (price == null) return '暂无价格';
  final cleaned = price.trim().replaceAll('¥', '').replaceAll(',', '');
  return isPositiveProductPrice(price) ? '¥$cleaned' : '暂无价格';
}
