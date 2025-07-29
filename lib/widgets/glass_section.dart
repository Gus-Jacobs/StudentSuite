import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/theme_provider.dart';

class GlassSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onRemove;
  final bool initiallyExpanded;

  const GlassSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.onRemove,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = themeProvider.currentTheme;
    final isDark = theme.brightness == Brightness.dark;
    final onSurfaceColor = theme.colorScheme.onSurface;

    // Define theme-aware colors for the glass effect.
    final glassColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);
    final glassBorderColor =
        isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: glassBorderColor),
            ),
            child: ExpansionTile(
              initiallyExpanded: initiallyExpanded,
              leading: Icon(icon, color: onSurfaceColor),
              trailing: onRemove != null
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: onRemove,
                    )
                  : Icon(Icons.arrow_drop_down, color: onSurfaceColor),
              title: Text(title,
                  style: TextStyle(
                      color: onSurfaceColor, fontWeight: FontWeight.bold)),
              iconColor: onSurfaceColor,
              collapsedIconColor: onSurfaceColor,
              children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: child)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
