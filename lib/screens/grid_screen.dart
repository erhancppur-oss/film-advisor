import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/media.dart';
import '../widgets/common.dart';
import '../widgets/media_row.dart';

/// Infinite scrolling poster grid for "See all".
class GridScreen extends StatefulWidget {
  const GridScreen({super.key, required this.title, required this.loader, this.showType = false});
  final String title;
  final PageLoader loader;
  final bool showType;

  @override
  State<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends State<GridScreen> {
  final List<MediaItem> _items = [];
  final Set<String> _keys = {};
  final ScrollController _scroll = ScrollController();
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.loader(_page + 1);
      if (!mounted) return;
      setState(() {
        _page = r.page;
        _hasMore = r.hasMore && r.items.isNotEmpty;
        for (final m in r.items) {
          if (_keys.add(m.key)) _items.add(m);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget body;
    if (_items.isEmpty && _error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (_items.isEmpty && _loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty) {
      body = EmptyView(icon: Icons.movie_filter_outlined, text: s.t('no_results'));
    } else {
      body = GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          mainAxisSpacing: 8,
          crossAxisSpacing: 10,
          childAspectRatio: 0.48,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ));
          }
          return MediaCard(item: _items[i], width: double.infinity, showType: widget.showType);
        },
      );
    }
    return Scaffold(appBar: AppBar(title: Text(widget.title)), body: body);
  }
}
