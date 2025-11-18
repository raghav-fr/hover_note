import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HoverOverlay());
}


class HoverOverlay extends StatefulWidget {
  const HoverOverlay({super.key});

  @override
  State<HoverOverlay> createState() => _HoverOverlayState();
}

class _HoverOverlayState extends State<HoverOverlay> {
  String text = "Loading...";
  int color = 0xFF000000;

  @override
  void initState() {
    super.initState();

    FlutterOverlayWindow.overlayListener.listen((data) {
      setState(() {
        text = data["text"];
        color = data["color"];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(15),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(color),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => FlutterOverlayWindow.closeOverlay(),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
