import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:student_suite/widgets/glass_action_tile.dart';
import '../providers/auth_provider.dart';
import 'dart:ui'; // For ImageFilter
import 'dart:io' show Platform;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This widget only returns the body content, as Scaffold/AppBar are in HomeScreen.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        GlassActionTile(
          icon: Icons.person_outline,
          title: 'Profile',
          subtitle: 'Manage your personal information',
          onTap: () => Navigator.pushNamed(context, '/profile'),
        ),
        GlassActionTile(
          icon: Icons.palette_outlined,
          title: 'Theme & Colors',
          subtitle: 'Change the look and feel of the app',
          onTap: () => Navigator.pushNamed(context, '/theme_settings'),
        ),
        GlassActionTile(
          icon: Icons.font_download_outlined,
          title: 'Font Settings',
          subtitle: 'Adjust text size and style',
          onTap: () => Navigator.pushNamed(context, '/font_settings'),
        ),
        GlassActionTile(
          icon: Icons.verified_user_outlined,
          title: 'Account',
          subtitle: 'Manage subscription and security',
          onTap: () => Navigator.pushNamed(context, '/account_settings'),
        ),
        GlassActionTile(
          icon: Icons.library_books_outlined,
          title: 'AI Context Subjects',
          subtitle: 'Provide context for AI tools',
          onTap: () => Navigator.pushNamed(context, '/subjects'),
        ),
        const Divider(height: 24, color: Colors.white24),
        GlassActionTile(
          icon: Icons.contact_support_outlined,
          title: 'Contact Support',
          subtitle: 'Report an issue or get help',
          onTap: () => _showFeedbackDialog(context, 'Issue'),
        ),
        GlassActionTile(
          icon: Icons.lightbulb_outlined,
          title: 'Give Feedback',
          subtitle: 'Suggest a new feature or idea',
          onTap: () => _showFeedbackDialog(context, 'Feedback'),
        ),
        const SizedBox(height: 24),
        _buildLogoutButton(context),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return ElevatedButton.icon(
      icon: const Icon(Icons.logout),
      label: const Text('Log Out'),
      onPressed: () async {
        // It's good practice to get a reference to the Navigator before an
        // async call if the widget's context might become invalid.
        final navigator = Navigator.of(context);
        await auth.logout();
        // The AuthGate handles the initial screen, but for an explicit logout,
        // we must manually navigate and clear the route history.
        navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context, String initialCategory) {
    final formKey = GlobalKey<FormState>();
    final messageController = TextEditingController();
    String category = initialCategory; // 'Issue' or 'Feedback'

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          // Use StatefulBuilder to manage dialog state
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(initialCategory == 'Issue'
                  ? 'Contact Support'
                  : 'Give Feedback'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: category,
                      items: ['Issue', 'Feedback', 'Idea', 'Praise']
                          .map((label) => DropdownMenuItem(
                                value: label,
                                child: Text(label),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            category = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'Your Message',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a message.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => _submitFeedback(
                      ctx, formKey, category, messageController),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _submitFeedback(BuildContext context, GlobalKey<FormState> formKey,
      String category, TextEditingController messageController) async {
    if (formKey.currentState?.validate() ?? false) {
      final auth = context.read<AuthProvider>();
      final user = auth.user;

      // Show a loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await FirebaseFirestore.instance.collection('feedback').add({
          'userId': user?.uid ?? 'anonymous',
          'email': user?.email ?? 'anonymous',
          'displayName': auth.displayName,
          'category': category,
          'message': messageController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'version': await _getAppVersion(), // Dynamically get app version
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        });

        // Pop loading indicator and then the feedback form
        Navigator.of(context).pop(); // Pop loading indicator
        Navigator.of(context).pop(); // Pop feedback dialog

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
      } catch (e) {
        // Pop loading indicator
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send feedback: $e')));
      }
    }
  }

  Future<String> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }
}
