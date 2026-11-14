import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/status_views.dart';
import '../../logic/network/api_failure.dart';
import '../../logic/network/network_repo.dart';
import 'product_comparison_controller.dart';
import 'product_config.dart';
import 'product_detail.dart';

/// Material dialogs for product parameters and configuration
/// comparison, following the *interaction shape* of Costben/c001apk's
/// `ui/topic/ProductComparison.kt` (config list dialog, details
/// dialog, fullscreen comparison dialog) rendered with plain Flutter
/// Material components instead of coui17's `OverlayDialog`.
///
/// Dialog behaviour mirrors the reference: the config list shows the
/// product title plus "N 个配置 · 已选 x/10"; the details dialog
/// loads `configInfo` on open and retries on failure; the comparison
/// dialog loads every selected config in parallel and aligns rows by
/// normalised key, with a "隐藏相同项" switch. The reference project
/// is AGPL-3.0; see `product_config.dart` for the parsing credit.

const double _parameterColumnWidth = 104;
const double _valueColumnWidth = 148;

/// Config list dialog: one row per config with a "参数" action and a
/// "对比"/"已选" toggle, plus a footer "对比已选 (M)" action.
/// Selected states are reactive via [comparison]'s observable list,
/// so toggling a row updates its button without rebuilding the page.
class ProductConfigListDialog extends StatelessWidget {
  const ProductConfigListDialog({
    super.key,
    required this.productTitle,
    required this.configs,
    required this.comparison,
    required this.onViewConfig,
    required this.onToggleCompare,
    required this.onOpenComparison,
  });

  final String productTitle;
  final List<ProductConfig> configs;
  final ProductComparisonController comparison;
  final void Function(ProductConfig config) onViewConfig;
  final void Function(ProductConfig config) onToggleCompare;
  final VoidCallback onOpenComparison;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(productTitle.isNotEmpty ? productTitle : '配置参数'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(
            () => Text(
              '${configs.length} 个配置 · 已选 ${comparison.selections.length}/${ProductComparisonController.maxSelections}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 430),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: configs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final config = configs[index];
                return Obx(() {
                  final selected = comparison.isSelected(config.id);
                  return Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => onViewConfig(config),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  config.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  productPriceLabel(config.price),
                                  style: TextStyle(
                                    color: isPositiveProductPrice(config.price)
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => onViewConfig(config),
                        child: const Text('参数'),
                      ),
                      TextButton(
                        onPressed: () => onToggleCompare(config),
                        child: Text(selected ? '已选' : '对比'),
                      ),
                    ],
                  );
                });
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        Obx(
          () => TextButton(
            onPressed: onOpenComparison,
            child: Text('对比已选 (${comparison.selections.length})'),
          ),
        ),
      ],
    );
  }
}

/// Parameter details dialog for one config. Loads `configInfo` on
/// open; a per-dialog request counter drops stale results when a
/// retry supersedes an in-flight load, mirroring Costben's
/// `productRequest` guard. Failure shows title "参数加载失败" with
/// retry and close actions.
class ProductConfigDetailsDialog extends StatefulWidget {
  const ProductConfigDetailsDialog({super.key, required this.config});

  final ProductConfig config;

  @override
  State<ProductConfigDetailsDialog> createState() =>
      _ProductConfigDetailsDialogState();
}

class _ProductConfigDetailsDialogState
    extends State<ProductConfigDetailsDialog> {
  int _request = 0;
  bool _loading = true;
  String? _error;
  List<ProductSpecSection> _sections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body =
          await NetworkRepo.getProductConfigInfo(widget.config.id);
      final sections = productSpecSections(body);
      if (!mounted || request != _request) return;
      setState(() {
        _sections = sections;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = ApiFailure.fromError(e).message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // On failure the dialog title itself is "参数加载失败", mirroring
    // Costben's error dialog; otherwise it is the config title.
    final title = _error != null
        ? '参数加载失败'
        : (widget.config.title.isNotEmpty ? widget.config.title : '产品参数');
    return AlertDialog(
      title: Text(title),
      content: _loading
          ? const LoadingStatusView()
          : _error != null
              ? ErrorStatusView(
                  message: _error!,
                  onTap: _load,
                )
              : _sections.isEmpty
                  ? const EmptyStatusView(text: '暂无参数')
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 540),
                      child: ListView(
                        shrinkWrap: true,
                        children: _buildSectionWidgets(context),
                      ),
                    ),
    );
  }

  List<Widget> _buildSectionWidgets(BuildContext context) {
    final widgets = <Widget>[];
    final primary = Theme.of(context).colorScheme.primary;
    for (final section in _sections) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          child: Text(
            section.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
      );
      String? previousGroup;
      for (final item in section.items) {
        if (item.group != null &&
            item.group!.isNotEmpty &&
            item.group != previousGroup) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 0, 4),
              child: Text(
                item.group!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
        widgets.add(_SpecRow(name: item.name, value: item.value));
        previousGroup = item.group;
      }
    }
    return widgets;
  }
}

/// One name/value row in the details dialog: name and value split
/// roughly 0.38/0.62, with a divider underneath, mirroring Costben's
/// `SpecRow`.
class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.name, required this.value});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 38,
                child: Text(
                  name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 62,
                child: Text(value),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Fullscreen comparison dialog for the configs selected at open
/// time. Sections and rows are aligned by normalised key
/// ([mergeProductSections]); missing values show "—". The
/// "隐藏相同项" switch filters rows whose values do not differ.
/// Removing a column (✕ in its header) also removes it from the
/// process-wide selection.
class ProductComparisonDialog extends StatefulWidget {
  const ProductComparisonDialog({
    super.key,
    required this.selections,
    required this.comparison,
  });

  final List<ProductComparisonSelection> selections;
  final ProductComparisonController comparison;

  @override
  State<ProductComparisonDialog> createState() =>
      _ProductComparisonDialogState();
}

class _ProductComparisonDialogState extends State<ProductComparisonDialog> {
  int _request = 0;
  bool _loading = true;
  String? _error;
  List<ProductComparisonColumn> _columns = [];
  bool _hideSame = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final columns = await Future.wait(
        widget.selections.map((selection) async {
          final body = await NetworkRepo.getProductConfigInfo(
            selection.config.id,
          );
          return ProductComparisonColumn(
            selection: selection,
            sections: productSpecSections(body),
          );
        }),
      );
      if (!mounted || request != _request) return;
      setState(() {
        _columns = columns;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = ApiFailure.fromError(e).message;
        _loading = false;
      });
    }
  }

  void _removeColumn(String configId) {
    widget.comparison.remove(configId);
    setState(() {
      _columns = _columns
          .where((column) => column.selection.config.id != configId)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text('配置对比 + ${widget.selections.length} 款配置'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _loading
            ? const LoadingStatusView()
            : _error != null
                ? ErrorStatusView(
                    message: '对比加载失败',
                    onTap: _load,
                  )
                : _columns.isEmpty
                    ? const EmptyStatusView(text: '暂无可对比的配置')
                    : _buildComparisonBody(context),
      ),
    );
  }

  Widget _buildComparisonBody(BuildContext context) {
    var sections = mergeProductSections(_columns);
    if (_hideSame) {
      sections = sections
          .map((section) => ProductComparisonSection(
                title: section.title,
                items: section.items
                    .where((item) => productValuesDiffer(item.values))
                    .toList(),
              ))
          .where((section) => section.items.isNotEmpty)
          .toList();
    }
    final tableWidth =
        _parameterColumnWidth + _valueColumnWidth * _columns.length;
    return Column(
      children: [
        Row(
          children: [
            Switch(
              value: _hideSame,
              onChanged: (value) => setState(() => _hideSame = value),
            ),
            const Text('隐藏相同项'),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: ListView(
                children: [
                  _buildHeaderRow(context),
                  const Divider(height: 1),
                  for (final section in sections) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Text(
                        section.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ..._buildSectionRows(context, section),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: _parameterColumnWidth),
        for (final column in _columns)
          SizedBox(
            width: _valueColumnWidth,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          column.selection.config.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () =>
                            _removeColumn(column.selection.config.id),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    column.selection.productTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    productPriceLabel(column.selection.config.price),
                    style: TextStyle(
                      color: isPositiveProductPrice(
                        column.selection.config.price,
                      )
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildSectionRows(
    BuildContext context,
    ProductComparisonSection section,
  ) {
    final widgets = <Widget>[];
    String? previousGroup;
    for (final item in section.items) {
      if (item.group != null &&
          item.group!.isNotEmpty &&
          item.group != previousGroup) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
            child: Text(
              item.group!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
        widgets.add(const Divider(height: 1));
      }
      final differs = productValuesDiffer(item.values);
      widgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _parameterColumnWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  item.name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            for (final value in item.values)
              SizedBox(
                width: _valueColumnWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: differs && value != productMissingValue
                          ? FontWeight.w600
                          : null,
                      color: value == productMissingValue
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : differs
                              ? Theme.of(context).colorScheme.primary
                              : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
      widgets.add(const Divider(height: 1));
      previousGroup = item.group;
    }
    return widgets;
  }
}
