import 'package:flutter/material.dart';

import '../../logic/model/feed/feed_price.dart';
import 'package:c001apk_flutter/constants/app_sizes.dart';

/// 动态卡片文本上方的价格行：左侧金额、旁边配置、右侧 listing 链接。
/// 价格与链接都不存在时不绘制。视觉跟随主线的 M3 配色与字号体系。
/// 移植自 Costben `ui/feed/FeedPriceRow.kt`（AGPL-3.0）。
class FeedPriceRow extends StatelessWidget {
  const FeedPriceRow({
    super.key,
    required this.price,
    this.link,
    this.onOpenLink,
  });

  final FeedPrice? price;
  final TradeLink? link;
  final ValueChanged<String>? onOpenLink;

  @override
  Widget build(BuildContext context) {
    if (price == null && link == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Row(
      children: [
        if (price != null) ...[
          Text(
            price!.label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 148),
            child: Text(
              price!.amount,
              style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              price!.configuration ?? '',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Spacer(),
        if (link != null)
          InkWell(
            onTap: () => onOpenLink?.call(link!.url),
            borderRadius: AppRadius.smallAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(link!.isXianyu ? Icons.storefront_outlined : Icons.link,
                    size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  link!.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

/// 「仅自己可见」徽标：官方客户端在时间旁展示同一把锁。
/// `publishStatus` 携带该状态，与审核状态无关。
/// 移植自 Costben `ui/feed/SelfOnlyBadge.kt`（AGPL-3.0）。
class SelfOnlyBadge extends StatelessWidget {
  const SelfOnlyBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.lock_outline,
          size: 12, color: theme.colorScheme.onSurfaceVariant),
      const SizedBox(width: 3),
      Text(
        '仅自己可见',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        maxLines: 1,
      ),
    ]);
  }
}
