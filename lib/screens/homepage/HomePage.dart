import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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

// MethodChannel shared between overlay functions and the widget
const MethodChannel _overlayChannel = MethodChannel('overlay_launcher');

// Track which notes currently have an active overlay
final Set<int> _activeOverlayIds = {};

/// Shows a native floating overlay window for the given note.
/// Each note gets its own independent, draggable window via NativeOverlayService.
Future<void> showOverlay(Notes note) async {
  debugPrint("[OVERLAY] showOverlay called for note id=${note.id}");
  
  try {
    // Check overlay permission via native code
    final bool permitted = await _overlayChannel.invokeMethod('checkOverlayPermission');
    debugPrint("[OVERLAY] Permission check result: $permitted");

    if (!permitted) {
      debugPrint("[OVERLAY] Requesting overlay permission...");
      await _overlayChannel.invokeMethod('requestOverlayPermission');
      return; // User needs to grant permission in Settings, then try again
    }

    // If this note already has an active overlay, don't create a duplicate
    if (_activeOverlayIds.contains(note.id)) {
      debugPrint("[OVERLAY] Note ${note.id} already has active overlay, skipping");
      return;
    }

    _activeOverlayIds.add(note.id);

    debugPrint("[OVERLAY] Calling showNativeOverlay for id=${note.id}, text='${note.text}', color=${note.color}");
    // Tell the native NativeOverlayService to create a new floating window
    await _overlayChannel.invokeMethod('showNativeOverlay', {
      'id': note.id,
      'text': note.text,
      'color': note.color,
    });
    debugPrint("[OVERLAY] showNativeOverlay call completed successfully");
  } catch (e, stack) {
    debugPrint("[OVERLAY] ERROR: $e");
    debugPrint("[OVERLAY] Stack: $stack");
  }
}

/// Removes a specific note's native overlay window.
void removeOverlay(int noteId) {
  _activeOverlayIds.remove(noteId);
  _overlayChannel.invokeMethod('closeNativeOverlay', {'id': noteId});
}

/// Called when the native service reports an overlay was closed (user tapped ✕).
void onOverlayClosed(int noteId) {
  _activeOverlayIds.remove(noteId);
}

class _HomepageState extends State<Homepage> {
  static const MethodChannel _channel = MethodChannel('overlay_launcher');

  // --- AdMob Banner ---
  static const String _adUnitId = 'ca-app-pub-6437781486320364/6277958371';
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // --- Search & Sidebar ---
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = "";

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void initState() {
    super.initState();
    context.read<NoteDatabase>().fetchNotes();
    _loadBannerAd();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLaunchIntent();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _searchController.dispose();
    super.dispose();
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

    // Filter notes based on search query
    List<Notes> filteredNotes = currentNotes.where((note) {
      return note.text.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

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
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Color.fromRGBO(255, 205, 7, 1)),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      "assets/images/emptynote.png", // Reusing your existing image as a logo
                      height: 8.h,
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      "Hover Note",
                      style: AppTextStyle.aristabold20.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: FaIcon(
                FontAwesomeIcons.noteSticky,
                color: Color.fromRGBO(255, 205, 7, 1),
              ),
              title: Text("All Notes", style: AppTextStyle.aristabold17),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(
                Icons.settings_rounded,
                color: Color.fromRGBO(255, 205, 7, 1),
              ),
              title: Text("Settings", style: AppTextStyle.aristabold17),
              onTap: () {},
            ),
            ListTile(
              leading: Icon(
                Icons.info_rounded,
                color: Color.fromRGBO(255, 205, 7, 1),
              ),
              title: Text("About", style: AppTextStyle.aristabold17),
              onTap: () {},
            ),
          ],
        ),
      ),
      appBar: PreferredSize(
        preferredSize: Size(100.w, 8.h),
        child: SafeArea(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Menu Icon + Title (or Search Field)
                Expanded(
                  child: Row(
                    children: [
                      if (!_isSearching)
                        GestureDetector(
                          onTap: () => _scaffoldKey.currentState?.openDrawer(),
                          child: Container(
                            height: 5.h,
                            padding: EdgeInsets.symmetric(horizontal: 3.w),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: Color.fromRGBO(255, 205, 7, 1),
                            ),
                            child: Row(
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.bars,
                                  color: Colors.white,
                                  size: 2.h,
                                ),
                                SizedBox(width: 3.w),
                                Text(
                                  "Hover Note",
                                  style: AppTextStyle.aristabold20.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_isSearching)
                        Expanded(
                          child: Container(
                            height: 5.h,
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: Colors.grey[100],
                            ),
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              style: AppTextStyle.aristabold17,
                              decoration: InputDecoration(
                                hintText: "Search notes...",
                                border: InputBorder.none,
                                hintStyle: AppTextStyle.aristabold17.copyWith(
                                  color: Colors.grey,
                                ),
                                icon: FaIcon(
                                  FontAwesomeIcons.magnifyingGlass,
                                  color: Color.fromRGBO(255, 205, 7, 1),
                                  size: 2.h,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 3.w),
                // Search Toggle Button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_isSearching) {
                        _isSearching = false;
                        _searchQuery = "";
                        _searchController.clear();
                      } else {
                        _isSearching = true;
                      }
                    });
                  },
                  child: Container(
                    height: 5.h,
                    width: 5.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _isSearching
                              ? Colors.redAccent
                              : Color.fromRGBO(20, 255, 20, 1),
                    ),
                    child: Center(
                      child: FaIcon(
                        _isSearching
                            ? FontAwesomeIcons.xmark
                            : FontAwesomeIcons.magnifyingGlass,
                        color: Colors.white,
                        size: 2.h,
                      ),
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image(
                                width: 50.w,
                                image: AssetImage("assets/images/emptynote.png"),
                              ),
                              if (_isSearching && _searchQuery.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 2.h),
                                  child: Text(
                                    "No matches found for '$_searchQuery'",
                                    style: AppTextStyle.aristabold17.copyWith(color: Colors.grey),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                  : ListView.builder(
                    itemCount: filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = filteredNotes[index];
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
      bottomNavigationBar: _isBannerAdLoaded && _bannerAd != null
          ? SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: double.infinity,
              child: AdWidget(ad: _bannerAd!),
            )
          : const SizedBox.shrink(),
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
