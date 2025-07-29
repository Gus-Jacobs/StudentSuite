import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../providers/theme_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:student_suite/models/note.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  bool _isPasswordObscured = true;

  @override
  void initState() {
    super.initState();
    // It's good practice to clear any lingering snackbars from previous screens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Listen for auth changes to pop the screen if signup is successful.
      // The AuthGate will then show the correct screen.
      context.read<AuthProvider>().addListener(_onAuthStateChanged);
      ScaffoldMessenger.of(context).clearSnackBars();
    });
  }

  void _onAuthStateChanged() {
    final auth = context.read<AuthProvider>();
    // If we are on this screen and the user is now logged in, pop back to the AuthGate.
    if (auth.user != null && mounted) {
      // This ensures that once signup is complete, this screen is removed
      // from the navigation stack, revealing the HomeScreen managed by AuthGate.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _handleSignup(BuildContext context) async {
    // Dismiss the keyboard to prevent UI overflow when the loading indicator appears.
    FocusScope.of(context).unfocus();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _email.text.trim();
    final password = _password.text.trim();
    final referralCode = _referralCodeController.text.trim();

    // Basic validation
    if (email.isEmpty || password.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Signup Failed'),
          content: const Text('Email and password cannot be empty.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      // The dev bypass was removed as it prevents actual account creation.
      // If a user tries to sign up with 'dev@pgm.com', it should go through
      // the normal signup flow.

      final bool success =
          await auth.signUp(email, password, referralCode: referralCode);

      if (!mounted) return;

      if (!success) {
        // The success case is handled by the listener.
        // The success case is handled by the listener. We only need to handle failure.
        // If user is null, something went wrong. Show an error.
        String errorMsg =
            auth.error ?? 'An unknown error occurred during signup.';

        // Friendlier error messages for common Firebase errors
        if (auth.error?.contains('email-already-in-use') ?? false) {
          errorMsg = 'This email is already registered. Try logging in.';
        } else if (auth.error?.contains('invalid-email') ?? false) {
          errorMsg = 'Please enter a valid email address.';
        } else if (auth.error?.contains('weak-password') ?? false) {
          errorMsg = 'Password should be at least 6 characters.';
        }

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Signup Failed'),
            content: Text(errorMsg),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Show a generic error dialog for any other unexpected errors.
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('An Error Occurred'),
          content: Text('Something went wrong during signup: $e'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'))
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    // Dispose controllers to free up resources.
    context.read<AuthProvider>().removeListener(_onAuthStateChanged);
    _email.dispose();
    _password.dispose();
    _referralCodeController.dispose();
    super.dispose();
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
              title: const Text('Contact Support'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: category,
                      items: ['Signup Issue', 'Bug Report', 'General Inquiry']
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
      // It's good practice to get a reference to the Navigator and
      // ScaffoldMessenger before an async call if the widget's context might
      // become invalid.
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      final auth = context.read<AuthProvider>();
      final user = auth.user;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
      );

      try {
        await FirebaseFirestore.instance.collection('feedback').add({
          'userId': user?.uid ?? 'anonymous',
          'email': user?.email ?? _email.text.trim(),
          'displayName': auth.displayName.isNotEmpty ? auth.displayName : 'N/A',
          'category': category,
          'message': messageController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'version': '1.0.0+1',
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        });

        navigator.pop(); // Pop loading indicator
        navigator.pop(); // Pop feedback dialog

        messenger.showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
      } catch (e) {
        navigator.pop();
        messenger.showSnackBar(
            SnackBar(content: Text('Failed to send feedback: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final currentTheme = themeProvider.currentTheme;
    final theme = Theme.of(context);
    // Ensure status bar icons are light to contrast with the dark gradient
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewportConstraints) {
          return Container(
            decoration: currentTheme.imageAssetPath != null
                ? BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(currentTheme.imageAssetPath!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.5), BlendMode.darken),
                    ),
                  )
                : BoxDecoration(gradient: currentTheme.gradient),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewportConstraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Custom back button to replace AppBar
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Create Account,',
                            style: theme.textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  const Shadow(
                                    blurRadius: 10.0,
                                    color: Colors.black38,
                                    offset: Offset(2.0, 2.0),
                                  ),
                                ]),
                          ),
                          Text(
                            'Sign up to get started',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(color: Colors.white70, shadows: [
                              const Shadow(
                                blurRadius: 8.0,
                                color: Colors.black26,
                                offset: Offset(1.0, 1.0),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 48),
                          TextField(
                            controller: _email,
                            decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined)),
                            keyboardType: TextInputType.emailAddress,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _password,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordObscured
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordObscured = !_isPasswordObscured;
                                  });
                                },
                              ),
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                            obscureText: _isPasswordObscured,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _referralCodeController,
                            decoration: const InputDecoration(
                                labelText: 'Referral Code (Optional)',
                                prefixIcon: Icon(Icons.card_giftcard)),
                            style:
                                TextStyle(color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _handleSignup(context),
                              child: const Text('Sign Up'),
                            ),
                          ),
                          const Spacer(),
                          Center(
                            child: TextButton(
                              onPressed: () =>
                                  _showFeedbackDialog(context, 'Signup Issue'),
                              child: const Text('Contact Support'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
