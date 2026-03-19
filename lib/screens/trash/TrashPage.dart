import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hover_note/constants/AppTextStyle.dart';
import 'package:hover_note/models/notes.dart';
import 'package:hover_note/models/note_database.dart';
import 'package:hover_note/screens/homepage/HomePage.dart';
import 'package:hover_note/screens/scheduled/ScheduledPage.dart';
import 'package:hover_note/screens/settings/SettingsPage.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:hover_note/components/note_container.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = "";
  bool _isSelectionMode = false;
  final Set<int> _selectedNoteIds = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoteDatabase>().fetchNotes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _deleteSelectedNotes() {
    if (_selectedNoteIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Delete Forever", style: AppTextStyle.aristabold20),
          content: Text(
            "Are you sure you want to delete ${_selectedNoteIds.length} notes permanently?",
            style: AppTextStyle.aristabold17,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: AppTextStyle.aristabold17),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final db = context.read<NoteDatabase>();
                for (final id in _selectedNoteIds) {
                  await db.deletePermanently(id);
                }
                setState(() {
                  _isSelectionMode = false;
                  _selectedNoteIds.clear();
                });
              },
              child: const Text(
                "Delete Forever",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final noteDatabase = context.watch<NoteDatabase>();
    final notes =
        noteDatabase.trashNotes.where((note) {
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
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(255, 205, 7, 1),
                ),
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 20.h,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            "assets/images/drawerlogo.png",
                            height: 8.h,
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            "Hover Note",
                            style: AppTextStyle.aristabold20.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 2.h),

              ListTile(
                leading: const FaIcon(
                  FontAwesomeIcons.solidNoteSticky,
                  color: Color.fromRGBO(255, 205, 7, 1),
                ),
                title: Text(
                  "All Notes",
                  style: AppTextStyle.aristabold17.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const Homepage()),(route)=>false
                  );
                },
              ),

              ListTile(
                leading: const FaIcon(
                  FontAwesomeIcons.solidClock,
                  color: Color.fromRGBO(255, 205, 7, 1),
                ),
                title: Text(
                  "Scheduled Notes",
                  style: AppTextStyle.aristabold17.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ScheduledPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const FaIcon(
                  FontAwesomeIcons.trash,
                  color: Color.fromRGBO(255, 205, 7, 1),
                ),
                title: Text(
                  "Trash",
                  style: AppTextStyle.aristabold17.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TrashPage()),
                  );
                },
              ),
              Divider(color: Colors.grey[300], indent: 4.w, endIndent: 4.w),
              ListTile(
                leading: const Icon(
                  Icons.settings_rounded,
                  color: Color.fromRGBO(255, 205, 7, 1),
                ),
                title: Text(
                  "Settings",
                  style: AppTextStyle.aristabold17.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.info_rounded,
                  color: Color.fromRGBO(255, 205, 7, 1),
                ),
                title: Text(
                  "About",
                  style: AppTextStyle.aristabold17.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
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
              child:
                  _isSelectionMode
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSelectionMode = false;
                                    _selectedNoteIds.clear();
                                  });
                                },
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                "${_selectedNoteIds.length} Selected",
                                style: AppTextStyle.aristabold17.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.restore,
                                  color: Colors.green,
                                ),
                                onPressed: () async {
                                  final db = context.read<NoteDatabase>();
                                  for (final id in _selectedNoteIds)
                                    await db.restoreNote(id);
                                  setState(() {
                                    _isSelectionMode = false;
                                    _selectedNoteIds.clear();
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_forever,
                                  color: Colors.redAccent,
                                ),
                                onPressed: _deleteSelectedNotes,
                              ),
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
                                    onTap:
                                        () =>
                                            _scaffoldKey.currentState
                                                ?.openDrawer(),
                                    child: Row(
                                      children: [
                                        Container(
                                          height: 5.h,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4.w,
                                          ),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color.fromRGBO(
                                              255,
                                              205,
                                              7,
                                              1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              FaIcon(
                                                FontAwesomeIcons.bars,
                                                color: Colors.white,
                                                size: 2.h,
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 3.w),
                                        Text(
                                          "trash",
                                          style: AppTextStyle.aristabold20
                                              .copyWith(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_isSearching)
                                  Expanded(
                                    child: Container(
                                      height: 5.h,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4.w,
                                      ),
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
                                          hintText: "Search in trash...",
                                          border: InputBorder.none,
                                          hintStyle: AppTextStyle.aristabold17
                                              .copyWith(color: Colors.grey),
                                          icon: const FaIcon(
                                            FontAwesomeIcons.magnifyingGlass,
                                            color: Color.fromRGBO(
                                              255,
                                              205,
                                              7,
                                              1,
                                            ),
                                            size: 20,
                                          ),
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
                                color:
                                    _isSearching
                                        ? Colors.redAccent
                                        : const Color.fromRGBO(20, 255, 20, 1),
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
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh:
                      () async =>
                          await context.read<NoteDatabase>().fetchNotes(),
                  child:
                      notes.isEmpty
                          ? ListView(
                            children: [
                              SizedBox(height: 20.h),
                              Center(
                                child: Column(
                                  children: [
                                    Image.asset(
                                      "assets/images/drawerlogo.png",
                                      width: 40.w,
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      "Trash is empty",
                                      style: AppTextStyle.aristabold17,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                          : ListView.builder(
                            itemCount: notes.length,
                            itemBuilder: (context, index) {
                              final note = notes[index];
                              return NoteContainer(
                                notes: note,
                                text: note.text,
                                color: Color(note.color),
                                isSelected: _selectedNoteIds.contains(note.id),
                                onLongPress: () {
                                  if (!_isSelectionMode) {
                                    setState(() {
                                      _isSelectionMode = true;
                                      _selectedNoteIds.add(note.id);
                                    });
                                  }
                                },
                                onTap: () {
                                  if (_isSelectionMode) {
                                    setState(() {
                                      if (_selectedNoteIds.contains(note.id)) {
                                        _selectedNoteIds.remove(note.id);
                                        if (_selectedNoteIds.isEmpty)
                                          _isSelectionMode = false;
                                      } else {
                                        _selectedNoteIds.add(note.id);
                                      }
                                    });
                                  }
                                },
                              );
                            },
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
