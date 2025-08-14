import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:hover_note/models/Notes.dart';
import 'package:hover_note/services/notification_service/notification_service.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

const String saveNoteTask = "saveNoteTask";

@pragma('vm:entry-point') // ✅ Required for Workmanager background tasks
void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      if (task == saveNoteTask) {
        final dir = await getApplicationDocumentsDirectory();
        final isar = await Isar.open([NotesSchema], directory: dir.path);

        final noteText = inputData?['text'];
        final colorValue = inputData?['color'] ?? Colors.lightGreenAccent.value;

        final newNote =
            Notes()
              ..text = noteText
              ..color = colorValue;

        await isar.writeTxn(() => isar.notes.put(newNote));

        // Show notification
        await NotificationService.showNotification(
          title: "Reminder Note",
          body: noteText,
        );
      }
      return Future.value(true);
    });
  }

class NoteDatabase extends ChangeNotifier {
  static late Isar isar;
  //initialization
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open([NotesSchema], directory: dir.path);

    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  }

  

  Future<void> scheduleNoteReminder(
    String text,
    Color color,
    DateTime reminderTime,
  ) async {
    final duration = reminderTime.difference(DateTime.now());
    if (duration.isNegative) return; // Skip if time is past

    Workmanager().registerOneOffTask(
      DateTime.now().millisecondsSinceEpoch.toString(),
      saveNoteTask,
      initialDelay: duration,
      inputData: {'text': text, 'color': color.value},
    );
  }

  //create
  final List<Notes> currentNotes = [];
  //create a note
  Future<Notes> createNote() async {
    final newNote = Notes()..text = '';
    newNote.color = Colors.pink.value;
    //save to db
    await isar.writeTxn(() => isar.notes.put(newNote));

    return newNote;
  }

  //add in a new note
  Future<void> addNote(String textFromUser) async {
    final newNote = Notes()..text = textFromUser;
    newNote.color = Colors.pink.value;
    //save to db
    await isar.writeTxn(() => isar.notes.put(newNote));
    //fetch from db
    fetchNotes();
  }

  //read
  Future<void> fetchNotes() async {
    List<Notes> fetchedNotes = await isar.notes.where().findAll();
    currentNotes.clear();
    currentNotes.addAll(fetchedNotes);
    notifyListeners();
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
  //delete

  Future<void> deleteNote(int id) async {
    await isar.writeTxn(() => isar.notes.delete(id));
    await fetchNotes();
  }
}
