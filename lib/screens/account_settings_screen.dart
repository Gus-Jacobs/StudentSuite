import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_action_tile.dart';
import '../widgets/glass_info_tile.dart';
import '../providers/theme_provider.dart';
import 'dart:ui'; // For ImageFilter

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final subscription = Provider.of<SubscriptionProvider>(context);
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
          title: const Text('Account'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            GlassInfoTile(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: auth.user?.email ?? 'Not logged in',
            ),
            GlassActionTile(
              icon: Icons.alternate_email,
              title: 'Change Email',
              onTap: () => _showChangeEmailDialog(context),
            ),
            GlassActionTile(
              icon: Icons.password_outlined,
              title: 'Change Password',
              onTap: () => _showChangePasswordDialog(context),
            ),
            GlassInfoTile(
              icon: Icons.star_border_outlined,
              title: 'Subscription Tier',
              subtitle: subscription.isSubscribed ? 'Pro' : 'Free',
              trailing: subscription.isSubscribed
                  ? ElevatedButton(
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Redirecting to customer portal...')),
                        );
                        await subscription.launchCustomerPortal();
                      },
                      child: const Text('Manage'),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        subscription.launchCheckoutSession();
                      },
                      child: const Text('Upgrade'),
                    ),
            ),
            if (subscription.referralCode != null)
              GlassInfoTile(
                icon: Icons.card_giftcard_outlined,
                title: 'Your Referral Code',
                subtitle: subscription.referralCode!,
                trailing: IconButton(
                  icon: Icon(Icons.copy_outlined,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7)),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: subscription.referralCode!),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Referral code copied!')),
                    );
                  },
                ),
              ),
            const Divider(height: 24, color: Colors.white24),
            _buildDeleteAccountTile(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccountTile(BuildContext context) {
    final theme = Theme.of(context);
    return GlassActionTile(
      icon: Icons.delete_forever_outlined,
      title: 'Delete Account',
      onTap: () => _showDeleteAccountDialog(context),
      // Custom styling for destructive action
      titleColor: theme.colorScheme.error,
      iconColor: theme.colorScheme.error,
    );
  }

  void _showChangeEmailDialog(BuildContext context) {
    final newEmailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        bool isPasswordObscured = true;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Email'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter your new email and current password. A verification link will be sent to the new address.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newEmailController,
                      decoration: const InputDecoration(labelText: 'New Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    TextFormField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordObscured
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              isPasswordObscured = !isPasswordObscured;
                            });
                          },
                        ),
                      ),
                      obscureText: isPasswordObscured,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Password is required'
                          : null,
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
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        await auth.updateUserEmail(
                          newEmailController.text.trim(),
                          passwordController.text.trim(),
                        );
                        if (!context.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Verification email sent to new address!')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Failed to update email: ${auth.error}')),
                        );
                      }
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final newPasswordController = TextEditingController();
    final currentPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        bool isCurrentPasswordObscured = true;
        bool isNewPasswordObscured = true;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'Enter your current password and a new password.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: currentPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            isCurrentPasswordObscured
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              isCurrentPasswordObscured =
                                  !isCurrentPasswordObscured;
                            });
                          },
                        ),
                      ),
                      obscureText: isCurrentPasswordObscured,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Password is required'
                          : null,
                    ),
                    TextFormField(
                      controller: newPasswordController,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            isNewPasswordObscured
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              isNewPasswordObscured = !isNewPasswordObscured;
                            });
                          },
                        ),
                      ),
                      obscureText: isNewPasswordObscured,
                      validator: (v) => (v == null || v.length < 6)
                          ? 'New password must be at least 6 characters'
                          : null,
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
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        await auth.updateUserPassword(
                          newPasswordController.text.trim(),
                          currentPasswordController.text.trim(),
                        );
                        if (!context.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Password updated successfully!')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Failed to update password: ${auth.error}')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        bool isPasswordObscured = true;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Account?'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'This action is permanent and cannot be undone. All your data will be deleted. Please enter your password to confirm.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordObscured
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              isPasswordObscured = !isPasswordObscured;
                            });
                          },
                        ),
                      ),
                      obscureText: isPasswordObscured,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Password is required'
                          : null,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      // Get navigator and messenger references before the async gap.
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);

                      try {
                        await auth.deleteAccount(
                          passwordController.text.trim(),
                        );

                        // The auth state listener will handle state changes, but we
                        // navigate manually to ensure a clean exit.
                        navigator.pushNamedAndRemoveUntil(
                            '/login', (route) => false);

                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text('Account deleted successfully.')),
                        );
                      } catch (e) {
                        // The dialog is still on screen if it fails, so we can pop it.
                        Navigator.of(ctx).pop();
                        messenger.showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Failed to delete account: ${auth.error}')),
                        );
                      }
                    }
                  },
                  child: const Text('Delete My Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
