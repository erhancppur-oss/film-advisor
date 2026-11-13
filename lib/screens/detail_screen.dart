import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../models/media.dart';
import '../services/tmdb_api.dart';
import '../state/library_state.dart';
import '../widgets/common.dart';
import '../widgets/media_row.dart';

Future<void> openUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.of(context).t('err_generic'))));
  }
}

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.item});
  final MediaItem item;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<MediaDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<TmdbApi>().details(widget.item.type, widget.item.id);
  }

  void _retry() => setState(() {
        _future = context.read<TmdbApi>().details(widget.item.type, widget.item.id);
      });

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      body: FutureBuilder<MediaDetail>(
        future: _future,
        builder: (context, snap) {
          return CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 230,
              stretch: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  NetImage(AppConfig.backdrop(item.backdropPath ?? item.posterPath, size: 'w1280')),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                        stops: const [0, 0.4, 1],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(child: _Header(item: item, detail: snap.data)),
            if (snap.hasError)
              SliverToBoxAdapter(child: ErrorView(error: snap.error!, onRetry: _retry))
            else if (!snap.hasData)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else
              SliverToBoxAdapter(child: _Body(detail: snap.data!)),
          ]);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item, this.detail});
  final MediaItem item;
  final MediaDetail? detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final d = detail;
    final meta = <String>[
      if (item.year.isNotEmpty) item.year,
      if (d?.runtime != null) '${d!.runtime} ${s.t('min')}',
      if (d?.seasons != null && d!.seasons! > 0) s.t('seasons', {'n': '${d!.seasons}'}),
      if (d?.certification != null) d!.certification!,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: NetImage(AppConfig.poster(item.posterPath)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [TypeChip(item.type)]),
            const SizedBox(height: 6),
            Text(item.title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800, height: 1.15)),
            if (d?.tagline != null) ...[
              const SizedBox(height: 4),
              Text(d!.tagline!,
                  style: TextStyle(fontStyle: FontStyle.italic, color: cs.outline, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Text(meta.join('  •  '), style: TextStyle(color: cs.outline, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              RatingBadge(item.voteAverage),
              const SizedBox(width: 8),
              if (item.voteCount > 0)
                Text(s.t('votes', {'n': '${item.voteCount}'}),
                    style: TextStyle(color: cs.outline, fontSize: 12)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});
  final MediaDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final lib = context.watch<LibraryState>();
    final item = detail.item;
    final inList = lib.isInWatchlist(item);
    final watched = lib.isWatched(item);
    final trailer = detail.trailer;
    final region = context.read<TmdbApi>().region;
    final tmdbUrl =
        'https://www.themoviedb.org/${item.type == MediaType.movie ? 'movie' : 'tv'}/${item.id}';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (detail.genres.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final g in detail.genres)
              Chip(label: Text(g.name), visualDensity: VisualDensity.compact),
          ]),
        ),
      // ---- actions
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => lib.toggleWatchlist(item),
              icon: Icon(inList ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined),
              label: Text(inList ? s.t('watchlist_added') : s.t('watchlist_add'),
                  overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: (watched
                ? FilledButton.tonalIcon(
                    onPressed: () => lib.toggleWatched(item),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(s.t('watched'), overflow: TextOverflow.ellipsis),
                  )
                : OutlinedButton.icon(
                    onPressed: () => lib.toggleWatched(item),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(s.t('mark_watched'), overflow: TextOverflow.ellipsis),
                  )),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Wrap(spacing: 0, children: [
          if (trailer != null)
            TextButton.icon(
              onPressed: () => openUrl(context, trailer.url),
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: Text(s.t('trailer')),
            ),
          TextButton.icon(
            onPressed: () => openUrl(context, tmdbUrl),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(s.t('open_tmdb')),
          ),
          if (detail.imdbId != null)
            TextButton.icon(
              onPressed: () => openUrl(context, 'https://www.imdb.com/title/${detail.imdbId}/'),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(s.t('open_imdb')),
            ),
          if (!inList && !watched)
            TextButton.icon(
              onPressed: () {
                lib.dislike(item);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.t('not_interested_done'))));
              },
              icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
              label: Text(s.t('not_interested')),
            ),
        ]),
      ),
      // ---- overview
      _SectionTitle(s.t('overview')),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          detail.overview.trim().isEmpty ? s.t('no_overview') : detail.overview,
          style: const TextStyle(height: 1.45),
        ),
      ),
      if (detail.directors.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text:
                    '${item.type == MediaType.movie ? s.t('director') : s.t('creators')}: ',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: detail.directors.join(', ')),
          ])),
        ),
      if (detail.episodes != null && detail.episodes! > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            '${s.t('seasons', {'n': '${detail.seasons}'})} • ${s.t('episodes', {'n': '${detail.episodes}'})}',
            style: TextStyle(color: cs.outline),
          ),
        ),
      // ---- where to watch
      _SectionTitle(s.t('where_to_watch')),
      _WatchProviders(watch: detail.watch, region: region),
      // ---- cast
      if (detail.cast.isNotEmpty) ...[
        _SectionTitle(s.t('cast')),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: detail.cast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final c = detail.cast[i];
              return SizedBox(
                width: 80,
                child: Column(children: [
                  ClipOval(
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: NetImage(AppConfig.profile(c.profilePath), icon: Icons.person),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(c.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(c.character,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: cs.outline)),
                ]),
              );
            },
          ),
        ),
      ],
      StaticMediaRow(title: s.t('more_like_this'), items: detail.recommendations),
      StaticMediaRow(title: s.t('similar'), items: detail.similar),
      const SizedBox(height: 32),
    ]);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _WatchProviders extends StatelessWidget {
  const _WatchProviders({required this.watch, required this.region});
  final WatchAvailability watch;
  final String region;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    if (watch.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(s.t('where_none', {'region': region}), style: TextStyle(color: cs.outline)),
      );
    }
    Widget group(String label, List<WatchProvider> list) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 82,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in list)
                Tooltip(
                  message: p.name,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: NetImage(AppConfig.logo(p.logoPath), icon: Icons.tv),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: watch.link == null ? null : () => openUrl(context, watch.link!),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          group(s.t('wp_stream'), watch.stream),
          group(s.t('wp_free'), watch.free),
          group(s.t('wp_rent'), watch.rent),
          group(s.t('wp_buy'), watch.buy),
          Text(s.t('justwatch'), style: TextStyle(fontSize: 11, color: cs.outline)),
        ]),
      ),
    );
  }
}
