import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/media.dart';
import '../services/tmdb_api.dart';
import 'common.dart';

typedef CoverLoader = Future<String?> Function(TmdbApi api);

/// Caches the backdrop chosen for each tile so scrolling never re-queries.
class CoverCache {
  static final Map<String, Future<String?>> _m = {};

  static Future<String?> get(String key, TmdbApi api, CoverLoader loader) =>
      _m.putIfAbsent(key, () => loader(api).catchError((_) => null));
}

/// First (or [pick]-th) backdrop of a result page.
Future<String?> backdropOf(Future<PagedResult> page, {int pick = 0}) async {
  final items = (await page).items.where((m) => m.backdropPath != null).toList();
  if (items.isEmpty) return null;
  return items[pick % items.length].backdropPath;
}

/// Cover from a /discover query.
CoverLoader discoverCover(MediaType type, Map<String, String> params, {int pick = 0}) =>
    (api) => backdropOf(api.discover(type, params), pick: pick);

/// Image tile with a cinematic dark gradient and text on top.
class CoverTile extends StatelessWidget {
  const CoverTile({
    super.key,
    required this.coverKey,
    required this.loader,
    required this.title,
    this.subtitle,
    this.icon,
    this.badge,
    this.width,
    this.height,
    this.onTap,
    this.selected = false,
    this.bigTitle = false,
    this.centered = false,
    this.radius = 16,
  });

  final String coverKey;
  final CoverLoader loader;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? badge; // e.g. a flag
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool selected;
  final bool bigTitle;
  final bool centered;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final api = context.read<TmdbApi>();
    final text = Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.end,
      children: [
        if (!centered) const Spacer(),
        Text(
          title,
          maxLines: bigTitle ? 1 : 2,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: bigTitle ? FontWeight.w900 : FontWeight.w800,
            fontSize: bigTitle ? 26 : 14,
            height: 1.15,
            letterSpacing: bigTitle ? 0.5 : 0,
            shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.2)),
        ],
      ],
    );

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(fit: StackFit.expand, children: [
            FutureBuilder<String?>(
              future: CoverCache.get(coverKey, api, loader),
              builder: (_, snap) => snap.data == null
                  ? const SizedBox.shrink()
                  : NetImage(AppConfig.backdrop(snap.data, size: 'w780')),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: centered
                      ? const [Color(0x66000000), Color(0x99000000)]
                      : const [Color(0x1A000000), Color(0x33000000), Color(0xE6000000)],
                ),
              ),
            ),
            if (selected)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: cs.primary, width: 3),
                ),
              ),
            if (icon != null || badge != null)
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: badge != null
                      ? Text(badge!, style: const TextStyle(fontSize: 14))
                      : Icon(icon, size: 16, color: Colors.white),
                ),
              ),
            Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), child: text),
          ]),
        ),
      ),
    );
  }
}
