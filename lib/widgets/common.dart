import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/media.dart';
import '../screens/detail_screen.dart';

void openDetail(BuildContext context, MediaItem item) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(item: item)));
}

/// Poster / backdrop image with graceful placeholder.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.icon = Icons.movie_outlined});

  final String? url;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(icon, color: cs.onSurfaceVariant.withValues(alpha: 0.5), size: 32),
    );
    if (url == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(color: cs.surfaceContainerHighest),
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

class RatingBadge extends StatelessWidget {
  const RatingBadge(this.rating, {super.key, this.small = false});
  final double rating;
  final bool small;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    final color = rating >= 7.5
        ? const Color(0xFF21D07A)
        : rating >= 6
            ? const Color(0xFFD2D531)
            : const Color(0xFFDB2360);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 7, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star_rounded, size: small ? 11 : 14, color: color),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: Colors.white,
            fontSize: small ? 10 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.compact = false});
  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final msg = s.t(apiErrorKey(error));
    final children = <Widget>[
      Icon(Icons.cloud_off_rounded,
          size: compact ? 24 : 48, color: Theme.of(context).colorScheme.outline),
      SizedBox(height: compact ? 6 : 12),
      Text(msg, textAlign: TextAlign.center),
      if (onRetry != null) ...[
        SizedBox(height: compact ? 4 : 12),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(s.t('retry')),
        ),
      ],
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onMore});
  final String title;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
      child: Row(children: [
        Expanded(
          child: Text(title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        if (onMore != null)
          TextButton(onPressed: onMore, child: Text(S.of(context).t('see_all'))),
      ]),
    );
  }
}

class TypeChip extends StatelessWidget {
  const TypeChip(this.type, {super.key});
  final MediaType type;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: type == MediaType.movie ? cs.primary : cs.tertiary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type == MediaType.movie ? s.t('movie') : s.t('tv'),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: type == MediaType.movie ? cs.onPrimary : cs.onTertiary,
        ),
      ),
    );
  }
}
