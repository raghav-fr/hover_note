import 'package:flutter/material.dart';
import 'package:hover_note/models/notes.dart';
import 'package:hover_note/services/notification_service/notification_service.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const String saveNoteTask = "saveNoteTask";

@pragma('vm:entry-point') // ✅ Required for Workmanager background tasks
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == saveNoteTask) {
      final dir = await getApplicationDocumentsDirectory();
      final isar = await Isar.open([NotesSchema], directory: dir.path);

      final noteId = inputData?['id'];
      if (noteId != null) {
        final existingNote = await isar.notes.get(noteId);
        if (existingNote != null) {
          existingNote.isScheduled = false;
          existingNote.scheduledAt = null;
          await isar.writeTxn(() => isar.notes.put(existingNote));
        }
      }
    }
    return Future.value(true);
  });
}

class NoteDatabase extends ChangeNotifier {
  static late Isar isar;

  NoteDatabase() {
    startWatching();
  }

  //initialization
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open([NotesSchema], directory: dir.path);

    // ✅ Init Workmanager for background DB saving
    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    // ✅ Init Timezone for scheduling notifications
    tzdata.initializeTimeZones();

    // Auto-cleanup trash after 20 days
    await _cleanupOldTrash(isar);
  }

  // Watch for changes in Isar to make DB reactive
  void startWatching() {
    isar.notes.watchLazy().listen((_) {
      fetchNotes();
    });
  }

  static Future<void> _cleanupOldTrash(Isar isarInstance) async {
    final thresholdDate = DateTime.now().subtract(const Duration(days: 20));
    // Find notes in trash where deletedAt is older than 20 days
    final oldTrash = await isarInstance.notes.filter()
      .isDeletedEqualTo(true)
      .deletedAtLessThan(thresholdDate)
      .findAll();
    
    if (oldTrash.isNotEmpty) {
      await isarInstance.writeTxn(() async {
        for (var note in oldTrash) {
          await isarInstance.notes.delete(note.id);
        }
      });
    }
  }

  //create
  final List<Notes> currentNotes = [];
  final List<Notes> trashNotes = [];
  final List<Notes> scheduledNotes = [];

  //create a note
  Future<Notes> createNote() async {
    final newNote = Notes()..text = '';
    newNote.color = Colors.pink.value;
    await isar.writeTxn(() => isar.notes.put(newNote));
    return newNote;
  }

  //add in a new note
  Future<void> addNote(String textFromUser) async {
    final newNote = Notes()..text = textFromUser;
    newNote.color = Colors.pink.value;
    await isar.writeTxn(() => isar.notes.put(newNote));
    fetchNotes();
  }

  //read
  Future<void> fetchNotes() async {
    List<Notes> allNotes = await isar.notes.where().findAll();

    List<Notes> active = [];
    List<Notes> trash = [];
    List<Notes> scheduled = [];

    for (var note in allNotes) {
      if (note.isDeleted) {
        trash.add(note);
      } else if (note.isScheduled) {
        scheduled.add(note);
      } else {
        active.add(note);
      }
    }

    // Sort: Pinned first, then by date descending
    active.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.date.compareTo(a.date);
    });
    
    // Sort scheduled by scheduled date
    scheduled.sort((a, b) {
      if (a.scheduledAt != null && b.scheduledAt != null) {
        return a.scheduledAt!.compareTo(b.scheduledAt!);
      }
      return b.date.compareTo(a.date);
    });

    // Sort trash by deletedAt date descending (newest trash first)
    trash.sort((a, b) {
      if (a.deletedAt != null && b.deletedAt != null) {
        return b.deletedAt!.compareTo(a.deletedAt!);
      }
      return b.date.compareTo(a.date);
    });

    currentNotes.clear();
    currentNotes.addAll(active);
    
    trashNotes.clear();
    trashNotes.addAll(trash);
    
    scheduledNotes.clear();
    scheduledNotes.addAll(scheduled);
    
    notifyListeners();
  }

  // update pin status
  Future<void> updateNotePin(int id, bool isPinned) async {
    final existingNote = await isar.notes.get(id);
    if (existingNote != null) {
      existingNote.isPinned = isPinned;
      await isar.writeTxn(() => isar.notes.put(existingNote));
      await fetchNotes();
    }
  }

  //update
  Future<void> updateNote(int id, String newText, Color color) async {
    final existingNote = await isar.notes.get(id);
    if (existingNote != null) {
      existingNote.text = newText;
      existingNote.color = color.value;
      await isar.writeTxn(() => isar.notes.put(existingNote));
      await fetchNotes();
    }
  }

  //move to trash
  Future<void> deleteNote(int id) async {
    final existingNote = await isar.notes.get(id);
    if (existingNote != null) {
      // If it's empty, delete it permanently
      if (existingNote.text.trim().isEmpty) {
        await deletePermanently(id);
      } else {
        existingNote.isDeleted = true;
        existingNote.deletedAt = DateTime.now();
        existingNote.isPinned = false; // Unpin when trashing
        
        // Also unschedule if it was scheduled
        if (existingNote.isScheduled) {
          existingNote.isScheduled = false;
          existingNote.scheduledAt = null;
        }
        await isar.writeTxn(() => isar.notes.put(existingNote));
        await fetchNotes();
      }
    }
  }

  //restore from trash
  Future<void> restoreNote(int id) async {
    final existingNote = await isar.notes.get(id);
    if (existingNote != null) {
      existingNote.isDeleted = false;
      existingNote.deletedAt = null;
      await isar.writeTxn(() => isar.notes.put(existingNote));
      await fetchNotes();
    }
  }

  //permanent delete
  Future<void> deletePermanently(int id) async {
    await isar.writeTxn(() => isar.notes.delete(id));
    await fetchNotes();
  }
  
  // cancel schedule and return to main
  Future<void> cancelSchedule(int id) async {
    final existingNote = await isar.notes.get(id);
    if (existingNote != null) {
      existingNote.isScheduled = false;
      existingNote.scheduledAt = null;
      await isar.writeTxn(() => isar.notes.put(existingNote));
      await fetchNotes();
    }
  }

  // ✅ Schedule Note Reminder (DB save via WorkManager + Notification via Awesome)
  Future<void> scheduleNoteReminder(
    int id,
    String text,
    Color color,
    DateTime reminderTime,
  ) async {
    final duration = reminderTime.difference(DateTime.now());
    if (duration.isNegative) return; // Skip if time is past

    // Update note in DB immediately to show in Scheduled view
    final existingNote = await isar.notes.get(id);
    if (existingNote != null) {
      existingNote.text = text;
      existingNote.color = color.value;
      existingNote.isScheduled = true;
      existingNote.scheduledAt = reminderTime;
      await isar.writeTxn(() => isar.notes.put(existingNote));
      await fetchNotes();
    }

    // Save note using WorkManager (background safe to toggle status later)
    Workmanager().registerOneOffTask(
      DateTime.now().millisecondsSinceEpoch.toString(),
      saveNoteTask,
      initialDelay: duration,
      inputData: {'id': id},
    );

    // Schedule notification using AwesomeNotifications
    await NotificationService.scheduleNotification(
      title: "Hover note notifies u",
      body: text,
      scheduledTime: reminderTime,
    );
  }
}
