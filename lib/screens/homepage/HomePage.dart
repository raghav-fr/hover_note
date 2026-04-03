import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hover_note/constants/AppTextStyle.dart';
import 'package:hover_note/models/notes.dart';
import 'package:hover_note/models/note_database.dart';
import 'package:hover_note/screens/createEditPage/createEditPage.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hover_note/screens/trash/TrashPage.dart';
import 'package:hover_note/screens/scheduled/ScheduledPage.dart';
import 'package:hover_note/screens/settings/SettingsPage.dart';
import 'package:hover_note/components/note_container.dart';
import 'package:share_plus/share_plus.dart';

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
Future<void> showOverlay(Notes note) async {
  try {
    final bool permitted = await _overlayChannel.invokeMethod('checkOverlayPermission');
    if (!permitted) {
      await _overlayChannel.invokeMethod('requestOverlayPermission');
      return;
    }
    if (_activeOverlayIds.contains(note.id)) return;
    _activeOverlayIds.add(note.id);
    await _overlayChannel.invokeMethod('showNativeOverlay', {
      'id': note.id,
      'text': note.text,
      'color': note.color,
    });
  } catch (e) {
    debugPrint("[OVERLAY] ERROR: $e");
  }
}

void removeOverlay(int noteId) {
  _activeOverlayIds.remove(noteId);
  _overlayChannel.invokeMethod('closeNativeOverlay', {'id': noteId});
}

void onOverlayClosed(int noteId) {
  _activeOverlayIds.remove(noteId);
}

class _HomepageState extends State<Homepage> with WidgetsBindingObserver {
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

  // --- Selection Mode ---
  bool _isSelectionMode = false;
  final Set<int> _selectedNoteIds = {};

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
    WidgetsBinding.instance.addObserver(this);
    context.read<NoteDatabase>().fetchNotes();
    _loadBannerAd();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLaunchIntent();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerAd?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh notes when app comes back to foreground
      context.read<NoteDatabase>().fetchNotes();
    }
  }

  Future<void> _checkLaunchIntent() async {
    try {
      final Map? data = await _channel.invokeMethod('getInitialIntent');
      if (data != null && data['open_edit'] == true) {
        final id = data['note_id'];
        final note = context.read<NoteDatabase>().currentNotes.firstWhere((n) => n.id == id);
        Navigator.push(context, MaterialPageRoute(builder: (_) => Createeditpage(editnote: note)));
      }
    } catch (e) {
      debugPrint("Intent read error: $e");
    }
  }

  void readNotes() {
    context.read<NoteDatabase>().fetchNotes();
  }

  void openCreateEditPage({Notes? note}) async {
    final shouldRefresh = await Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.bottomToTop,
        child: Createeditpage(editnote: note!),
      ),
    );
    if (shouldRefresh == true) readNotes();
  }

  @override
  Widget build(BuildContext context) {
    final noteDatabase = context.watch<NoteDatabase>();
    List<Notes> currentNotes = noteDatabase.currentNotes;
    List<Notes> filteredNotes = currentNotes.where((note) {
      return note.text.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedNoteIds.clear();
          });
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(color: Color.fromRGBO(255, 205, 7, 1)),
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 20.h,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset("assets/images/logowhite.png", height: 8.h),
                          SizedBox(height: 1.h),
                          Text("Hover Note", style: AppTextStyle.aristabold20.copyWith(color: Colors.white)),
                          SizedBox(height: 2.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.solidNoteSticky, color: Color.fromRGBO(255, 205, 7, 1)),
                title: Text("All Notes", style: AppTextStyle.aristabold17.copyWith(color: Theme.of(context).colorScheme.primary)),
                onTap: () => Navigator.pop(context),
              ),
              
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.solidClock, color: Color.fromRGBO(255, 205, 7, 1)),
                title: Text("Scheduled Notes", style: AppTextStyle.aristabold17.copyWith(color: Theme.of(context).colorScheme.primary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ScheduledPage()));
                },
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.trash, color: Color.fromRGBO(255, 205, 7, 1)),
                title: Text("Trash", style: AppTextStyle.aristabold17.copyWith(color: Theme.of(context).colorScheme.primary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TrashPage()));
                },
              ),
              Divider(color: Colors.grey[300], indent: 4.w, endIndent: 4.w),
              ListTile(
                leading: const Icon(Icons.settings_rounded, color: Color.fromRGBO(255, 205, 7, 1)),
                title: Text("Settings", style: AppTextStyle.aristabold17.copyWith(color: Theme.of(context).colorScheme.primary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_rounded, color: Color.fromRGBO(255, 205, 7, 1)),
                title: Text("About", style: AppTextStyle.aristabold17.copyWith(color: Theme.of(context).colorScheme.primary)),
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
              color: Theme.of(context).colorScheme.surface,
              child: _isSelectionMode
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.close, color: Theme.of(context).colorScheme.primary),
                              onPressed: () => setState(() { _isSelectionMode = false; _selectedNoteIds.clear(); }),
                            ),
                            SizedBox(width: 2.w),
                            Text("${_selectedNoteIds.length} Selected", style: AppTextStyle.aristabold17.copyWith(color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.push_pin_rounded, color: Theme.of(context).colorScheme.primary),
                              onPressed: _pinSelectedNotes,
                            ),
                            IconButton(
                              icon: Icon(Icons.share_rounded, color: Theme.of(context).colorScheme.primary),
                              onPressed: _shareSelectedNotes,
                            ),
                            IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.redAccent), onPressed: _deleteSelectedNotes),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (!_isSearching)
                                GestureDetector(
                                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                                  child: Container(
                                    height: 5.h,
                                    padding: EdgeInsets.symmetric(horizontal: 3.w),
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), color: const Color.fromRGBO(255, 205, 7, 1)),
                                    child: Row(
                                      children: [
                                        FaIcon(FontAwesomeIcons.bars, color: Colors.white, size: 2.h),
                                        SizedBox(width: 3.w),
                                        Text("Hover Note", style: AppTextStyle.aristabold20.copyWith(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              if (_isSearching)
                                Expanded(
                                  child: Container(
                                    height: 5.h,
                                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), color: Colors.grey[100]),
                                    child: TextField(
                                      controller: _searchController,
                                      autofocus: true,
                                      onChanged: (val) => setState(() => _searchQuery = val),
                                      style: AppTextStyle.aristabold17,
                                      decoration: InputDecoration(
                                        hintText: "Search notes...",
                                        border: InputBorder.none,
                                        hintStyle: AppTextStyle.aristabold17.copyWith(color: Colors.grey),
                                        icon: FaIcon(FontAwesomeIcons.magnifyingGlass, color: const Color.fromRGBO(255, 205, 7, 1), size: 2.h),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 3.w),
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
                              color: _isSearching ? Colors.redAccent : const Color.fromRGBO(20, 255, 20, 1),
                            ),
                            child: Center(
                              child: FaIcon(_isSearching ? FontAwesomeIcons.xmark : FontAwesomeIcons.magnifyingGlass, color: Colors.white, size: 2.h),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        floatingActionButton: FloatingActionButton(
          elevation: 5,
          backgroundColor: const Color.fromRGBO(31, 77, 240, 1),
          shape: const CircleBorder(side: BorderSide(width: 1.5, color: Colors.white)),
          onPressed: () async {
            final newnote = await context.read<NoteDatabase>().createNote();
            openCreateEditPage(note: newnote);
          },
          child: const Icon(Icons.add_rounded, size: 50, color: Colors.white),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => await context.read<NoteDatabase>().fetchNotes(),
            child: currentNotes.isEmpty
                ? CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Container(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image(width: 50.w, image: const AssetImage("assets/images/emptynote.png")),
                                if (_isSearching && _searchQuery.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: 2.h),
                                    child: Text("No matches found for '$_searchQuery'", style: AppTextStyle.aristabold17.copyWith(color: Colors.grey)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = filteredNotes[index];
                      final isSelected = _selectedNoteIds.contains(note.id);
                      return NoteContainer(
                        notes: note,
                        width: 80.w,
                        text: note.text,
                        color: Color(note.color),
                        isSelected: isSelected,
                        onLongPress: () { if (!_isSelectionMode) setState(() { _isSelectionMode = true; _selectedNoteIds.add(note.id); }); },
                        onTap: () {
                          if (_isSelectionMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedNoteIds.remove(note.id);
                                if (_selectedNoteIds.isEmpty) _isSelectionMode = false;
                              } else {
                                _selectedNoteIds.add(note.id);
                              }
                            });
                          } else {
                            openCreateEditPage(note: note);
                          }
                        },
                      );
                    },
                  ),
          ),
        ),
        bottomNavigationBar: _isBannerAdLoaded && _bannerAd != null
            ? SizedBox(height: _bannerAd!.size.height.toDouble(), width: double.infinity, child: AdWidget(ad: _bannerAd!))
            : const SizedBox.shrink(),
      ),
    );
  }

  void _shareSelectedNotes() {
    if (_selectedNoteIds.isEmpty) return;
    final notesToShare = context.read<NoteDatabase>().currentNotes
        .where((n) => _selectedNoteIds.contains(n.id))
        .map((n) => n.text)
        .join('\n\n---\n\n');
    Share.share(notesToShare);
    setState(() { _isSelectionMode = false; _selectedNoteIds.clear(); });
  }

  void _pinSelectedNotes() async {
    if (_selectedNoteIds.isEmpty) return;
    final db = context.read<NoteDatabase>();
    final selectedNotes = db.currentNotes.where((n) => _selectedNoteIds.contains(n.id)).toList();
    final allPinned = selectedNotes.every((n) => n.isPinned);
    
    for (final note in selectedNotes) {
      await db.updateNotePin(note.id, !allPinned);
    }
    setState(() { _isSelectionMode = false; _selectedNoteIds.clear(); });
  }

  void _deleteSelectedNotes() {
    if (_selectedNoteIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Move to Trash", style: AppTextStyle.aristabold20),
          content: Text("Are you sure you want to move ${_selectedNoteIds.length} notes to trash?", style: AppTextStyle.aristabold17),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: AppTextStyle.aristabold17.copyWith(color: Colors.grey))),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final db = context.read<NoteDatabase>();
                for (final id in _selectedNoteIds) {
                  await db.deleteNote(id);
                }
                setState(() { _isSelectionMode = false; _selectedNoteIds.clear(); });
              },
              child: Text("Delete", style: AppTextStyle.aristabold17.copyWith(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }
}
