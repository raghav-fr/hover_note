import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:hover_note/constants/AppTextStyle.dart';
import 'package:hover_note/models/Notes.dart';
import 'package:hover_note/models/note_database.dart';
import 'package:hover_note/screens/createEditPage/createEditPage.dart';
// import 'package:intl/date_symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

Future<void> showOverlay(Notes note) async {
  bool permitted = await FlutterOverlayWindow.isPermissionGranted();

  if (!permitted) {
    permitted = (await FlutterOverlayWindow.requestPermission())!;
  }

  if (!permitted) return;

  await FlutterOverlayWindow.showOverlay(
    width: 800,
    height: 600,
    enableDrag: true,
    alignment: OverlayAlignment.center,
    flag: OverlayFlag.defaultFlag,
  );

  await Future.delayed(const Duration(milliseconds: 400));

  FlutterOverlayWindow.shareData({
    "text": note.text,
    "color": note.color,
    "id": note.id,
  });
}

class _HomepageState extends State<Homepage> {
  static const MethodChannel _channel = MethodChannel('overlay_launcher');
  @override
void initState() {
  super.initState();
  context.read<NoteDatabase>().fetchNotes();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkLaunchIntent();
  });
}

  Future<void> _checkLaunchIntent() async {
    try {
      final Map? data = await _channel.invokeMethod('getInitialIntent');

      if (data != null && data['open_edit'] == true) {
        final id = data['note_id'];

        final note = context.read<NoteDatabase>().currentNotes.firstWhere(
          (n) => n.id == id,
        );
        print("Opening edit page for note id: $id with text: ${note.text}");
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => Createeditpage(editnote: note)),
        );
      }
    } catch (e) {
      debugPrint("Intent read error: $e");
    }
  }

  void readNotes() {
    context.read<NoteDatabase>().fetchNotes();
  }

  @override
  Widget build(BuildContext context) {
    final noteDatabase = context.watch<NoteDatabase>();

    List<Notes> currentNotes = noteDatabase.currentNotes;

    void openCreateEditPage({Notes? note}) async {
      final shouldRefresh = await Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.bottomToTop,
          child: Createeditpage(editnote: note!),
        ),
      );

      if (shouldRefresh == true) {
        readNotes(); // Reload after delete or save
      }
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size(80.w, 6.h),
        child: SafeArea(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w),
            height: 7.h,
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  height: 4.5.h,
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: Color.fromRGBO(255, 205, 7, 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FaIcon(FontAwesomeIcons.bars, color: Colors.white),
                      SizedBox(width: 4.w),
                      Text(
                        "Hover Note",
                        style: AppTextStyle.aristabold20.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.fromRGBO(20, 255, 20, 1),
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: FaIcon(
                      FontAwesomeIcons.magnifyingGlass,
                      color: Colors.white,
                      size: 2.5.h,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        elevation: 5,
        backgroundColor: Color.fromRGBO(31, 77, 240, 1),
        shape: CircleBorder(side: BorderSide(width: 1.5, color: Colors.white)),
        onPressed: () async {
          final newnote = await context.read<NoteDatabase>().createNote();
          openCreateEditPage(note: newnote);
        },
        child: const Icon(Icons.add_rounded, size: 50, color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<NoteDatabase>().fetchNotes();
          },
          child:
              currentNotes.isEmpty
                  ? CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Image(
                            width: 50.w,
                            image: AssetImage("assets/images/emptynote.png"),
                          ),
                        ),
                      ),
                    ],
                  )
                  : ListView.builder(
                    itemCount: currentNotes.length,
                    itemBuilder: (context, index) {
                      final note = currentNotes[index];
                      return InkWell(
                        onTap: () {
                          openCreateEditPage(note: note);
                        },
                        child: customContainer(
                          notes: note,
                          width: 80.w,
                          text: note.text,
                          color: Color(note.color),
                        ),
                      );
                    },
                  ),
        ),
      ),
    );
  }
}

class customContainer extends StatelessWidget {
  final Notes? notes;
  final double? width;
  final Color? color;
  final String? text;
  const customContainer({
    super.key,
    this.color,
    this.text,
    this.width,
    this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      margin: EdgeInsets.all(10),
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text!,
              maxLines: 5,
              style: AppTextStyle.aristabold17.copyWith(color: Colors.white),
            ),
          ),
          GestureDetector(
            onTap: () => showOverlay(notes!),
            child: Container(
              padding: EdgeInsets.only(top: 0.5.h, left: 2.5.w),
              child: FaIcon(
                FontAwesomeIcons.play,
                color: Colors.white,
                size: 2.h,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
