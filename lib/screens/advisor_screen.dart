import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../models/advisor.dart';
import '../models/media.dart';
import '../services/tmdb_api.dart';
import '../state/advisor_prefs.dart';
import '../state/library_state.dart';
import '../widgets/common.dart';
import 'results_screen.dart';

// ============================================================== feeds

/// Turns AdvisorCriteria into a paged stream of recommendations.
class AdvisorFeed {
  AdvisorFeed(this.api, this.criteria);

  final TmdbApi api;
  final AdvisorCriteria criteria;
  bool relaxed = false;
  final Map<MediaType, int> _totals = {};

  Future<PagedResult> _fetch(AdvisorCriteria c, int page) async {
    final types = c.types.where((t) => (_totals[t] ?? 1 << 20) >= page).toList();
    if (types.isEmpty) return PagedResult(const [], page: page, totalPages: page);
    final results = await Future.wait(
      types.map((t) => api.discover(t, c.toDiscoverParams(t, api.region), page: page)),
    );
    for (int i = 0; i < types.length; i++) {
      _totals[types[i]] = results[i].totalPages;
    }
    final merged = <MediaItem>[];
    final maxLen = results.fold<int>(0, (m, r) => max(m, r.items.length));
    for (int i = 0; i < maxLen; i++) {
      for (final r in results) {
        if (i < r.items.length) merged.add(r.items[i]);
      }
    }
    final totalPages = _totals.values.fold<int>(1, (m, v) => max(m, v));
    final totalResults = results.fold<int>(0, (s, r) => s + r.totalResults);
    return PagedResult(merged, page: page, totalPages: totalPages, totalResults: totalResults);
  }

  Future<PagedResult> load(int page) async {
    if (relaxed) return _fetch(criteria.relaxed(), page);
    final r = await _fetch(criteria, page);
    if (page == 1 && r.totalResults < 8) {
      relaxed = true;
      _totals.clear();
      final r2 = await _fetch(criteria.relaxed(), 1);
      final keys = r.items.map((e) => e.key).toSet();
      return PagedResult(
        [...r.items, ...r2.items.where((m) => !keys.contains(m.key))],
        page: 1,
        totalPages: r2.totalPages,
        totalResults: r.totalResults + r2.totalResults,
      );
    }
    return r;
  }
}

/// Recommendations built from the user's watchlist + watched titles.
class ProfileFeed {
  ProfileFeed(this.api, this.seeds);
  final TmdbApi api;
  final List<MediaItem> seeds;

  MediaType get _mainType {
    final movies = seeds.where((m) => m.type == MediaType.movie).length;
    return movies * 2 >= seeds.length ? MediaType.movie : MediaType.tv;
  }

  List<int> _topGenres(MediaType t) {
    final count = <int, int>{};
    for (final m in seeds.where((m) => m.type == t)) {
      for (final g in m.genreIds) {
        count[g] = (count[g] ?? 0) + 1;
      }
    }
    final sorted = count.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(2).map((e) => e.key).toList();
  }

  Future<PagedResult> load(int page) async {
    if (page == 1) {
      final lists = await Future.wait(seeds.take(10).map(
            (m) => api.recommendations(m.type, m.id).catchError((_) => const PagedResult([])),
          ));
      final score = <String, double>{};
      final byKey = <String, MediaItem>{};
      for (final r in lists) {
        for (int i = 0; i < r.items.length; i++) {
          final m = r.items[i];
          byKey[m.key] = m;
          score[m.key] = (score[m.key] ?? 0) + 1 + (20 - i) / 40 + m.voteAverage / 20;
        }
      }
      final keys = score.keys.toList()..sort((a, b) => score[b]!.compareTo(score[a]!));
      return PagedResult(keys.map((k) => byKey[k]!).toList(), page: 1, totalPages: 30);
    }
    final t = _mainType;
    final genres = _topGenres(t);
    return api.discover(t, {
      if (genres.isNotEmpty) 'with_genres': genres.join('|'),
      'sort_by': 'vote_average.desc',
      'vote_count.gte': t == MediaType.movie ? '1000' : '200',
    }, page: page - 1);
  }
}

/// "Something similar to X": TMDB recommendations + similar titles.
class SimilarFeed {
  SimilarFeed(this.api, this.item);
  final TmdbApi api;
  final MediaItem item;

  Future<PagedResult> load(int page) async {
    final res = await Future.wait([
      api.recommendations(item.type, item.id, page: page).catchError((_) => const PagedResult([])),
      api.similar(item.type, item.id, page: page).catchError((_) => const PagedResult([])),
    ]);
    final merged = <MediaItem>[];
    final seen = <String>{item.key};
    final n = max(res[0].items.length, res[1].items.length);
    for (int i = 0; i < n; i++) {
      for (final r in res) {
        if (i < r.items.length && seen.add(r.items[i].key)) merged.add(r.items[i]);
      }
    }
    return PagedResult(merged,
        page: page, totalPages: max(res[0].totalPages, res[1].totalPages).clamp(1, 5));
  }
}

// ============================================================== hub

class AdvisorScreen extends StatelessWidget {
  const AdvisorScreen({super.key});

  void _push(BuildContext context, Widget w) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  void _pickForMe(BuildContext context) {
    final s = S.of(context);
    final api = context.read<TmdbApi>();
    final lib = context.read<LibraryState>();
    final now = DateTime.now();
    final h = now.hour;
    final weekendNight = (now.weekday == DateTime.friday && h >= 17) ||
        now.weekday == DateTime.saturday ||
        (now.weekday == DateTime.sunday && h < 18);
    String when;
    List<String> moods;
    if (h < 5 || h >= 23) {
      when = 'late';
      moods = ['scare', 'thrill', 'mindbend'];
    } else if (h < 12) {
      when = 'morning';
      moods = ['feelgood', 'laugh', 'learn', 'escape'];
    } else if (h < 17) {
      when = 'afternoon';
      moods = ['adrenaline', 'escape', 'laugh', 'mindbend'];
    } else if (weekendNight) {
      when = 'weekend';
      moods = ['adrenaline', 'laugh', 'escape', 'thrill'];
    } else {
      when = 'evening';
      moods = ['thrill', 'mindbend', 'cry', 'adrenaline', 'romance'];
    }

    // Bias towards the user's favourite genre if we know it.
    final rnd = Random();
    final genreCount = <int, int>{};
    for (final m in lib.seeds) {
      for (final g in m.genreIds) {
        genreCount[g] = (genreCount[g] ?? 0) + 1;
      }
    }
    if (genreCount.isNotEmpty && rnd.nextBool()) {
      final fav = (genreCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
      final matching = kMoods.where((m) => m.movieGenres.contains(fav) || m.tvGenres.contains(fav));
      if (matching.isNotEmpty) moods = matching.map((m) => m.key).toList();
    }
    final moodKey = moods[rnd.nextInt(moods.length)];
    final mood = kMoods.firstWhere((m) => m.key == moodKey);
    final criteria = AdvisorCriteria(
      content: ContentChoice.any,
      moodKey: moodKey,
      minRating: 7,
      fame: rnd.nextBool() ? Fame.popular : Fame.acclaimed,
    );
    final feed = AdvisorFeed(api, criteria);
    _push(
      context,
      ResultsScreen(
        title: s.t('mode_pick'),
        loader: feed.load,
        isRelaxed: () => feed.relaxed,
        showHint: true,
        banner: s.t('pick_reason', {
          'when': s.t('when_$when'),
          'mood': '${mood.emoji} ${s.t('mood_$moodKey')}',
        }),
      ),
    );
  }

  void _profile(BuildContext context) {
    final s = S.of(context);
    final lib = context.read<LibraryState>();
    final seeds = [...lib.watchlist.take(6), ...lib.watched.take(6)];
    if (seeds.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.person_search_rounded),
          content: Text(s.t('profile_empty')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('ok'))),
          ],
        ),
      );
      return;
    }
    final feed = ProfileFeed(context.read<TmdbApi>(), seeds);
    _push(
      context,
      ResultsScreen(
        title: s.t('mode_profile'),
        loader: feed.load,
        showHint: true,
        banner: s.t('profile_reason', {'n': '${seeds.length}'}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final modes = <_Mode>[
      _Mode('mode_pick', '🎲', const [Color(0xFF7C5CFF), Color(0xFFFF5CA8)], () => _pickForMe(context)),
      _Mode('mode_profile', '👤', const [Color(0xFF11998E), Color(0xFF38EF7D)], () => _profile(context)),
      _Mode('mode_manual', '🎛️', const [Color(0xFF4568DC), Color(0xFFB06AB3)],
          () => _push(context, const ManualAdvisorScreen())),
      _Mode('mode_similar', '🔁', const [Color(0xFFFF8008), Color(0xFFFFC837)],
          () => _push(context, const SimilarAdvisorScreen())),
      _Mode('mode_mood', '😊', const [Color(0xFFEB3349), Color(0xFFF45C43)],
          () => _push(context, const MoodAdvisorScreen())),
      _Mode('mode_platform', '📺', const [Color(0xFF00B4DB), Color(0xFF0083B0)],
          () => _push(context, const PlatformAdvisorScreen())),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.t('adv_hub_title'))),
      body: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 600 ? 3 : 2;
        return GridView.count(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: [for (final m in modes) _ModeCard(mode: m)],
        );
      }),
    );
  }
}

class _Mode {
  final String key;
  final String emoji;
  final List<Color> colors;
  final VoidCallback onTap;
  _Mode(this.key, this.emoji, this.colors, this.onTap);
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode});
  final _Mode mode;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: mode.onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: mode.colors,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(mode.emoji, style: const TextStyle(fontSize: 28)),
            ),
            const Spacer(),
            Text(
              s.t(mode.key),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, height: 1.1),
            ),
            const SizedBox(height: 4),
            Text(
              s.t('${mode.key}_d'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.2),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============================================================== shared widgets

class _ContentSelector extends StatelessWidget {
  const _ContentSelector({required this.value, required this.onChanged});
  final ContentChoice value;
  final ValueChanged<ContentChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SegmentedButton<ContentChoice>(
      segments: [
        ButtonSegment(
            value: ContentChoice.any, label: Text(s.t('content_any')), icon: const Icon(Icons.shuffle)),
        ButtonSegment(
            value: ContentChoice.movie, label: Text(s.t('movies')), icon: const Icon(Icons.movie)),
        ButtonSegment(
            value: ContentChoice.tv, label: Text(s.t('series')), icon: const Icon(Icons.live_tv)),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (v) => onChanged(v.first),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

Widget _moodGrid(BuildContext context, String? selected, ValueChanged<String> onTap) {
  final s = S.of(context);
  return GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 2.3,
    children: [
      for (final m in kMoods)
        _MoodTile(
          emoji: m.emoji,
          label: s.t('mood_${m.key}'),
          selected: selected == m.key,
          onTap: () => onTap(m.key),
        ),
    ],
  );
}

// ============================================================== mood mode

class MoodAdvisorScreen extends StatefulWidget {
  const MoodAdvisorScreen({super.key});

  @override
  State<MoodAdvisorScreen> createState() => _MoodAdvisorScreenState();
}

class _MoodAdvisorScreenState extends State<MoodAdvisorScreen> {
  ContentChoice _content = ContentChoice.any;

  void _go(String moodKey) {
    final s = S.of(context);
    final feed = AdvisorFeed(
      context.read<TmdbApi>(),
      AdvisorCriteria(content: _content, moodKey: moodKey, minRating: 6.5, fame: Fame.popular),
    );
    final mood = kMoods.firstWhere((m) => m.key == moodKey);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultsScreen(
        title: '${mood.emoji} ${s.t('mood_$moodKey')}',
        loader: feed.load,
        isRelaxed: () => feed.relaxed,
        showHint: true,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('mode_mood'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(s.t('mood_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        _ContentSelector(value: _content, onChanged: (v) => setState(() => _content = v)),
        const SizedBox(height: 16),
        _moodGrid(context, null, _go),
      ]),
    );
  }
}

// ============================================================== similar mode

class SimilarAdvisorScreen extends StatefulWidget {
  const SimilarAdvisorScreen({super.key});

  @override
  State<SimilarAdvisorScreen> createState() => _SimilarAdvisorScreenState();
}

class _SimilarAdvisorScreenState extends State<SimilarAdvisorScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  Future<PagedResult>? _future;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _future = q.trim().length < 2 ? null : context.read<TmdbApi>().search(q.trim());
      });
    });
  }

  void _pick(MediaItem m) {
    final s = S.of(context);
    final feed = SimilarFeed(context.read<TmdbApi>(), m);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultsScreen(
        title: s.t('similar_title', {'title': m.title}),
        loader: feed.load,
        showHint: true,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('mode_similar'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: s.t('similar_hint'),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _future == null
              ? EmptyView(icon: Icons.compare_arrows_rounded, text: s.t('mode_similar_d'))
              : FutureBuilder<PagedResult>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) return ErrorView(error: snap.error!);
                    final items = snap.data?.items ?? const <MediaItem>[];
                    if (items.isEmpty) {
                      return EmptyView(icon: Icons.search_off_rounded, text: s.t('no_results'));
                    }
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final m = items[i];
                        return ListTile(
                          onTap: () => _pick(m),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 40,
                              height: 60,
                              child: NetImage(AppConfig.poster(m.posterPath, size: 'w154')),
                            ),
                          ),
                          title: Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Row(children: [
                            TypeChip(m.type),
                            const SizedBox(width: 8),
                            Text(m.year, style: TextStyle(color: cs.outline)),
                          ]),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        );
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ============================================================== platform mode

class _ProviderChips extends StatefulWidget {
  const _ProviderChips({required this.type, required this.selected, required this.onChanged});
  final MediaType type;
  final Map<int, String> selected;
  final ValueChanged<Map<int, String>> onChanged;

  @override
  State<_ProviderChips> createState() => _ProviderChipsState();
}

class _ProviderChipsState extends State<_ProviderChips> {
  late Future<List<WatchProvider>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<TmdbApi>().watchProviders(widget.type);
  }

  @override
  void didUpdateWidget(covariant _ProviderChips old) {
    super.didUpdateWidget(old);
    if (old.type != widget.type) _future = context.read<TmdbApi>().watchProviders(widget.type);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return FutureBuilder<List<WatchProvider>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorView(
            error: snap.error!,
            compact: true,
            onRetry: () => setState(() {
              _future = context.read<TmdbApi>().watchProviders(widget.type);
            }),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = snap.data!.take(20).toList();
        if (list.isEmpty) return Text(s.t('no_results'));
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in list)
            FilterChip(
              avatar: AppConfig.logo(p.logoPath) == null
                  ? null
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(AppConfig.logo(p.logoPath)!,
                          width: 24, height: 24, errorBuilder: (_, __, ___) => const SizedBox()),
                    ),
              label: Text(p.name),
              selected: widget.selected.containsKey(p.id),
              onSelected: (sel) {
                final m = Map<int, String>.of(widget.selected);
                if (sel) {
                  m[p.id] = p.name;
                } else {
                  m.remove(p.id);
                }
                widget.onChanged(m);
              },
            ),
        ]);
      },
    );
  }
}

class PlatformAdvisorScreen extends StatefulWidget {
  const PlatformAdvisorScreen({super.key});

  @override
  State<PlatformAdvisorScreen> createState() => _PlatformAdvisorScreenState();
}

class _PlatformAdvisorScreenState extends State<PlatformAdvisorScreen> {
  ContentChoice _content = ContentChoice.any;
  late Map<int, String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Map.of(context.read<AdvisorPrefs>().myPlatforms);
  }

  void _show() {
    final s = S.of(context);
    context.read<AdvisorPrefs>().setMyPlatforms(_selected);
    final feed = AdvisorFeed(
      context.read<TmdbApi>(),
      AdvisorCriteria(
        content: _content,
        providers: _selected.keys.toSet(),
        minRating: 6,
        fame: Fame.popular,
      ),
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultsScreen(
        title: s.t('mode_platform'),
        loader: feed.load,
        isRelaxed: () => feed.relaxed,
        showHint: true,
        banner: _selected.values.join(' · '),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = context.read<TmdbApi>();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('mode_platform'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(s.t('platform_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(s.t('q_platform_hint', {'region': api.region}),
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 16),
        _ContentSelector(value: _content, onChanged: (v) => setState(() => _content = v)),
        const SizedBox(height: 16),
        _ProviderChips(
          type: _content == ContentChoice.tv ? MediaType.tv : MediaType.movie,
          selected: _selected,
          onChanged: (m) => setState(() => _selected = m),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _selected.isEmpty ? null : _show,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(_selected.isEmpty ? s.t('platform_pick') : s.t('adv_show')),
          ),
        ),
      ),
    );
  }
}

// ============================================================== manual mode

class ManualAdvisorScreen extends StatefulWidget {
  const ManualAdvisorScreen({super.key, this.askAll = false});
  final bool askAll;

  @override
  State<ManualAdvisorScreen> createState() => _ManualAdvisorScreenState();
}

class _ManualAdvisorScreenState extends State<ManualAdvisorScreen> {
  final PageController _pages = PageController();
  late AdvisorCriteria _c;
  late List<String> _steps;
  final Set<String> _remember = {};
  final Map<int, String> _providerNames = {};
  int _step = 0;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<AdvisorPrefs>();
    _c = prefs.apply(AdvisorCriteria());
    _steps = widget.askAll
        ? List.of(kAdvisorSteps)
        : kAdvisorSteps.where((st) => !prefs.isSaved(st)).toList();
    _providerNames.addAll(prefs.myPlatforms);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  int get _total => _steps.length;

  void _go(int step) {
    if (step < 0 || step >= _total) return;
    setState(() => _step = step);
    _pages.animateToPage(step,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  void _next() {
    if (_step >= _total - 1) {
      _showResults();
    } else {
      _go(_step + 1);
    }
  }

  Future<void> _showResults() async {
    final s = S.of(context);
    final prefs = context.read<AdvisorPrefs>();
    final api = context.read<TmdbApi>();
    for (final st in _remember) {
      await prefs.save(st, _c, providerNames: _providerNames);
    }
    if (!mounted) return;
    final feed = AdvisorFeed(api, _c.copy());
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => ResultsScreen(
        title: s.t('results_title'),
        loader: feed.load,
        isRelaxed: () => feed.relaxed,
        showHint: true,
        onChangeCriteria: () => Navigator.of(ctx).pop(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final prefs = context.watch<AdvisorPrefs>();
    final skipped = widget.askAll ? 0 : prefs.savedSteps.length;

    if (_total == 0) {
      return Scaffold(
        appBar: AppBar(title: Text(s.t('mode_manual'))),
        body: EmptyView(
          icon: Icons.bookmark_added_rounded,
          text: s.t('all_remembered'),
          action: Column(mainAxisSize: MainAxisSize.min, children: [
            FilledButton.icon(
              onPressed: _showResults,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(s.t('adv_show')),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => const ManualAdvisorScreen(askAll: true),
              )),
              child: Text(s.t('ask_all_once')),
            ),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.t('mode_manual'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: (_step + 1) / _total, minHeight: 6),
              ),
            ),
            const SizedBox(width: 12),
            Text(s.t('adv_step', {'n': '${_step + 1}', 'total': '$_total'}),
                style: TextStyle(color: cs.outline, fontSize: 12)),
          ]),
        ),
        if (skipped > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Icon(Icons.bookmark_added_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(s.t('remembered_count', {'n': '$skipped'}),
                    style: TextStyle(fontSize: 12, color: cs.outline)),
              ),
            ]),
          ),
        Expanded(
          child: PageView(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (final st in _steps) _buildStep(st, s)],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              if (_step > 0)
                IconButton.outlined(
                  onPressed: () => _go(_step - 1),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: s.t('adv_back'),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _showResults,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(s.t('adv_show'), textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
                child: Text(_step == _total - 1 ? s.t('ok') : s.t('adv_next')),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildStep(String st, S s) {
    switch (st) {
      case 'content':
        return _contentStep(s);
      case 'mood':
        return _moodStep(s);
      case 'genres':
        return _genreStep(s);
      case 'era':
        return _eraStep(s);
      case 'runtime':
        return _runtimeStep(s);
      case 'quality':
        return _qualityStep(s);
      case 'language':
        return _languageStep(s);
      default:
        return _platformStep(s);
    }
  }

  Widget _stepScaffold(String step, String title, {String? hint, required List<Widget> children}) {
    final cs = Theme.of(context).colorScheme;
    final on = _remember.contains(step);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Text(title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(hint, style: TextStyle(color: cs.outline)),
        ],
        const SizedBox(height: 8),
        // "Remember this choice" tick
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => on ? _remember.remove(step) : _remember.add(step)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Checkbox(
                value: on,
                visualDensity: VisualDensity.compact,
                onChanged: (v) =>
                    setState(() => v == true ? _remember.add(step) : _remember.remove(step)),
              ),
              Expanded(
                child: Text(S.of(context).t('remember_choice'),
                    style: TextStyle(fontSize: 13, color: on ? cs.primary : cs.onSurfaceVariant)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _choiceTile({
    required String title,
    String? subtitle,
    String? emoji,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
            ),
            child: Row(children: [
              if (emoji != null) Text(emoji, style: const TextStyle(fontSize: 26)),
              if (icon != null) Icon(icon, size: 26, color: selected ? cs.primary : cs.onSurface),
              if (emoji != null || icon != null) const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (subtitle != null)
                    Text(subtitle, style: TextStyle(color: cs.outline, fontSize: 13)),
                ]),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: cs.primary),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _contentStep(S s) {
    Widget tile(ContentChoice c, String key, IconData icon) => _choiceTile(
          title: s.t(key),
          icon: icon,
          selected: _c.content == c,
          onTap: () {
            setState(() => _c.content = c);
            _next();
          },
        );
    return _stepScaffold('content', s.t('q_content'), hint: s.t('adv_intro'), children: [
      tile(ContentChoice.movie, 'content_movie', Icons.movie_rounded),
      tile(ContentChoice.tv, 'content_tv', Icons.live_tv_rounded),
      tile(ContentChoice.any, 'content_any', Icons.shuffle_rounded),
    ]);
  }

  Widget _moodStep(S s) {
    return _stepScaffold('mood', s.t('q_mood'), children: [
      _moodGrid(context, _c.moodKey, (k) {
        setState(() => _c.moodKey = _c.moodKey == k ? null : k);
        if (_c.moodKey != null) _next();
      }),
      const SizedBox(height: 12),
      _choiceTile(
        title: s.t('adv_skip'),
        icon: Icons.all_inclusive_rounded,
        selected: _c.moodKey == null,
        onTap: () {
          setState(() => _c.moodKey = null);
          _next();
        },
      ),
    ]);
  }

  Widget _genreStep(S s) {
    final cs = Theme.of(context).colorScheme;
    return _stepScaffold('genres', s.t('q_genres'), hint: s.t('q_genres_hint'), children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final g in kGenres)
          Builder(builder: (_) {
            final inc = _c.includeGenres.contains(g.key);
            final exc = _c.excludeGenres.contains(g.key);
            return FilterChip(
              label: Text(s.t('genre_${g.key}')),
              selected: inc || exc,
              showCheckmark: false,
              avatar: inc
                  ? Icon(Icons.check_rounded, size: 18, color: cs.primary)
                  : exc
                      ? Icon(Icons.close_rounded, size: 18, color: cs.error)
                      : null,
              selectedColor: exc ? cs.errorContainer : cs.primaryContainer,
              onSelected: (_) {
                setState(() {
                  if (inc) {
                    _c.includeGenres.remove(g.key);
                    _c.excludeGenres.add(g.key);
                  } else if (exc) {
                    _c.excludeGenres.remove(g.key);
                  } else {
                    _c.includeGenres.add(g.key);
                  }
                });
              },
            );
          }),
      ]),
    ]);
  }

  Widget _eraStep(S s) {
    return _stepScaffold('era', s.t('q_era'), children: [
      for (final e in Era.values)
        _choiceTile(
          title: s.t('era_${e.name}'),
          selected: _c.era == e,
          onTap: () {
            setState(() => _c.era = e);
            _next();
          },
        ),
    ]);
  }

  Widget _runtimeStep(S s) {
    String? sub(RuntimePref r) => r == RuntimePref.any ? null : s.t('rt_${r.name}_d');
    IconData icon(RuntimePref r) {
      switch (r) {
        case RuntimePref.any:
          return Icons.all_inclusive_rounded;
        case RuntimePref.short:
          return Icons.timer_outlined;
        case RuntimePref.medium:
          return Icons.schedule_rounded;
        case RuntimePref.long:
          return Icons.hourglass_bottom_rounded;
      }
    }

    return _stepScaffold('runtime', s.t('q_runtime'), children: [
      for (final r in RuntimePref.values)
        _choiceTile(
          title: s.t('rt_${r.name}'),
          subtitle: sub(r),
          icon: icon(r),
          selected: _c.runtime == r,
          onTap: () {
            setState(() => _c.runtime = r);
            _next();
          },
        ),
    ]);
  }

  Widget _qualityStep(S s) {
    final emojis = {Fame.popular: '🔥', Fame.acclaimed: '🏆', Fame.hidden: '💎'};
    return _stepScaffold('quality', s.t('q_quality'), children: [
      for (final f in Fame.values)
        _choiceTile(
          title: s.t('fame_${f.name}'),
          subtitle: s.t('fame_${f.name}_d'),
          emoji: emojis[f],
          selected: _c.fame == f,
          onTap: () => setState(() => _c.fame = f),
        ),
      const SizedBox(height: 8),
      Text(
        _c.minRating <= 0
            ? s.t('any_rating')
            : s.t('min_rating', {'r': _c.minRating.toStringAsFixed(1)}),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      Slider(
        value: _c.minRating,
        min: 0,
        max: 9,
        divisions: 18,
        label: _c.minRating.toStringAsFixed(1),
        onChanged: (v) => setState(() => _c.minRating = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Text('👨‍👩‍👧', style: TextStyle(fontSize: 24)),
        title: Text(s.t('q_kids')),
        subtitle: Text(s.t('q_kids_hint')),
        value: _c.withKids,
        onChanged: (v) => setState(() => _c.withKids = v),
      ),
    ]);
  }

  Widget _languageStep(S s) {
    return _stepScaffold('language', s.t('q_language'), children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in kLanguages)
          ChoiceChip(
            label: Text(s.t('lang_${l.key}')),
            selected: _c.language == l.code,
            onSelected: (_) => setState(() => _c.language = l.code),
          ),
      ]),
    ]);
  }

  Widget _platformStep(S s) {
    final api = context.read<TmdbApi>();
    final type = _c.content == ContentChoice.tv ? MediaType.tv : MediaType.movie;
    final selected = {for (final id in _c.providers) id: _providerNames[id] ?? '#$id'};
    return _stepScaffold(
      'platforms',
      s.t('q_platform'),
      hint: s.t('q_platform_hint', {'region': api.region}),
      children: [
        _ProviderChips(
          type: type,
          selected: selected,
          onChanged: (m) => setState(() {
            _c.providers = m.keys.toSet();
            _providerNames.addAll(m);
          }),
        ),
      ],
    );
  }
}
