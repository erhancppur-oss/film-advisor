import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/media.dart';
import '../state/library_state.dart';
import '../widgets/common.dart';
import '../widgets/media_row.dart';
import '../widgets/swipe_deck.dart';

/// Shows a stream of titles either as a swipe deck or as a grid.
/// Used by the advisor and by "Quick swipe".
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.title,
    required this.loader,
    this.isRelaxed,
    this.showHint = false,
    this.onChangeCriteria,
  });

  final String title;
  final PageLoader loader;
  final bool Function()? isRelaxed;
  final bool showHint;
  final VoidCallback? onChangeCriteria;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final List<MediaItem> _items = [];
  final Set<String> _keys = {};
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  bool _cardView = true;
  bool _hintShown = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final lib = context.read<LibraryState>();
    try {
      // Skip pages that contain only already-known titles (max 3 tries).
      int added = 0;
      for (int attempt = 0; attempt < 3 && added == 0 && _hasMore; attempt++) {
        _page++;
        final r = await widget.loader(_page);
        _hasMore = r.page < r.totalPages && r.items.isNotEmpty;
        for (final m in r.items) {
          if (!lib.isKnown(m) && _keys.add(m.key)) {
            _items.add(m);
            added++;
          }
        }
      }
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _like(MediaItem m) {
    final s = S.of(context);
    context.read<LibraryState>().addToWatchlist(m);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${s.t('added_watchlist')}: ${m.title}'),
        duration: const Duration(milliseconds: 1200),
      ));
  }

  void _skip(MediaItem m) => context.read<LibraryState>().dislike(m);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final relaxed = widget.isRelaxed?.call() ?? false;

    Widget body;
    if (_items.isEmpty && _loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty && _error != null) {
      body = ErrorView(error: _error!, onRetry: () {
        _hasMore = true;
        _page = _page > 0 ? _page - 1 : 0;
        _loadMore();
      });
    } else if (_items.isEmpty) {
      body = EmptyView(
        icon: Icons.search_off_rounded,
        text: s.t('results_none'),
        action: widget.onChangeCriteria == null
            ? null
            : FilledButton.icon(
                onPressed: widget.onChangeCriteria,
                icon: const Icon(Icons.tune_rounded),
                label: Text(s.t('change_criteria')),
              ),
      );
    } else if (_cardView) {
      body = SwipeDeck(
        key: const ValueKey('deck'),
        items: _items,
        onLike: _like,
        onSkip: _skip,
        onOpen: (m) => openDetail(context, m),
        onNearEnd: _loadMore,
        empty: _loading
            ? const Center(child: CircularProgressIndicator())
            : EmptyView(
                icon: Icons.done_all_rounded,
                text: s.t('swipe_empty'),
                action: widget.onChangeCriteria == null
                    ? null
                    : FilledButton.icon(
                        onPressed: widget.onChangeCriteria,
                        icon: const Icon(Icons.tune_rounded),
                        label: Text(s.t('change_criteria')),
                      ),
              ),
      );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 500) _loadMore();
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            mainAxisSpacing: 8,
            crossAxisSpacing: 10,
            childAspectRatio: 0.48,
          ),
          itemCount: _items.length,
          itemBuilder: (_, i) => MediaCard(item: _items[i], width: double.infinity, showType: true),
        ),
      );
    }

    final banners = <Widget>[
      if (relaxed && _items.isNotEmpty)
        _Banner(icon: Icons.info_outline_rounded, text: s.t('results_relaxed')),
      if (widget.showHint && !_hintShown && _cardView && _items.isNotEmpty)
        _Banner(
          icon: Icons.swipe_rounded,
          text: s.t('swipe_hint'),
          onClose: () => setState(() => _hintShown = true),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.onChangeCriteria != null)
            IconButton(
              tooltip: s.t('change_criteria'),
              icon: const Icon(Icons.tune_rounded),
              onPressed: widget.onChangeCriteria,
            ),
          IconButton(
            tooltip: _cardView ? s.t('view_list') : s.t('view_cards'),
            icon: Icon(_cardView ? Icons.grid_view_rounded : Icons.style_rounded),
            onPressed: () {
              final lib = context.read<LibraryState>();
              setState(() {
                // drop titles already swiped so the new deck starts fresh
                _items.removeWhere(lib.isKnown);
                _cardView = !_cardView;
              });
              if (_items.length < 5) _loadMore();
            },
          ),
        ],
      ),
      body: SafeArea(top: false, child: Column(children: [...banners, Expanded(child: body)])),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.onClose});
  final IconData icon;
  final String text;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: cs.onSecondaryContainer),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: cs.onSecondaryContainer, fontSize: 13)),
        ),
        if (onClose != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 18, color: cs.onSecondaryContainer),
            onPressed: onClose,
          ),
      ]),
    );
  }
}
