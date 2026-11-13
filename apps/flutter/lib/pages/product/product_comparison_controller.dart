import 'package:get/get.dart';

import 'product_config.dart';

/// Result of toggling a config in the comparison list, mirroring
/// Costben's `ProductComparisonStore.ToggleResult`.
enum ProductComparisonToggleResult {
  added,
  removed,
  limitReached,
  invalid,
}

/// Process-wide comparison selection, mirroring Costben's
/// `ProductComparisonStore`: selections survive leaving one product
/// page and opening another, because the controller is registered
/// permanently (never deleted with a page). At most
/// [maxSelections] configs may be selected.
class ProductComparisonController extends GetxController {
  static const int maxSelections = 10;

  /// The single process-wide instance, created on first use.
  static ProductComparisonController get instance {
    if (Get.isRegistered<ProductComparisonController>()) {
      return Get.find<ProductComparisonController>();
    }
    return Get.put(ProductComparisonController(), permanent: true);
  }

  /// Currently selected configs, in selection order.
  final selections = <ProductComparisonSelection>[].obs;

  /// Ids of the selected configs, for dialog selected states.
  Set<String> get selectedIds =>
      selections.map((selection) => selection.config.id).toSet();

  bool isSelected(String configId) =>
      selections.any((selection) => selection.config.id == configId);

  ProductComparisonToggleResult toggle(ProductComparisonSelection selection) {
    final configId = selection.config.id;
    if (configId.isEmpty) return ProductComparisonToggleResult.invalid;
    if (isSelected(configId)) {
      selections.removeWhere((item) => item.config.id == configId);
      return ProductComparisonToggleResult.removed;
    }
    if (selections.length >= maxSelections) {
      return ProductComparisonToggleResult.limitReached;
    }
    selections.add(selection);
    return ProductComparisonToggleResult.added;
  }

  void remove(String configId) {
    selections.removeWhere((item) => item.config.id == configId);
  }
}
