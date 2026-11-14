import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../models/media.dart';
import '../services/tmdb_api.dart';
import '../state/library_state.dart';
import '../widgets/common.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  Future<PagedResult>? _future;
  late Future<PagedResult> _trending;

  @override
  void initState() {
    super.initState();
    _trending = context.read<TmdbApi>().trending(null, daily: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _run(v));
    setState(() {}); // update clear button
  }

  void _run(String v, {bool remember = false}) {
    final q = v.trim();
    if (!mounted) return;
    if (remember) context.read<LibraryState>().addRecentSearch(q);
    setState(() {
      _query = q;
      _future = q.length < 2 ? null : context.read<TmdbApi>().search(q);
    });
  }

  void _useSuggestion(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    _run(q, remember: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: TextField(
          controller: _ctrl,
          onChanged: _onChanged,
          onSubmitted: (v) => _run(v, remember: true),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: s.t('search_hint'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _ctrl.clear();
                      _run('');
                    },
                  ),
            filled: true,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      body: _query.length < 2 ? _suggestions(s) : _results(s),
    );
  }

  Widget _suggestions(S s) {
    final lib = context.watch<LibraryState>();
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      if (lib.recentSearches.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(children: [
            Expanded(
              child: Text(s.t('recent_searches'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            TextButton(onPressed: lib.clearRecentSearches, child: Text(s.t('clear'))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, runSpacing: 4, children: [
            for (final q in lib.recentSearches)
              ActionChip(
                avatar: const Icon(Icons.history_rounded, size: 16),
                label: Text(q),
                onPressed: () => _useSuggestion(q),
              ),
          ]),
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(s.t('trending_now'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      FutureBuilder<PagedResult>(
        future: _trending,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorView(
              error: snap.error!,
              compact: true,
              onRetry: () => setState(() {
                _trending = context.read<TmdbApi>().trending(null, daily: true);
              }),
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Column(
            children: [for (final m in snap.data!.items.take(15)) _ResultTile(item: m)],
          );
        },
      ),
    ]);
  }

  Widget _results(S s) {
    return FutureBuilder<PagedResult>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorView(error: snap.error!, onRetry: () => _run(_query));
        }
        final items = snap.data?.items ?? const <MediaItem>[];
        if (items.isEmpty) {
          return EmptyView(icon: Icons.search_off_rounded, text: s.t('no_results'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: items.length,
          itemBuilder: (_, i) => _ResultTile(
            item: items[i],
            onOpen: () => context.read<LibraryState>().addRecentSearch(_query),
          ),
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.item, this.onOpen});
  final MediaItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () {
        onOpen?.call();
        openDetail(context, item);
      },
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(width: 40, height: 60, child: NetImage(AppConfig.poster(item.posterPath, size: 'w154'))),
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Row(children: [
        TypeChip(item.type),
        const SizedBox(width: 8),
        if (item.year.isNotEmpty) Text(item.year, style: TextStyle(color: cs.outline)),
      ]),
      trailing: RatingBadge(item.voteAverage, small: true),
    );
  }
}
