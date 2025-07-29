import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'dart:ui'; // For ImageFilter
import '../providers/subscription_provider.dart';
import '../widgets/upgrade_dialog.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});
  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

enum ThemeType { color, image }

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  ThemeType _selectedThemeType = ThemeType.color;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = themeProvider.currentTheme;

    BoxDecoration backgroundDecoration;
    if (currentTheme.imageAssetPath != null) {
      backgroundDecoration = BoxDecoration(
        image: DecorationImage(
          image: AssetImage(currentTheme.imageAssetPath!),
          fit: BoxFit.cover,
          colorFilter:
              ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
        ),
      );
    } else {
      backgroundDecoration = BoxDecoration(gradient: currentTheme.gradient);
    }

    return Container(
      decoration: backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Theme & Colors'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            _buildSectionTitle(context, 'Color Mode'),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.wb_sunny_outlined)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.nights_stay_outlined)),
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.settings_brightness_outlined)),
              ],
              selected: {themeProvider.themeMode},
              onSelectionChanged: (newSelection) {
                themeProvider.setThemeMode(newSelection.first);
              },
            ),
            const Divider(height: 40, color: Colors.white30),
            _buildSectionTitle(context, 'Background Style'),
            const SizedBox(height: 16),
            SegmentedButton<ThemeType>(
              segments: const [
                ButtonSegment(value: ThemeType.color, label: Text('Gradients')),
                ButtonSegment(value: ThemeType.image, label: Text('Images')),
              ],
              selected: {_selectedThemeType},
              onSelectionChanged: (newSelection) {
                setState(() => _selectedThemeType = newSelection.first);
              },
            ),
            const SizedBox(height: 16),
            _buildThemeGrid(themeProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeGrid(ThemeProvider themeProvider) {
    final List<AppTheme> themesToShow;
    if (_selectedThemeType == ThemeType.color) {
      themesToShow = appThemes.where((t) => t.gradient != null).toList();
    } else {
      themesToShow = appThemes.where((t) => t.imageAssetPath != null).toList();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: themesToShow.length,
      itemBuilder: (context, index) {
        final theme = themesToShow[index];
        final isSelected = theme.name == themeProvider.currentTheme.name;
        return _ThemePreviewCard(
          theme: theme,
          isSelected: isSelected,
          onTap: () {
            final subscription =
                Provider.of<SubscriptionProvider>(context, listen: false);
            if (theme.isPro && !subscription.isSubscribed) {
              showUpgradeDialog(context);
            } else {
              themeProvider.setAppTheme(theme);
            }
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  final AppTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      // <--- ADDED MouseRegion here
      cursor: SystemMouseCursors.click, // <--- Set the cursor here
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 0,
          color: Colors.transparent, // Make card transparent
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (theme.imageAssetPath != null)
                        Image.asset(theme.imageAssetPath!, fit: BoxFit.cover)
                      else
                        Container(
                          decoration: BoxDecoration(gradient: theme.gradient),
                        ),
                      if (isSelected)
                        Container(
                          color: Colors.black.withOpacity(0.4),
                          child: const Icon(Icons.check_circle,
                              color: Colors.white, size: 36),
                        ),
                      if (theme.isPro && !isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(1, 1),
                                )
                              ],
                            ),
                            child: const Text('PRO',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10)),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.black.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: Text(
                      theme.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
