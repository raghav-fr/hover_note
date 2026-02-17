import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

enum OverlayMode { expanded, bubble }

// const MethodChannel _channel = MethodChannel('overlay_launcher');

class HoverOverlay extends StatefulWidget {
  const HoverOverlay({super.key});

  @override
  State<HoverOverlay> createState() => _HoverOverlayState();
}

class _HoverOverlayState extends State<HoverOverlay> {
  String text = "Loading...";
  int color = 0xFF000000;
  int? noteId;

  OverlayMode mode = OverlayMode.expanded;

  @override
  void initState() {
    super.initState();

    FlutterOverlayWindow.overlayListener.listen((data) {
      setState(() {
        text = data["text"] ?? text;
        color = data["color"] ?? color;
        noteId = data["id"]; // ✅ primitive only
      });
    });
  }

  void minimizeToBubble() {
    setState(() => mode = OverlayMode.bubble);
  }

  void expandOverlay() {
    setState(() => mode = OverlayMode.expanded);
  }

  // Change your openEditPage function to this:
void openEditPage() async {
  print("Opening Edit Page for note ID: $noteId");
  // 1. Send a message to the Main App via the shared bridge
  await FlutterOverlayWindow.shareData({
    'command': 'open_edit_page',
    'id': noteId
  });

  // 2. Close the overlay
  await FlutterOverlayWindow.closeOverlay();
}
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Overlay-safe (prevents MouseTracker crash)
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
        body: Center(
          child: GestureDetector(
            onTap: () {
              if (mode == OverlayMode.bubble) {
                expandOverlay();
              }
            },
            onDoubleTap: () {
              if (mode == OverlayMode.expanded) {
                openEditPage();
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  mode == OverlayMode.bubble
                      ? _BubbleView(color: color)
                      : _ExpandedView(
                        text: text,
                        color: color,
                        onMinimize: minimizeToBubble,
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- Expanded View ---------------- */

class _ExpandedView extends StatelessWidget {
  final String text;
  final int color;
  final VoidCallback onMinimize;

  const _ExpandedView({
    required this.text,
    required this.color,
    required this.onMinimize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey("expanded"),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(color),
        borderRadius: BorderRadius.circular(20),
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
                  onTap: FlutterOverlayWindow.closeOverlay,
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
  const _BubbleView({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey("bubble"),
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
