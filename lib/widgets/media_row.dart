import 'package:flutter/material.dart';

import '../config.dart';
import '../models/media.dart';
import '../screens/grid_screen.dart';
import 'common.dart';

typedef PageLoader = Future<PagedResult> Function(int page);

/// Poster tile used in horizontal rows and grids.
class MediaCard extends StatelessWidget {
  const MediaCard({super.key, required this.item, this.width = 120, this.showType = false});
  final MediaItem item;
  final double width;
  final bool showType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => openDetail(context, item),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(fit: StackFit.expand, children: [
                NetImage(AppConfig.poster(item.posterPath)),
                Positioned(left: 4, top: 4, child: RatingBadge(item.voteAverage, small: true)),
                if (showType) Positioned(right: 4, top: 4, child: TypeChip(item.type)),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (item.year.isNotEmpty)
            Text(item.year,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline)),
        ]),
      ),
    );
  }
}

/// A titled, horizontally scrollable row of posters.
class MediaRow extends StatefulWidget {
  const MediaRow({
    super.key,
    required this.title,
    required this.loader,
    this.showType = false,
    this.filter,
    this.hideWhenEmpty = true,
  });

  final String title;
  final PageLoader loader;
  final bool showType;
  final bool Function(MediaItem)? filter;
  final bool hideWhenEmpty;

  @override
  State<MediaRow> createState() => _MediaRowState();
}

class _MediaRowState extends State<MediaRow> {
  late Future<PagedResult> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader(1);
  }

  void _retry() => setState(() => _future = widget.loader(1));

  @override
  Widget build(BuildContext context) {
    const rowHeight = 250.0;
    return FutureBuilder<PagedResult>(
      future: _future,
      builder: (context, snap) {
        Widget body;
        if (snap.connectionState != ConnectionState.done) {
          body = ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => SizedBox(
              width: 120,
              child: Column(children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ]),
            ),
          );
        } else if (snap.hasError) {
          body = ErrorView(error: snap.error!, onRetry: _retry, compact: true);
        } else {
          var items = snap.data!.items;
          if (widget.filter != null) items = items.where(widget.filter!).toList();
          if (items.isEmpty && widget.hideWhenEmpty) return const SizedBox.shrink();
          body = ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => MediaCard(item: items[i], showType: widget.showType),
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(
            widget.title,
            onMore: (snap.hasData && snap.data!.hasMore)
                ? () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GridScreen(
                        title: widget.title,
                        loader: widget.loader,
                        showType: widget.showType,
                      ),
                    ))
                : null,
          ),
          SizedBox(height: rowHeight, child: body),
        ]);
      },
    );
  }
}

/// Builds a row from an already-available list (e.g. recommendations in details).
class StaticMediaRow extends StatelessWidget {
  const StaticMediaRow({super.key, required this.title, required this.items, this.showType = false});
  final String title;
  final List<MediaItem> items;
  final bool showType;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(title),
      SizedBox(
        height: 250,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => MediaCard(item: items[i], showType: showType),
        ),
      ),
    ]);
  }
}
