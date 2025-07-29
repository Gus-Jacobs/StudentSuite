import 'package:flutter/material.dart';

class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final int maxLines;
  final bool isRequired;
  final String? Function(String?)? validator;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.maxLines = 1,
    this.isRequired = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        style:
            TextStyle(color: onSurfaceColor), // Ensures text color is correct
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: icon != null
              ? Icon(icon, color: onSurfaceColor.withOpacity(0.7))
              : null,
          labelText: label,
          // All other styling (borders, label style, fill color) is now
          // handled by the InputDecorationTheme in theme_provider.dart for
          // consistency across all themes.
        ),
        validator: validator ??
            (value) => (isRequired && (value == null || value.trim().isEmpty))
                ? 'Please enter the $label.'
                : null,
      ),
    );
  }
}
