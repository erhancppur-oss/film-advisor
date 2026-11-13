import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../models/advisor.dart';
import '../models/media.dart';
import '../services/tmdb_api.dart';
import 'results_screen.dart';

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
    // interleave movies and shows
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
      // too strict: append results with loosened criteria
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

class AdvisorScreen extends StatefulWidget {
  const AdvisorScreen({super.key});

  @override
  State<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends State<AdvisorScreen> {
  final PageController _pages = PageController();
  AdvisorCriteria _c = AdvisorCriteria();
  int _step = 0;
  static const int _total = 8;
  Future<List<WatchProvider>>? _providersFuture;
  String? _providersKey;

  Future<List<WatchProvider>> _providers(TmdbApi api, MediaType type) {
    final key = '${type.name}_${api.region}';
    if (_providersFuture == null || _providersKey != key) {
      _providersKey = key;
      _providersFuture = api.watchProviders(type);
    }
    return _providersFuture!;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int step) {
    if (step < 0 || step >= _total) return;
    setState(() => _step = step);
    _pages.animateToPage(step,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  void _next() {
    if (_step == _total - 1) {
      _showResults();
    } else {
      _go(_step + 1);
    }
  }

  void _reset() {
    setState(() => _c = AdvisorCriteria());
    _go(0);
  }

  void _showResults() {
    final api = context.read<TmdbApi>();
    final feed = AdvisorFeed(api, _c.copy());
    final s = S.of(context);
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

    final steps = <Widget>[
      _contentStep(s),
      _moodStep(s),
      _genreStep(s),
      _eraStep(s),
      _runtimeStep(s),
      _qualityStep(s),
      _languageStep(s),
      _platformStep(s),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('adv_title')),
        actions: [
          TextButton(onPressed: _reset, child: Text(s.t('adv_reset'))),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _total,
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(s.t('adv_step', {'n': '${_step + 1}', 'total': '$_total'}),
                style: TextStyle(color: cs.outline, fontSize: 12)),
          ]),
        ),
        Expanded(
          child: PageView(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(),
            children: steps,
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

  // ------------------------------------------------------------------ steps

  Widget _stepScaffold(String title, {String? hint, required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      children: [
        Text(title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(hint, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
        const SizedBox(height: 20),
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
                  Text(title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
    return _stepScaffold(s.t('q_content'), hint: s.t('adv_intro'), children: [
      tile(ContentChoice.movie, 'content_movie', Icons.movie_rounded),
      tile(ContentChoice.tv, 'content_tv', Icons.live_tv_rounded),
      tile(ContentChoice.any, 'content_any', Icons.shuffle_rounded),
    ]);
  }

  Widget _moodStep(S s) {
    return _stepScaffold(s.t('q_mood'), children: [
      GridView.count(
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
              selected: _c.moodKey == m.key,
              onTap: () {
                setState(() => _c.moodKey = _c.moodKey == m.key ? null : m.key);
                if (_c.moodKey != null) _next();
              },
            ),
        ],
      ),
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
    return _stepScaffold(s.t('q_genres'), hint: s.t('q_genres_hint'), children: [
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
    return _stepScaffold(s.t('q_era'), children: [
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

    return _stepScaffold(s.t('q_runtime'), children: [
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
    return _stepScaffold(s.t('q_quality'), children: [
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
      const SizedBox(height: 4),
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
    return _stepScaffold(s.t('q_language'), children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in kLanguages)
          ChoiceChip(
            label: Text(s.t('lang_${l.key}')),
            selected: _c.language == l.code,
            onSelected: (_) {
              setState(() => _c.language = l.code);
            },
          ),
      ]),
    ]);
  }

  Widget _platformStep(S s) {
    final api = context.read<TmdbApi>();
    final type = _c.content == ContentChoice.tv ? MediaType.tv : MediaType.movie;
    return _stepScaffold(
      s.t('q_platform'),
      hint: s.t('q_platform_hint', {'region': api.region}),
      children: [
        FutureBuilder<List<WatchProvider>>(
          future: _providers(api, type),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(s.t(apiErrorKey(snap.error!)));
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final list = snap.data!.take(18).toList();
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
                  selected: _c.providers.contains(p.id),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _c.providers.add(p.id);
                    } else {
                      _c.providers.remove(p.id);
                    }
                  }),
                ),
            ]);
          },
        ),
      ],
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
