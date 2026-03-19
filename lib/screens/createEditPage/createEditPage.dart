import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hover_note/constants/AppTextStyle.dart';
import 'package:hover_note/models/notes.dart';
import 'package:hover_note/models/note_database.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _isDeleted = false;
  bool _hasSaved = false;

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
    reminderDateTime = widget.editnote.scheduledAt;
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
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (_isDeleted || _hasSaved) return;
        _saveNote();
      },
      child: Scaffold(
      appBar: PreferredSize(
        preferredSize: Size(80.w, 6.h),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: FaIcon(
                  FontAwesomeIcons.arrowLeft,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                    onPressed: () {
                      if (textController.text.isNotEmpty) {
                        Share.share(textController.text);
                      }
                    },
                    icon: FaIcon(
                      FontAwesomeIcons.shareNodes,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      size: 2.2.h,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isDeleted = true;
                      });
                      context.read<NoteDatabase>().deleteNote(
                        widget.editnote.id,
                      );
                      Navigator.pop(context);
                    },
                    icon: FaIcon(
                      FontAwesomeIcons.trash,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      size: 2.2.h,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _saveNote();
                      Navigator.pop(context);
                    },
                    icon: FaIcon(
                      FontAwesomeIcons.check,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                  SizedBox(width: 3.w),
                  Text(
                    _formattedReminder(),
                    style: AppTextStyle.aristabold17.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[500], size: 2.h),
                    onPressed: () {
                      setState(() {
                        reminderDateTime = null;
                      });
                    },
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
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                hintText: ' Enter your message here...',
                border: const OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _saveNote() {
    if (_isDeleted || _hasSaved) return;
    _hasSaved = true;

    if (textController.text.trim().isEmpty) {
      context.read<NoteDatabase>().deleteNote(widget.editnote.id);
    } else {
      if (reminderDateTime != null) {
        context.read<NoteDatabase>().scheduleNoteReminder(
          widget.editnote.id,
          textController.text,
          currentcolor!,
          reminderDateTime!,
        );
      } else {
        if (widget.editnote.isScheduled) {
          context.read<NoteDatabase>().cancelSchedule(widget.editnote.id);
        }
        context.read<NoteDatabase>().updateNote(
          widget.editnote.id,
          textController.text,
          currentcolor!,
        );
      }
    }
  }
}
