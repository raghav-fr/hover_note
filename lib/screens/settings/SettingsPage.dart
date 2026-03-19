import 'package:flutter/material.dart';
import 'package:hover_note/constants/AppTextStyle.dart';
import 'package:hover_note/services/theme_service/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Settings", style: AppTextStyle.aristabold20),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Theme Mode", style: AppTextStyle.aristabold18),
            SizedBox(height: 2.h),
            _buildThemeOption(
              context,
              "System Default",
              ThemeMode.system,
              themeProvider,
            ),
            _buildThemeOption(
              context,
              "Light Mode",
              ThemeMode.light,
              themeProvider,
            ),
            _buildThemeOption(
              context,
              "Dark Mode",
              ThemeMode.dark,
              themeProvider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    ThemeMode mode,
    ThemeProvider provider,
  ) {
    return RadioListTile<ThemeMode>(
      title: Text(title, style: AppTextStyle.aristabold17),
      value: mode,
      groupValue: provider.themeMode,
      activeColor: Theme.of(context).colorScheme.primary,
      onChanged: (ThemeMode? value) {
        if (value != null) {
          provider.setThemeMode(value);
        }
      },
    );
  }
}
