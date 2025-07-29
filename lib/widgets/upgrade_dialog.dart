import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/providers/subscription_provider.dart';

void showUpgradeDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      // Determine the price based on the user's founder status.
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isFounder = auth.isFounder;
      final priceString = isFounder ? r'$5.99/month' : r'$11.99/month';

      return AlertDialog(
        title: const Text('Upgrade to Pro'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              const Text('This is a Pro feature.'),
              const SizedBox(height: 8),
              Text(
                  'Upgrade for $priceString to unlock all AI-powered tools, including:'),
              const SizedBox(height: 16),
              const Row(children: [
                Icon(Icons.check, color: Colors.green),
                SizedBox(width: 8),
                Text('AI Teacher & Interviewer')
              ]),
              const Row(children: [
                Icon(Icons.check, color: Colors.green),
                SizedBox(width: 8),
                Text('Resume & Cover Letter AI')
              ]),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Maybe Later'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
              child: const Text('Upgrade Now'),
              onPressed: () {
                // 1. Pop the upgrade dialog itself.
                Navigator.of(context).pop();
                // 2. Show a temporary snackbar to inform the user.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Redirecting to payment portal...')),
                );
                // 3. Launch the checkout session.
                Provider.of<SubscriptionProvider>(context, listen: false)
                    .launchCheckoutSession();
              }),
        ],
      );
    },
  );
}
