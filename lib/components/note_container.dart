import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hover_note/constants/AppTextStyle.dart';
import 'package:hover_note/models/notes.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:hover_note/screens/homepage/HomePage.dart'; // For showOverlay

class NoteContainer extends StatelessWidget {
  final Notes? notes;
  final double? width;
  final Color? color;
  final String? text;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final bool isSelected;
  
  const NoteContainer({
    super.key,
    this.color,
    this.text,
    this.width,
    this.notes,
    this.onLongPress,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        margin: EdgeInsets.all(10),
        width: width,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notes?.isPinned ?? false)
                    Padding(
                      padding: EdgeInsets.only(right: 2.w, top: 0.5.h),
                      child: Transform.rotate(
                        angle: 0.5,
                        child: Icon(
                          Icons.push_pin_rounded,
                          color: Colors.white,
                          size: 1.8.h,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text!,
                          maxLines: 5,
                          style: AppTextStyle.aristabold17.copyWith(color: Colors.white),
                        ),
                        if (notes?.isScheduled == true && notes?.scheduledAt != null)
                           Padding(
                             padding: EdgeInsets.only(top: 1.h),
                             child: Row(
                               children: [
                                 FaIcon(FontAwesomeIcons.solidClock, color: Colors.white70, size: 1.5.h),
                                 SizedBox(width: 1.5.w),
                                 Text(
                                   DateFormat("MM/dd HH:mm").format(notes!.scheduledAt!),
                                   style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                                 ),
                               ]
                             )
                           ),
                      ]
                    ),
                  ),
                ],
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
      ),
    );
  }
}
