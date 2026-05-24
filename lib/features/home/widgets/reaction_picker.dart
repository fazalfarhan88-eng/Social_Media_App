import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:iconsax/iconsax.dart';

class ReactionPicker extends StatefulWidget {
  final Function(String) onReact;
  final String currentReaction;
  
  const ReactionPicker({super.key, required this.onReact, this.currentReaction = ''});

  @override
  State<ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<ReactionPicker> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  OverlayEntry? _overlayEntry;

  final Map<String, String> _reactions = {
    'like': '👍',
    'love': '❤️',
    'haha': '😂',
    'sad': '😢',
    'angry': '😡',
  };

  void _playReactionSound(String type) async {
    String soundFile = '';
    switch(type) {
      case 'like': soundFile = 'sounds/like_pop.mp3'; break;
      case 'love': soundFile = 'sounds/love_heartbeat.mp3'; break;
      case 'haha': soundFile = 'sounds/haha_laugh.mp3'; break;
      case 'sad': soundFile = 'sounds/sad_piano.mp3'; break;
      case 'angry': soundFile = 'sounds/angry_growl.mp3'; break;
    }
    try {
      debugPrint('Playing reaction sound: $soundFile');
      await _audioPlayer.play(AssetSource(soundFile));
    } catch (e) {
      debugPrint('SOUND ERROR (Expected if files are placeholders): $e');
    }
  }

  void _showOverlay(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final theme = Theme.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: _hideOverlay,
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy - 60,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _reactions.entries.map((entry) => GestureDetector(
                      onTap: () {
                        _playReactionSound(entry.key);
                        widget.onReact(entry.key);
                        _hideOverlay();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(entry.value, style: const TextStyle(fontSize: 32)),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      }
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool hasReaction = widget.currentReaction.isNotEmpty;

    return GestureDetector(
      onLongPress: () => _showOverlay(context),
      onTap: () {
        _playReactionSound('like');
        widget.onReact('like');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: hasReaction ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            if (!hasReaction) ...[
              const Icon(Iconsax.heart, size: 22),
              const SizedBox(width: 8),
              const Text("React", style: TextStyle(fontWeight: FontWeight.bold)),
            ] else ...[
              Text(_reactions[widget.currentReaction] ?? '', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                widget.currentReaction.toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
