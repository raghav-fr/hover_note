import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hover_note/constants/AppTextStyle.dart';
import 'package:hover_note/models/Notes.dart';
import 'package:hover_note/models/note_database.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';

class Createeditpage extends StatefulWidget {
  final Notes editnote;
  const Createeditpage({super.key, required this.editnote});

  @override
  State<Createeditpage> createState() => _CreateeditpageState();
}

class _CreateeditpageState extends State<Createeditpage> {
  TextEditingController textController = TextEditingController();
  Color? currentcolor;
  DateTime? reminderDateTime;

  void colorchange(Color color) {
    setState(() {
      currentcolor = color;
    });
  }

  @override
  void initState() {
    super.initState();
    textController.text = widget.editnote.text;
    currentcolor = Color(widget.editnote.color);
  }

  Future<void> _pickReminderDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: reminderDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime:
            reminderDateTime != null
                ? TimeOfDay.fromDateTime(reminderDateTime!)
                : TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          reminderDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  String _formattedReminder() {
    if (reminderDateTime == null) return "";
    return DateFormat("yyyy-MM-dd HH:mm").format(reminderDateTime!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size(80.w, 6.h),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  if (textController.text.isEmpty) {
                    context.read<NoteDatabase>().deleteNote(widget.editnote.id);
                    Navigator.pop(context);
                  } else {
                    textController.text==widget.editnote.text? Navigator.pop(context):
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("Save before exiting?"),
                          content: Text(
                            "You have unsaved changes. Do you want to save them?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                if (widget.editnote.text.isEmpty) {
                                  context.read<NoteDatabase>().deleteNote(
                                    widget.editnote.id,
                                  );
                                }
                                Navigator.pop(context); // close dialog
                                Navigator.pop(context); // close edit page
                              },
                              child: Text("Discard"),
                            ),
                            TextButton(
                              onPressed: () {
                                context.read<NoteDatabase>().updateNote(
                                  widget.editnote.id,
                                  textController.text,
                                  currentcolor!,
                                );
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                              child: Text("Save"),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
                icon: FaIcon(
                  FontAwesomeIcons.arrowLeft,
                  color: Colors.grey[600],
                  size: 2.2.h,
                ),
              ),
              Row(
                children: [
                  // Reminder icon
                  IconButton(
                    onPressed: _pickReminderDateTime,
                    icon: FaIcon(
                      FontAwesomeIcons.solidClock,
                      color:
                          reminderDateTime != null
                              ? currentcolor
                              : Colors.grey[500],
                      size: 2.2.h,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: FaIcon(
                      FontAwesomeIcons.shareNodes,
                      color: Colors.grey[600],
                      size: 2.2.h,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      context.read<NoteDatabase>().deleteNote(
                        widget.editnote.id,
                      );
                      Navigator.pop(context, true);
                    },
                    icon: FaIcon(
                      FontAwesomeIcons.trash,
                      color: Colors.grey[600],
                      size: 2.2.h,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (textController.text.isEmpty) {
                        context.read<NoteDatabase>().deleteNote(
                          widget.editnote.id,
                        );
                      } else {
                        if (reminderDateTime != null) {
                          context.read<NoteDatabase>().scheduleNoteReminder(
                            textController.text,
                            currentcolor!,
                            reminderDateTime!,
                          );
                          context.read<NoteDatabase>().deleteNote(
                          widget.editnote.id,
                        );
                        } else {
                          context.read<NoteDatabase>().updateNote(
                            widget.editnote.id,
                            textController.text,
                            currentcolor!,
                          );
                        }
                      }
                      textController.clear();
                      Navigator.pop(context);
                    },
                    icon: FaIcon(
                      FontAwesomeIcons.check,
                      color: Colors.grey[600],
                      size: 2.2.h,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          contentPadding: EdgeInsets.zero,
                          titlePadding: EdgeInsets.zero,
                          content: SingleChildScrollView(
                            child: ColorPicker(
                              pickerColor: currentcolor!,
                              onColorChanged: colorchange,
                              colorPickerWidth: 300,
                              pickerAreaHeightPercent: .7,
                              displayThumbColor: true,
                              paletteType: PaletteType.hsl,
                              pickerAreaBorderRadius: const BorderRadius.only(
                                topRight: Radius.circular(2),
                                topLeft: Radius.circular(2),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    width: 7.w,
                    height: 7.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentcolor,
                    ),
                  ),
                ),
                if (reminderDateTime != null) ...[
                  SizedBox(width: 10),
                  Text(
                    _formattedReminder(),
                    style: AppTextStyle.aristabold16.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: textController,
              textAlignVertical: TextAlignVertical.top,
              maxLines: null,
              cursorWidth: 2,
              cursorColor: Colors.grey[500],
              expands: true,
              keyboardType: TextInputType.multiline,
              style: AppTextStyle.aristabold19,
              decoration: InputDecoration(
                hintStyle: TextStyle(color: Colors.grey[400]),
                hintText: ' Enter your message here...',
                border: const OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
