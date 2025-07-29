import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/providers/subscription_provider.dart';

void showPostLoginUpgradeDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // User must interact with the dialog
    builder: (BuildContext context) {
      // Determine the price based on the user's founder status.
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isFounder = auth.isFounder;
      final priceString = isFounder ? r'$5.99' : r'$11.99';
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.rocket_launch_outlined, color: Colors.amber),
            SizedBox(width: 10),
            Text('Go Pro!'),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              const Text(
                'Upgrade to use AI tools and ace your studies!',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                '$priceString a month - that\'s less than a coffee!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
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
              final subscriptionProvider =
                  Provider.of<SubscriptionProvider>(context, listen: false);
              Navigator.of(context).pop();
              subscriptionProvider.launchCheckoutSession();
            },
          ),
        ],
      );
    },
  );
}
