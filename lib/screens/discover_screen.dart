import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/media.dart';
import '../services/tmdb_api.dart';
import '../state/library_state.dart';
import '../widgets/common.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/media_row.dart';
import 'results_screen.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return DefaultTabController(
      length: 2,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: Row(children: [
              const Icon(Icons.movie_filter_rounded),
              const SizedBox(width: 8),
              Text('Film Advisor', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            actions: [
              IconButton(
                tooltip: s.t('quick_swipe'),
                icon: const Icon(Icons.swipe_rounded),
                onPressed: () => _openQuickSwipe(context),
              ),
              IconButton(
                tooltip: s.t('surprise_me'),
                icon: const Icon(Icons.casino_rounded),
                onPressed: () => _surprise(context),
              ),
            ],
            bottom: TabBar(tabs: [Tab(text: s.t('movies')), Tab(text: s.t('series'))]),
          ),
          body: const TabBarView(children: [
            _Feed(type: MediaType.movie),
            _Feed(type: MediaType.tv),
          ]),
        );
      }),
    );
  }

  MediaType _currentType(BuildContext context) {
    final idx = DefaultTabController.of(context).index;
    return idx == 0 ? MediaType.movie : MediaType.tv;
  }

  void _openQuickSwipe(BuildContext context) {
    final api = context.read<TmdbApi>();
    final type = _currentType(context);
    // Start at a random page so every session feels fresh.
    final offset = Random().nextInt(5);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultsScreen(
        title: S.of(context).t('quick_swipe'),
        loader: (page) => api.discover(type, {
          'sort_by': 'popularity.desc',
          'vote_count.gte': type == MediaType.movie ? '300' : '100',
          'vote_average.gte': '6',
        }, page: page + offset),
        showHint: true,
      ),
    ));
  }

  Future<void> _surprise(BuildContext context) async {
    final s = S.of(context);
    final api = context.read<TmdbApi>();
    final lib = context.read<LibraryState>();
    final type = _currentType(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        SnackBar(content: Text(s.t('surprise_loading')), duration: const Duration(seconds: 1)));
    try {
      final rnd = Random();
      final r = await api.discover(type, {
        'sort_by': 'popularity.desc',
        'vote_count.gte': type == MediaType.movie ? '1000' : '300',
        'vote_average.gte': '7',
      }, page: 1 + rnd.nextInt(15));
      final pool = r.items.where((m) => !lib.isKnown(m)).toList();
      if (pool.isEmpty) return;
      final pick = pool[rnd.nextInt(pool.length)];
      if (context.mounted) openDetail(context, pick);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.t(apiErrorKey(e)))));
    }
  }
}

class _Feed extends StatefulWidget {
  const _Feed({required this.type});
  final MediaType type;

  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed> with AutomaticKeepAliveClientMixin {
  int _generation = 0;
  late Future<PagedResult> _hero;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _hero = context.read<TmdbApi>().trending(widget.type);
  }

  Future<void> _refresh() async {
    final api = context.read<TmdbApi>();
    api.clearCache();
    setState(() {
      _generation++;
      _hero = api.trending(widget.type);
    });
    await _hero.catchError((_) => const PagedResult([]));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final api = context.read<TmdbApi>();
    final lib = context.read<LibraryState>();
    final t = widget.type;
    final isMovie = t == MediaType.movie;
    final seeds = lib.seeds.where((m) => m.type == t).take(3).toList();

    Future<PagedResult> disc(Map<String, String> p, int page) => api.discover(t, p, page: page);

    final rows = <Widget>[
      FutureBuilder<PagedResult>(
        future: _hero,
        builder: (context, snap) {
          if (snap.hasError) {
            return SizedBox(height: 220, child: ErrorView(error: snap.error!, onRetry: _refresh));
          }
          if (!snap.hasData) {
            return const SizedBox(height: 230, child: Center(child: CircularProgressIndicator()));
          }
          final items =
              snap.data!.items.where((m) => m.backdropPath != null).take(8).toList();
          return HeroCarousel(items: items);
        },
      ),
      if (seeds.isNotEmpty)
        MediaRow(
          title: s.t('sec_for_you'),
          loader: (page) async {
            final results = await Future.wait(
              seeds.map((m) => api.recommendations(t, m.id).catchError((_) => const PagedResult([]))),
            );
            final seen = <String>{};
            final merged = <MediaItem>[];
            // interleave recommendations of every seed
            for (int i = 0; i < 20; i++) {
              for (final r in results) {
                if (i < r.items.length) {
                  final m = r.items[i];
                  if (!lib.isKnown(m) && seen.add(m.key)) merged.add(m);
                }
              }
            }
            return PagedResult(merged);
          },
        ),
      MediaRow(title: s.t('sec_trending'), loader: (p) => api.trending(t, page: p)),
      if (isMovie)
        MediaRow(
            title: s.t('sec_now_playing'), loader: (p) => api.category(t, 'now_playing', page: p))
      else
        MediaRow(title: s.t('sec_on_air'), loader: (p) => api.category(t, 'on_the_air', page: p)),
      MediaRow(title: s.t('sec_popular'), loader: (p) => api.category(t, 'popular', page: p)),
      MediaRow(
        title: isMovie ? s.t('sec_turkish_movies') : s.t('sec_turkish_series'),
        loader: (p) => disc({
          'with_original_language': 'tr',
          'sort_by': 'popularity.desc',
          'vote_count.gte': isMovie ? '20' : '5',
        }, p),
      ),
      MediaRow(title: s.t('sec_top_rated'), loader: (p) => api.category(t, 'top_rated', page: p)),
      if (isMovie) ...[
        MediaRow(title: s.t('sec_upcoming'), loader: (p) => api.category(t, 'upcoming', page: p)),
        MediaRow(
          title: s.t('sec_comedy'),
          loader: (p) => disc(
              {'with_genres': '35', 'sort_by': 'popularity.desc', 'vote_count.gte': '300'}, p),
        ),
        MediaRow(
          title: s.t('sec_scifi'),
          loader: (p) => disc(
              {'with_genres': '878|14', 'sort_by': 'popularity.desc', 'vote_count.gte': '300'}, p),
        ),
        MediaRow(
          title: s.t('sec_horror'),
          loader: (p) => disc(
              {'with_genres': '27', 'sort_by': 'popularity.desc', 'vote_count.gte': '300'}, p),
        ),
      ] else ...[
        MediaRow(
          title: s.t('sec_korean'),
          loader: (p) => disc({
            'with_original_language': 'ko',
            'with_genres': '18',
            'sort_by': 'popularity.desc',
            'vote_count.gte': '20',
          }, p),
        ),
        MediaRow(
          title: s.t('sec_anime'),
          loader: (p) => disc({
            'with_original_language': 'ja',
            'with_genres': '16',
            'sort_by': 'popularity.desc',
            'vote_count.gte': '50',
          }, p),
        ),
      ],
      MediaRow(
        title: s.t('sec_docs'),
        loader: (p) => disc({
          'with_genres': '99',
          'sort_by': 'popularity.desc',
          'vote_count.gte': isMovie ? '100' : '20',
        }, p),
      ),
      const SizedBox(height: 24),
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: ValueKey('feed_${t.name}_$_generation'),
        padding: EdgeInsets.zero,
        children: rows,
      ),
    );
  }
}
