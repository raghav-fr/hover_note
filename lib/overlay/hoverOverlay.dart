import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

enum OverlayMode { expanded, bubble }

class HoverOverlay extends StatefulWidget {
  const HoverOverlay({super.key});

  @override
  State<HoverOverlay> createState() => _HoverOverlayState();
}

class _HoverOverlayState extends State<HoverOverlay> {
  // Each note is stored by its ID
  final Map<int, _OverlayNote> _notes = {};

  @override
  void initState() {
    super.initState();

    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is! Map) return;

      final String? command = data["command"];

      setState(() {
        if (command == "add") {
          final int id = data["id"];
          if (_notes.containsKey(id)) {
            _notes[id]!.text = data["text"] ?? _notes[id]!.text;
            _notes[id]!.color = data["color"] ?? _notes[id]!.color;
          } else {
            _notes[id] = _OverlayNote(
              id: id,
              text: data["text"] ?? "",
              color: data["color"] ?? 0xFF000000,
              mode: OverlayMode.expanded,
            );
          }
        } else if (command == "remove") {
          final int id = data["id"];
          _notes.remove(id);
          if (_notes.isEmpty) {
            FlutterOverlayWindow.closeOverlay();
          }
        }
      });
    });
  }

  void _minimizeNote(int id) {
    setState(() {
      _notes[id]?.mode = OverlayMode.bubble;
    });
  }

  void _expandNote(int id) {
    setState(() {
      _notes[id]?.mode = OverlayMode.expanded;
    });
  }

  Future<void> _closeNote(int id) async {
    setState(() {
      _notes.remove(id);
    });
    await FlutterOverlayWindow.shareData({
      'command': 'overlay_closed',
      'id': id,
    });
    if (_notes.isEmpty) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  void _openEditPage(int id) async {
    await FlutterOverlayWindow.shareData({
      'command': 'open_edit_page',
      'id': id,
    });
    _closeNote(id);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Listener(
          onPointerHover: (_) {},
          onPointerDown: (_) {},
          onPointerUp: (_) {},
          child: child!,
        );
      },
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _notes.values.map((note) {
              return GestureDetector(
                onTap: () {
                  if (note.mode == OverlayMode.bubble) {
                    _expandNote(note.id);
                  }
                },
                onDoubleTap: () {
                  if (note.mode == OverlayMode.expanded) {
                    _openEditPage(note.id);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: note.mode == OverlayMode.bubble
                        ? _BubbleView(
                            key: ValueKey("bubble_${note.id}"),
                            color: note.color,
                          )
                        : _ExpandedView(
                            key: ValueKey("expanded_${note.id}"),
                            text: note.text,
                            color: note.color,
                            onMinimize: () => _minimizeNote(note.id),
                            onClose: () => _closeNote(note.id),
                          ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/* ----------- Data class for each overlay note ----------- */

class _OverlayNote {
  final int id;
  String text;
  int color;
  OverlayMode mode;

  _OverlayNote({
    required this.id,
    required this.text,
    required this.color,
    required this.mode,
  });
}

/* ---------------- Expanded View ---------------- */

class _ExpandedView extends StatelessWidget {
  final String text;
  final int color;
  final VoidCallback onMinimize;
  final VoidCallback onClose;

  const _ExpandedView({
    super.key,
    required this.text,
    required this.color,
    required this.onMinimize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(color),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                text,
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: "aristabold",
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onMinimize,
                  child: const Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- Bubble View ---------------- */

class _BubbleView extends StatelessWidget {
  final int color;
  const _BubbleView({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Color(color),
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: const Icon(Icons.sticky_note_2, color: Colors.white, size: 26),
    );
  }
}
