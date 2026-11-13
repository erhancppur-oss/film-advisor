import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../models/media.dart';
import '../models/trends.dart';
import '../services/tmdb_api.dart';
import '../widgets/common.dart';

const _palettes = <List<Color>>[
  [Color(0xFF7C5CFF), Color(0xFFFF5CA8)],
  [Color(0xFF00B4DB), Color(0xFF0083B0)],
  [Color(0xFFFF8008), Color(0xFFFFC837)],
  [Color(0xFF11998E), Color(0xFF38EF7D)],
  [Color(0xFFEB3349), Color(0xFFF45C43)],
  [Color(0xFF4568DC), Color(0xFFB06AB3)],
  [Color(0xFF232526), Color(0xFF606C88)],
];

class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sections = buildTrendSections();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('trends_title'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _CustomListCard(),
          for (int i = 0; i < sections.length; i++) ...[
            SectionHeader(s.t(sections[i].titleKey)),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sections[i].items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, j) => _TrendCard(
                  def: sections[i].items[j],
                  colors: _palettes[(i * 3 + j) % _palettes.length],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.def, required this.colors});
  final TrendDef def;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SizedBox(
      width: 168,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RankedListScreen(def: def)),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: Stack(children: [
              Positioned(
                right: -6,
                bottom: -10,
                child: Opacity(
                  opacity: 0.35,
                  child: Text(def.emoji, style: const TextStyle(fontSize: 64)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(def.emoji, style: const TextStyle(fontSize: 22)),
                  const Spacer(),
                  Text(
                    def.title(s),
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
          ),
        ),
      ),
    );
  }
}

/// "Create your own list": actor, director, genre or topic.
class _CustomListCard extends StatefulWidget {
  const _CustomListCard();

  @override
  State<_CustomListCard> createState() => _CustomListCardState();
}

class _CustomListCardState extends State<_CustomListCard> {
  final _ctrl = TextEditingController();
  MediaType _type = MediaType.movie;
  int _n = 10;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    final s = S.of(context);
    final api = context.read<TmdbApi>();
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final def = await resolveCustomTrend(api, text, _n, _type);
      if (!mounted) return;
      if (def == null) {
        messenger.showSnackBar(SnackBar(content: Text(s.t('trend_not_found', {'q': text}))));
      } else {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => RankedListScreen(def: def)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.t(apiErrorKey(e)))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.playlist_add_rounded, color: cs.primary),
            const SizedBox(width: 8),
            Text(s.t('custom_list_title'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _create(),
            decoration: InputDecoration(
              hintText: s.t('custom_list_hint'),
              isDense: true,
              filled: true,
              fillColor: cs.surface,
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ChoiceChip(
              label: Text(s.t('movies')),
              selected: _type == MediaType.movie,
              onSelected: (_) => setState(() => _type = MediaType.movie),
            ),
            ChoiceChip(
              label: Text(s.t('series')),
              selected: _type == MediaType.tv,
              onSelected: (_) => setState(() => _type = MediaType.tv),
            ),
            DropdownButton<int>(
              value: _n,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              items: [
                for (final n in const [10, 20, 50, 100])
                  DropdownMenuItem(value: n, child: Text(s.t('top_n', {'n': '$n'}))),
              ],
              onChanged: (v) => setState(() => _n = v ?? 10),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(s.t('custom_list_go')),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Numbered list (#1, #2 …) of a trend.
class RankedListScreen extends StatefulWidget {
  const RankedListScreen({super.key, required this.def});
  final TrendDef def;

  @override
  State<RankedListScreen> createState() => _RankedListScreenState();
}

class _RankedListScreenState extends State<RankedListScreen> {
  late Future<List<MediaItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = loadTrend(context.read<TmdbApi>(), widget.def);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.def.title(s), maxLines: 2)),
      body: FutureBuilder<List<MediaItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(
              error: snap.error!,
              onRetry: () => setState(() {
                _future = loadTrend(context.read<TmdbApi>(), widget.def);
              }),
            );
          }
          final items = snap.data ?? const <MediaItem>[];
          if (items.isEmpty) {
            return EmptyView(icon: Icons.search_off_rounded, text: s.t('no_results'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = items[i];
              final medal = i == 0
                  ? const Color(0xFFFFC837)
                  : i == 1
                      ? const Color(0xFFC0C6CF)
                      : i == 2
                          ? const Color(0xFFCD7F32)
                          : cs.outline;
              return Material(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => openDetail(context, m),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${i + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: i < 3 ? 26 : 20, fontWeight: FontWeight.w900, color: medal),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 54,
                          height: 80,
                          child: NetImage(AppConfig.poster(m.posterPath, size: 'w154')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Row(children: [
                            TypeChip(m.type),
                            const SizedBox(width: 8),
                            if (m.year.isNotEmpty)
                              Text(m.year, style: TextStyle(color: cs.outline, fontSize: 12)),
                          ]),
                        ]),
                      ),
                      RatingBadge(m.voteAverage),
                      const SizedBox(width: 4),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
