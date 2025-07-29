import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/theme_provider.dart';

class GlassActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const GlassActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
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
              gradient: currentTheme.glassGradient,
              color: currentTheme.glassGradient == null ? glassColor : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: glassBorderColor),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                mouseCursor: SystemMouseCursors.click,
                onTap: onTap,
                leading:
                    Icon(icon, color: iconColor ?? onSurfaceColor, size: 28),
                title: Text(title,
                    style: TextStyle(
                        color: titleColor ?? onSurfaceColor,
                        fontWeight: FontWeight.bold)),
                subtitle: subtitle != null
                    ? Text(subtitle!,
                        style:
                            TextStyle(color: onSurfaceColor.withOpacity(0.7)))
                    : null,
                trailing: Icon(Icons.arrow_forward_ios,
                    color: onSurfaceColor.withOpacity(0.7), size: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
