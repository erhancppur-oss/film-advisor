import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../models/media.dart';
import 'common.dart';

/// Tinder-style card stack. Right = like, left = skip, tap = details.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.items,
    required this.onLike,
    required this.onSkip,
    required this.onOpen,
    this.onNearEnd,
    required this.empty,
  });

  final List<MediaItem> items;
  final void Function(MediaItem) onLike;
  final void Function(MediaItem) onSkip;
  final void Function(MediaItem) onOpen;
  final VoidCallback? onNearEnd;
  final Widget empty;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck> with SingleTickerProviderStateMixin {
  int _index = 0;
  Offset _drag = Offset.zero;
  late final AnimationController _ctrl;
  Animation<Offset>? _anim;
  bool _flyingOut = false;
  bool _liked = false;

  static const double _threshold = 110;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _ctrl.addListener(() {
      if (_anim != null) setState(() => _drag = _anim!.value);
    });
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && _flyingOut) {
        final item = widget.items[_index];
        setState(() {
          _index++;
          _drag = Offset.zero;
          _flyingOut = false;
        });
        if (_liked) {
          widget.onLike(item);
        } else {
          widget.onSkip(item);
        }
        if (widget.items.length - _index <= 4) widget.onNearEnd?.call();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _hasCard => _index < widget.items.length;

  void _animateTo(Offset target, {required bool flyOut, bool liked = false}) {
    _flyingOut = flyOut;
    _liked = liked;
    _anim = Tween<Offset>(begin: _drag, end: target)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward(from: 0);
  }

  void swipe(bool like) {
    if (!_hasCard || _ctrl.isAnimating) return;
    final w = MediaQuery.of(context).size.width;
    _animateTo(Offset(like ? w * 1.5 : -w * 1.5, 40), flyOut: true, liked: like);
  }

  void _onPanEnd(DragEndDetails d) {
    final w = MediaQuery.of(context).size.width;
    final vx = d.velocity.pixelsPerSecond.dx;
    if (_drag.dx > _threshold || vx > 900) {
      _animateTo(Offset(w * 1.5, _drag.dy), flyOut: true, liked: true);
    } else if (_drag.dx < -_threshold || vx < -900) {
      _animateTo(Offset(-w * 1.5, _drag.dy), flyOut: true, liked: false);
    } else {
      _animateTo(Offset.zero, flyOut: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (!_hasCard) return widget.empty;

    final cards = <Widget>[];
    final last = math.min(_index + 2, widget.items.length - 1);
    for (int i = last; i >= _index; i--) {
      final item = widget.items[i];
      final depth = i - _index;
      if (depth == 0) {
        final angle = _drag.dx / 900;
        final likeOpacity = (_drag.dx / _threshold).clamp(0.0, 1.0);
        final nopeOpacity = (-_drag.dx / _threshold).clamp(0.0, 1.0);
        cards.add(Transform.translate(
          offset: _drag,
          child: Transform.rotate(
            angle: angle,
            child: GestureDetector(
              onTap: () => widget.onOpen(item),
              onPanUpdate: (d) {
                if (_ctrl.isAnimating) return;
                setState(() => _drag += d.delta);
              },
              onPanEnd: (d) {
                if (_ctrl.isAnimating) return;
                _onPanEnd(d);
              },
              child: _SwipeCard(
                item: item,
                likeOpacity: likeOpacity.toDouble(),
                nopeOpacity: nopeOpacity.toDouble(),
                likeText: s.t('swipe_like'),
                nopeText: s.t('swipe_nope'),
              ),
            ),
          ),
        ));
      } else {
        final progress = (_drag.dx.abs() / _threshold).clamp(0.0, 1.0).toDouble();
        final scale = 1 - 0.05 * depth + (depth == 1 ? 0.05 * progress : 0);
        cards.add(Transform.translate(
          offset: Offset(0, 14.0 * depth - (depth == 1 ? 14 * progress : 0)),
          child: Transform.scale(
            scale: scale,
            child: IgnorePointer(child: _SwipeCard(item: item)),
          ),
        ));
      }
    }

    return Column(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Stack(alignment: Alignment.center, children: cards),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _RoundButton(
            icon: Icons.close_rounded,
            color: const Color(0xFFE5484D),
            onTap: () => swipe(false),
            tooltip: s.t('swipe_nope'),
          ),
          const SizedBox(width: 24),
          _RoundButton(
            icon: Icons.info_outline_rounded,
            color: Theme.of(context).colorScheme.secondary,
            small: true,
            onTap: () => widget.onOpen(widget.items[_index]),
            tooltip: 'Info',
          ),
          const SizedBox(width: 24),
          _RoundButton(
            icon: Icons.favorite_rounded,
            color: const Color(0xFF30A46C),
            onTap: () => swipe(true),
            tooltip: s.t('swipe_like'),
          ),
        ]),
      ),
    ]);
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.small = false,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 48.0 : 64.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: CircleBorder(side: BorderSide(color: color.withValues(alpha: 0.6), width: 2)),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: color, size: size * 0.48),
          ),
        ),
      ),
    );
  }
}

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({
    required this.item,
    this.likeOpacity = 0,
    this.nopeOpacity = 0,
    this.likeText = '',
    this.nopeText = '',
  });

  final MediaItem item;
  final double likeOpacity;
  final double nopeOpacity;
  final String likeText;
  final String nopeText;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          NetImage(AppConfig.poster(item.posterPath, size: 'w500')),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent, Color(0xE6000000)],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                TypeChip(item.type),
                const SizedBox(width: 6),
                RatingBadge(item.voteAverage),
                const SizedBox(width: 6),
                if (item.year.isNotEmpty)
                  Text(item.year,
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.15),
              ),
              if (item.overview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.overview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                ),
              ],
            ]),
          ),
          if (likeOpacity > 0)
            Positioned(
              top: 28,
              left: 20,
              child: Opacity(
                opacity: likeOpacity,
                child: _Stamp(text: likeText, color: const Color(0xFF30A46C), angle: -0.25),
              ),
            ),
          if (nopeOpacity > 0)
            Positioned(
              top: 28,
              right: 20,
              child: Opacity(
                opacity: nopeOpacity,
                child: _Stamp(text: nopeText, color: const Color(0xFFE5484D), angle: 0.25),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.text, required this.color, required this.angle});
  final String text;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 4),
          borderRadius: BorderRadius.circular(8),
          color: Colors.black26,
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
    );
  }
}
