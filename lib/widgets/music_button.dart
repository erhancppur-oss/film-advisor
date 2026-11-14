import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../music/music_service.dart';

/// Top-bar button that turns background music on/off.
class MusicButton extends StatelessWidget {
  const MusicButton({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MusicService>();
    final s = S.of(context);
    return IconButton(
      tooltip: m.enabled ? s.t('music_off') : s.t('music_on'),
      color: color,
      icon: Icon(m.enabled ? Icons.music_note_rounded : Icons.music_off_rounded),
      onPressed: m.toggle,
    );
  }
}
