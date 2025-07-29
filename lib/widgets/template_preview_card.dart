import 'dart:ui';
import 'package:flutter/material.dart';

class TemplatePreviewCard extends StatelessWidget {
  final String templateName;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  const TemplatePreviewCard({
    super.key,
    required this.templateName,
    required this.isSelected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurfaceColor = theme.colorScheme.onSurface;

    final glassColor =
        isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.1);
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : onSurfaceColor.withOpacity(0.3);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: borderColor, width: isSelected ? 2.5 : 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        color: onSurfaceColor.withOpacity(0.7), size: 32),
                    const SizedBox(height: 8),
                    Text(
                      templateName,
                      style: TextStyle(
                          color: onSurfaceColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
