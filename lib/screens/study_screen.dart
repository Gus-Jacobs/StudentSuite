import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import 'package:student_suite/widgets/upgrade_dialog.dart';
import 'dart:ui'; // For ImageFilter

class StudyScreen extends StatelessWidget {
  static const List<_StudyTool> tools = [
    _StudyTool('Flashcards', Icons.style_outlined, '/flashcards', isPro: false),
    _StudyTool('Pomodoro', Icons.timer_outlined, '/pomodoro', isPro: false),
    _StudyTool('AI Teacher', Icons.smart_toy_outlined, '/ai_teacher',
        isPro: true),
    _StudyTool('Notes', Icons.note_alt_outlined, '/notes', isPro: false),
  ];

  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The Scaffold and AppBar are now handled by HomeScreen.
    // This widget only returns the body content.
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return _StudyToolCard(tool: tool);
      },
    );
  }
}

class _StudyToolCard extends StatelessWidget {
  const _StudyToolCard({required this.tool});

  final _StudyTool tool;

  @override
  Widget build(BuildContext context) {
    final subscription = Provider.of<SubscriptionProvider>(context);
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;

    // Define theme-aware colors for the glass effect
    final glassColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);
    final glassBorderColor =
        isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1);

    // A modern, glass-like card that's visible on any background.
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: glassBorderColor,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                if (tool.isPro && !subscription.isSubscribed) {
                  showUpgradeDialog(context);
                } else {
                  Navigator.pushNamed(context, tool.route);
                }
              },
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          tool.icon,
                          size: 48,
                          color: onSurfaceColor.withOpacity(0.9),
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(2, 2),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tool.name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: onSurfaceColor,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              const Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tool.isPro)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(1, 1),
                            )
                          ],
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudyTool {
  final String name;
  final IconData icon;
  final String route;
  final bool isPro;

  const _StudyTool(this.name, this.icon, this.route, {this.isPro = false});
}
