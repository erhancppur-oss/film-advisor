import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../models/advisor.dart';
import '../models/media.dart';
import '../models/trends.dart';
import '../music/music_service.dart';
import '../services/tmdb_api.dart';
import '../widgets/common.dart';
import '../widgets/music_button.dart';

const _palettes = <List<Color>>[
  [Color(0xFF7C5CFF), Color(0xFFFF5CA8)],
  [Color(0xFF00B4DB), Color(0xFF0083B0)],
  [Color(0xFFFF8008), Color(0xFFFFC837)],
  [Color(0xFF11998E), Color(0xFF38EF7D)],
  [Color(0xFFEB3349), Color(0xFFF45C43)],
  [Color(0xFF4568DC), Color(0xFFB06AB3)],
  [Color(0xFF232526), Color(0xFF606C88)],
  [Color(0xFFDA4453), Color(0xFF89216B)],
];

void _openFilter(BuildContext context, ListFilter f) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => RankedListScreen.fromFilter(f)));
}

void _openDef(BuildContext context, TrendDef d) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => RankedListScreen.fromDef(d)));
}

// ===================================================================== screen

class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final curated = buildTrendSections();
    TrendSection sec(String key) => curated.firstWhere((c) => c.titleKey == key);
    final year = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('trends_title')), actions: const [MusicButton()]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const _ListBuilder(),
          // ---- all time
          SectionHeader(s.t('sec_all_time')),
          _CardRow(defs: sec('sec_all_time').items, palette: 0),
          // ---- by year
          SectionHeader(s.t('sec_by_year')),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: year - 1969,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final y = year - i;
                return _GradientTile(
                  width: 110,
                  colors: _palettes[i % _palettes.length],
                  onTap: () => _openFilter(context, ListFilter(year: y, n: 20)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$y',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                    Text(s.t('top_n', {'n': '20'}),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                );
              },
            ),
          ),
          // ---- by genre
          SectionHeader(s.t('sec_by_genre')),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kGenres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final g = kGenres[i];
                return _GradientTile(
                  width: 104,
                  colors: _palettes[(i + 3) % _palettes.length],
                  onTap: () => _openFilter(context, ListFilter(genre: g.key)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(kGenreEmoji[g.key] ?? '🎬', style: const TextStyle(fontSize: 34)),
                    const SizedBox(height: 4),
                    Text(s.t('genre_${g.key}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ]),
                );
              },
            ),
          ),
          // ---- actors
          SectionHeader(s.t('sec_popular_actors')),
          const _PopularActorsRow(),
          SectionHeader(s.t('sec_actors')),
          _PeopleRow(names: kLegendActors, director: false),
          SectionHeader(s.t('sec_turkish_stars')),
          _PeopleRow(names: kTurkishActors, director: false),
          // ---- directors
          SectionHeader(s.t('sec_directors')),
          _PeopleRow(names: [...kDirectors, ...kTurkishDirectors], director: true),
          // ---- countries
          SectionHeader(s.t('sec_by_country')),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kCountries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final c = kCountries[i];
                return _GradientTile(
                  width: 100,
                  colors: _palettes[(i + 5) % _palettes.length],
                  onTap: () => _openFilter(context, ListFilter(lang: c.lang, n: 20)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(c.flag, style: const TextStyle(fontSize: 34)),
                    const SizedBox(height: 4),
                    Text(s.t('lang_${c.lang}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ]),
                );
              },
            ),
          ),
          // ---- decades
          SectionHeader(s.t('sec_decades')),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 8,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final d = 2020 - i * 10;
                return _GradientTile(
                  width: 120,
                  colors: _palettes[(i + 1) % _palettes.length],
                  onTap: () => _openFilter(context, ListFilter(decade: d, n: 20)),
                  child: Center(
                    child: Text("${d}s",
                        style: const TextStyle(
                            color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  ),
                );
              },
            ),
          ),
          // ---- series & world
          SectionHeader(s.t('sec_world')),
          _CardRow(defs: sec('sec_world').items, palette: 2),
          SectionHeader(s.t('sec_topics')),
          _CardRow(defs: sec('sec_topics').items, palette: 4),
        ],
      ),
    );
  }
}

// ===================================================================== tiles

class _GradientTile extends StatelessWidget {
  const _GradientTile({required this.width, required this.colors, required this.onTap, required this.child});
  final double width;
  final List<Color> colors;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            ),
            padding: const EdgeInsets.all(8),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.defs, required this.palette});
  final List<TrendDef> defs;
  final int palette;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: defs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, j) {
          final d = defs[j];
          return _GradientTile(
            width: 168,
            colors: _palettes[(palette + j) % _palettes.length],
            onTap: () => _openDef(context, d),
            child: Stack(children: [
              Positioned(
                right: -8,
                bottom: -14,
                child: Opacity(opacity: 0.3, child: Text(d.emoji, style: const TextStyle(fontSize: 60))),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.emoji, style: const TextStyle(fontSize: 22)),
                  const Spacer(),
                  Text(
                    d.title(s),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      height: 1.15,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                    ),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// Round photo + name. Looks up the photo by name if needed.
class PersonAvatar extends StatefulWidget {
  const PersonAvatar({super.key, required this.person, required this.onTap, this.size = 72, this.selected = false});
  final PersonPick person;
  final ValueChanged<PersonPick> onTap;
  final double size;
  final bool selected;

  @override
  State<PersonAvatar> createState() => _PersonAvatarState();
}

class _PersonAvatarState extends State<PersonAvatar> {
  static final Map<String, PersonPick> _resolved = {};
  late PersonPick _p;

  @override
  void initState() {
    super.initState();
    _p = _resolved[widget.person.name] ?? widget.person;
    if (_p.profilePath == null) _resolve();
  }

  Future<void> _resolve() async {
    try {
      final j = await context.read<TmdbApi>().searchPerson(widget.person.name);
      if (j == null || !mounted) return;
      final p = PersonPick(widget.person.name,
          id: (j['id'] as num).toInt(), profilePath: j['profile_path'] as String?);
      _resolved[widget.person.name] = p;
      setState(() => _p = p);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.size + 12,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onTap(_p),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: widget.selected
                    ? [cs.primary, cs.primary]
                    : const [Color(0xFF7C5CFF), Color(0xFFFF5CA8)],
              ),
            ),
            child: ClipOval(
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: NetImage(AppConfig.profile(_p.profilePath), icon: Icons.person),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.person.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
                color: widget.selected ? cs.primary : null),
          ),
        ]),
      ),
    );
  }
}

class _PeopleRow extends StatelessWidget {
  const _PeopleRow({required this.names, required this.director});
  final List<String> names;
  final bool director;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: names.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) => PersonAvatar(
          person: PersonPick(names[i]),
          onTap: (p) => _openFilter(
            context,
            director ? ListFilter(director: p) : ListFilter(actor: p),
          ),
        ),
      ),
    );
  }
}

class _PopularActorsRow extends StatefulWidget {
  const _PopularActorsRow();

  @override
  State<_PopularActorsRow> createState() => _PopularActorsRowState();
}

class _PopularActorsRowState extends State<_PopularActorsRow> {
  late Future<List<Map<String, dynamic>>> _f;

  @override
  void initState() {
    super.initState();
    _f = context.read<TmdbApi>().popularPeople();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, compact: true);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (_, i) {
              final p = list[i];
              final pick = PersonPick((p['name'] as String?) ?? '',
                  id: (p['id'] as num).toInt(), profilePath: p['profile_path'] as String?);
              return PersonAvatar(person: pick, onTap: (pp) => _openFilter(context, ListFilter(actor: pp)));
            },
          );
        },
      ),
    );
  }
}

// ===================================================================== builder

class _ListBuilder extends StatefulWidget {
  const _ListBuilder();

  @override
  State<_ListBuilder> createState() => _ListBuilderState();
}

class _ListBuilderState extends State<_ListBuilder> {
  final ListFilter _f = ListFilter();

  Future<T?> _sheet<T>(Widget Function(BuildContext ctx) builder, {double height = 0.7}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(height: MediaQuery.of(ctx).size.height * height, child: builder(ctx)),
    );
  }

  Widget _sheetTitle(BuildContext ctx, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text(t, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      );

  Future<void> _pickGenre(S s) async {
    final r = await _sheet<String>((ctx) => Column(children: [
          _sheetTitle(ctx, s.t('f_genre')),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: [
                _ChoiceTile(emoji: '✨', label: s.t('all'), selected: _f.genre == null, onTap: () => Navigator.pop(ctx, '')),
                for (final g in kGenres)
                  if (g.idFor(_f.type) != null)
                    _ChoiceTile(
                      emoji: kGenreEmoji[g.key] ?? '🎬',
                      label: s.t('genre_${g.key}'),
                      selected: _f.genre == g.key,
                      onTap: () => Navigator.pop(ctx, g.key),
                    ),
              ],
            ),
          ),
        ]));
    if (r != null) setState(() => _f.genre = r.isEmpty ? null : r);
  }

  Future<void> _pickYear(S s) async {
    final now = DateTime.now().year;
    final r = await _sheet<String>((ctx) => Column(children: [
          _sheetTitle(ctx, s.t('f_year')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                label: Text(s.t('all')),
                selected: _f.year == null && _f.decade == null,
                onSelected: (_) => Navigator.pop(ctx, ''),
              ),
              for (int d = 2020; d >= 1950; d -= 10)
                ChoiceChip(
                  label: Text("${d}s"),
                  selected: _f.decade == d,
                  onSelected: (_) => Navigator.pop(ctx, 'd$d'),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              children: [
                for (int y = now; y >= 1950; y--)
                  _YearCell(year: y, selected: _f.year == y, onTap: () => Navigator.pop(ctx, 'y$y')),
              ],
            ),
          ),
        ]));
    if (r == null) return;
    setState(() {
      _f.year = null;
      _f.decade = null;
      if (r.startsWith('y')) _f.year = int.parse(r.substring(1));
      if (r.startsWith('d')) _f.decade = int.parse(r.substring(1));
    });
  }

  Future<void> _pickPerson(S s, {required bool director}) async {
    final api = context.read<TmdbApi>();
    Widget grid(BuildContext ctx, List<PersonPick> people) => GridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: 4,
          mainAxisSpacing: 6,
          crossAxisSpacing: 2,
          childAspectRatio: 0.66,
          children: [
            for (final p in people)
              PersonAvatar(
                person: p,
                size: 62,
                selected: (director ? _f.director : _f.actor)?.name == p.name,
                onTap: (pp) => Navigator.pop(ctx, pp),
              ),
          ],
        );
    final r = await _sheet<PersonPick>(
      (ctx) => DefaultTabController(
        length: director ? 2 : 3,
        child: Column(children: [
          _sheetTitle(ctx, director ? s.t('f_director') : s.t('f_actor')),
          TabBar(
            isScrollable: true,
            tabs: director
                ? [Tab(text: s.t('tab_world')), Tab(text: s.t('tab_turkish'))]
                : [Tab(text: s.t('tab_popular')), Tab(text: s.t('tab_legends')), Tab(text: s.t('tab_turkish'))],
          ),
          Expanded(
            child: TabBarView(
              children: director
                  ? [
                      grid(ctx, [for (final n in kDirectors) PersonPick(n)]),
                      grid(ctx, [for (final n in kTurkishDirectors) PersonPick(n)]),
                    ]
                  : [
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: api.popularPeople(),
                        builder: (c, snap) {
                          if (snap.hasError) return ErrorView(error: snap.error!);
                          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                          return grid(ctx, [
                            for (final p in snap.data!)
                              PersonPick((p['name'] as String?) ?? '',
                                  id: (p['id'] as num).toInt(), profilePath: p['profile_path'] as String?),
                          ]);
                        },
                      ),
                      grid(ctx, [for (final n in kLegendActors) PersonPick(n)]),
                      grid(ctx, [for (final n in kTurkishActors) PersonPick(n)]),
                    ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: () => Navigator.pop(ctx, const PersonPick('')),
              icon: const Icon(Icons.clear_rounded),
              label: Text(s.t('all')),
            ),
          ),
        ]),
      ),
      height: 0.85,
    );
    if (r == null) return;
    setState(() {
      final v = r.name.isEmpty ? null : r;
      if (director) {
        _f.director = v;
        if (v != null) _f.actor = null;
      } else {
        _f.actor = v;
        if (v != null) _f.director = null;
      }
    });
  }

  Future<void> _pickCountry(S s) async {
    final r = await _sheet<String>((ctx) => Column(children: [
          _sheetTitle(ctx, s.t('f_country')),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: [
                _ChoiceTile(emoji: '🌍', label: s.t('all'), selected: _f.lang == null, onTap: () => Navigator.pop(ctx, '')),
                for (final c in kCountries)
                  _ChoiceTile(
                    emoji: c.flag,
                    label: s.t('lang_${c.lang}'),
                    selected: _f.lang == c.lang,
                    onTap: () => Navigator.pop(ctx, c.lang),
                  ),
              ],
            ),
          ),
        ]));
    if (r != null) setState(() => _f.lang = r.isEmpty ? null : r);
  }

  Future<void> _pickSort(S s) async {
    const opts = {'best': '🏆', 'popular': '🔥', 'votes': '🗳️', 'newest': '🆕'};
    final r = await _sheet<String>(
      (ctx) => Column(children: [
        _sheetTitle(ctx, s.t('f_sort')),
        for (final e in opts.entries)
          ListTile(
            leading: Text(e.value, style: const TextStyle(fontSize: 24)),
            title: Text(s.t('sort_${e.key}')),
            trailing: _f.sort == e.key ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary) : null,
            onTap: () => Navigator.pop(ctx, e.key),
          ),
      ]),
      height: 0.45,
    );
    if (r != null) setState(() => _f.sort = r);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    String yearLabel() =>
        _f.year != null ? '${_f.year}' : (_f.decade != null ? "${_f.decade}s" : s.t('all'));
    String? countryFlag() {
      for (final c in kCountries) {
        if (c.lang == _f.lang) return c.flag;
      }
      return null;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primaryContainer, cs.surfaceContainerHigh],
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🎯', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.t('builder_title'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text(s.t('builder_sub'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        SegmentedButton<MediaType>(
          segments: [
            ButtonSegment(value: MediaType.movie, label: Text(s.t('movies')), icon: const Icon(Icons.movie)),
            ButtonSegment(value: MediaType.tv, label: Text(s.t('series')), icon: const Icon(Icons.live_tv)),
          ],
          selected: {_f.type},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() {
            _f.type = v.first;
            if (_f.genreId == null) _f.genre = null;
          }),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Pill(
            label: s.t('f_genre'),
            value: _f.genre == null ? s.t('all') : '${kGenreEmoji[_f.genre] ?? ''} ${s.t('genre_${_f.genre}')}',
            active: _f.genre != null,
            onTap: () => _pickGenre(s),
            onClear: () => setState(() => _f.genre = null),
          ),
          _Pill(
            label: s.t('f_year'),
            value: yearLabel(),
            active: _f.year != null || _f.decade != null,
            onTap: () => _pickYear(s),
            onClear: () => setState(() {
              _f.year = null;
              _f.decade = null;
            }),
          ),
          _Pill(
            label: s.t('f_actor'),
            value: _f.actor?.name ?? s.t('all'),
            active: _f.actor != null,
            onTap: () => _pickPerson(s, director: false),
            onClear: () => setState(() => _f.actor = null),
          ),
          _Pill(
            label: s.t('f_director'),
            value: _f.director?.name ?? s.t('all'),
            active: _f.director != null,
            onTap: () => _pickPerson(s, director: true),
            onClear: () => setState(() => _f.director = null),
          ),
          _Pill(
            label: s.t('f_country'),
            value: _f.lang == null ? s.t('all') : '${countryFlag() ?? ''} ${s.t('lang_${_f.lang}')}',
            active: _f.lang != null,
            onTap: () => _pickCountry(s),
            onClear: () => setState(() => _f.lang = null),
          ),
          _Pill(
            label: s.t('f_sort'),
            value: s.t('sort_${_f.sort}'),
            active: _f.sort != 'best',
            onTap: () => _pickSort(s),
            onClear: () => setState(() => _f.sort = 'best'),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Text(s.t('f_count'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final n in const [10, 20, 50, 100])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$n'),
                      selected: _f.n == n,
                      onSelected: (_) => setState(() => _f.n = n),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () => _openFilter(context, _f.copy()),
            icon: const Icon(Icons.format_list_numbered_rounded),
            label: Text(s.t('builder_go'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value, required this.active, required this.onTap, required this.onClear});
  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: active ? cs.primary : cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 6, active ? 4 : 12, 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  style: TextStyle(fontSize: 10.5, color: active ? cs.onPrimary.withValues(alpha: 0.8) : cs.outline)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5, color: active ? cs.onPrimary : cs.onSurface)),
              ),
            ]),
            if (active)
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                color: cs.onPrimary,
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.expand_more_rounded, size: 18, color: cs.outline),
              ),
          ]),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.emoji, required this.label, required this.selected, required this.onTap});
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _YearCell extends StatelessWidget {
  const _YearCell({required this.year, required this.selected, required this.onTap});
  final int year;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primary : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Center(
          child: Text('$year',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: selected ? cs.onPrimary : cs.onSurface)),
        ),
      ),
    );
  }
}

// ===================================================================== ranked list

/// Numbered list (#1, #2 …) with a backdrop header.
class RankedListScreen extends StatefulWidget {
  const RankedListScreen({super.key, required this.title, required this.loader, this.musicTheme});

  factory RankedListScreen.fromDef(TrendDef d) => RankedListScreen(
        title: d.title,
        loader: (api) => loadTrend(api, d),
        musicTheme: d.args['genre'] == null ? null : _genreTheme(d.args['genre']!),
      );

  factory RankedListScreen.fromFilter(ListFilter f) => RankedListScreen(
        title: f.title,
        loader: (api) => loadFilter(api, f),
        musicTheme: f.genre == null ? null : _genreTheme(f.genre!),
      );

  final String Function(S s) title;
  final Future<List<MediaItem>> Function(TmdbApi api) loader;
  final String? musicTheme;

  static String _genreTheme(String key) {
    for (final g in kGenres) {
      if (g.key == key) return themeForGenres([if (g.movieId != null) g.movieId!, if (g.tvId != null) g.tvId!]);
    }
    return 'ambient';
  }

  @override
  State<RankedListScreen> createState() => _RankedListScreenState();
}

class _RankedListScreenState extends State<RankedListScreen> with MusicTheme {
  late Future<List<MediaItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader(context.read<TmdbApi>());
    if (widget.musicTheme != null) startMusic(context.read<MusicService>(), widget.musicTheme!);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final title = widget.title(s);
    return Scaffold(
      body: FutureBuilder<List<MediaItem>>(
        future: _future,
        builder: (context, snap) {
          final items = snap.data ?? const <MediaItem>[];
          final hero = items.isEmpty ? null : items.first;
          final slivers = <Widget>[
            SliverAppBar(
              pinned: true,
              expandedHeight: 210,
              actions: const [MusicButton()],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 52, bottom: 14, end: 52),
                title: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                background: Stack(fit: StackFit.expand, children: [
                  if (hero != null) NetImage(AppConfig.backdrop(hero.backdropPath ?? hero.posterPath)),
                  if (hero == null)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF7C5CFF), Color(0xFFFF5CA8)]),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black45, Colors.transparent, cs.surface],
                        stops: const [0, 0.35, 1],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ];
          if (snap.connectionState != ConnectionState.done) {
            slivers.add(const SliverFillRemaining(child: Center(child: CircularProgressIndicator())));
          } else if (snap.hasError) {
            slivers.add(SliverFillRemaining(
              child: ErrorView(
                error: snap.error!,
                onRetry: () => setState(() => _future = widget.loader(context.read<TmdbApi>())),
              ),
            ));
          } else if (items.isEmpty) {
            slivers.add(SliverFillRemaining(
              child: EmptyView(icon: Icons.search_off_rounded, text: s.t('no_results')),
            ));
          } else {
            slivers.add(SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _RankRow(rank: i + 1, item: items[i]),
              ),
            ));
          }
          return CustomScrollView(slivers: slivers);
        },
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.item});
  final int rank;
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final medal = rank == 1
        ? const Color(0xFFFFC837)
        : rank == 2
            ? const Color(0xFFC0C6CF)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : null;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openDetail(context, item),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            SizedBox(
              width: 46,
              child: medal != null
                  ? Column(children: [
                      Icon(Icons.emoji_events_rounded, color: medal, size: 22),
                      Text('$rank',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: medal)),
                    ])
                  : Text('$rank',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.outline)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 58,
                height: 86,
                child: NetImage(AppConfig.poster(item.posterPath, size: 'w154')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Row(children: [
                  TypeChip(item.type),
                  const SizedBox(width: 8),
                  if (item.year.isNotEmpty) Text(item.year, style: TextStyle(color: cs.outline, fontSize: 12)),
                ]),
                if (item.overview.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                ],
              ]),
            ),
            const SizedBox(width: 6),
            RatingBadge(item.voteAverage),
            const SizedBox(width: 4),
          ]),
        ),
      ),
    );
  }
}
