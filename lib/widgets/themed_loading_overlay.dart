import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // For ImageFilter
import '../providers/theme_provider.dart';

class ThemedLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const ThemedLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          // This modal barrier prevents interaction with the UI behind it.
          const ModalBarrier(dismissible: false, color: Colors.black26),
        if (isLoading)
          // The actual loading UI
          _buildLoadingUI(context),
      ],
    );
  }

  Widget _buildLoadingUI(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final currentTheme = themeProvider.currentTheme;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        decoration: BoxDecoration(gradient: currentTheme.gradient),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}
