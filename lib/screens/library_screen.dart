import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../models/media.dart';
import '../state/library_state.dart';
import '../state/settings_state.dart';
import '../widgets/common.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lib = context.watch<LibraryState>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.t('nav_library')),
          bottom: TabBar(tabs: [
            Tab(text: '${s.t('tab_watchlist')} (${lib.watchlist.length})'),
            Tab(text: '${s.t('tab_watched')} (${lib.watched.length})'),
          ]),
        ),
        body: TabBarView(children: [
          _ListGrid(items: lib.watchlist, watchedTab: false),
          _ListGrid(items: lib.watched, watchedTab: true),
        ]),
      ),
    );
  }
}

class _ListGrid extends StatelessWidget {
  const _ListGrid({required this.items, required this.watchedTab});
  final List<MediaItem> items;
  final bool watchedTab;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (items.isEmpty) {
      return EmptyView(
        icon: watchedTab ? Icons.visibility_outlined : Icons.bookmark_border_rounded,
        text: watchedTab ? s.t('empty_watched') : s.t('empty_watchlist'),
        action: watchedTab
            ? null
            : FilledButton.icon(
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(s.t('go_advisor')),
                onPressed: () => context.read<SettingsState>().goToTab(2),
              ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.52,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => openDetail(context, m),
          onLongPress: () => _menu(context, m),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(AppConfig.poster(m.posterPath)),
                  Positioned(left: 4, top: 4, child: RatingBadge(m.voteAverage, small: true)),
                  Positioned(right: 4, top: 4, child: TypeChip(m.type)),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(10)),
                      child: InkWell(
                        onTap: () => _menu(context, m),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Text(m.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        );
      },
    );
  }

  void _menu(BuildContext context, MediaItem m) {
    final s = S.of(context);
    final lib = context.read<LibraryState>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(m.year),
          ),
          if (!watchedTab)
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: Text(s.t('move_watched')),
              onTap: () {
                lib.toggleWatched(m);
                Navigator.pop(ctx);
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: Text(s.t('move_watchlist')),
              onTap: () {
                lib.toggleWatched(m); // removes from watched
                lib.addToWatchlist(m);
                Navigator.pop(ctx);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: Text(s.t('remove')),
            onTap: () {
              lib.remove(m);
              Navigator.pop(ctx);
            },
          ),
        ]),
      ),
    );
  }
}
