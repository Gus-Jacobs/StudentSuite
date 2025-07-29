import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionProvider with ChangeNotifier {
  AuthProvider? _authProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Getters ---
  // These now get their data directly from AuthProvider, the single source of truth.
  bool get isSubscribed => _authProvider?.isPro ?? false;
  bool get isLoading => _authProvider?.isLoading ?? true;
  String? get referralCode =>
      _authProvider?.user?.uid.substring(0, 8).toUpperCase();

  // Empty constructor for ChangeNotifierProxyProvider
  SubscriptionProvider();

  /// Called by ChangeNotifierProxyProvider when AuthProvider updates.
  void update(AuthProvider authProvider) {
    // Check if the actual subscription or loading state has changed before notifying listeners.
    // This prevents unnecessary widget rebuilds.
    final bool wasSubscribed = _authProvider?.isPro ?? false;
    final bool wasLoading = _authProvider?.isLoading ?? true;

    _authProvider = authProvider;

    final bool isNowSubscribed = _authProvider?.isPro ?? false;
    final bool isNowLoading = _authProvider?.isLoading ?? true;

    // Only notify if there's a meaningful change.
    if (wasSubscribed != isNowSubscribed || wasLoading != isNowLoading) {
      notifyListeners();
    }
  }

  /// Creates a document in Firestore that a Cloud Function will use to create
  /// a Stripe Checkout session.
  Future<void> launchCheckoutSession() async {
    if (_authProvider?.user == null) return; // Guard against null user
    final userId = _authProvider!.user!.uid;

    // Use a custom scheme for local dev, and https for production App Links.
    const successUrl = kDebugMode
        ? 'studentsuite://success'
        : 'https://app.studentsuite.com/success';
    const cancelUrl = kDebugMode
        ? 'studentsuite://cancel'
        : 'https://app.studentsuite.com/cancel';

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('checkout_sessions')
        .doc();

    // --- DYNAMIC PRICE SELECTION ---
    // Define your two price IDs from your Stripe dashboard.
    const founderPriceId =
        'price_1PQTGDRx6a951Jv7e425a7a1'; // Your existing $5.99 price
    const standardPriceId =
        'price_1RpIkuAt2vKSOayIyqw5nZnO'; // TODO: Replace with your new $11.99 price ID from Stripe

    // Determine which price to use based on the user's founder status.
    final bool isFounder = _authProvider?.isFounder ?? false;
    final String priceIdToUse = isFounder ? founderPriceId : standardPriceId;

    try {
      await docRef.set({
        'price': priceIdToUse,
        'success_url': successUrl,
        'cancel_url': cancelUrl,
        'timestamp': FieldValue.serverTimestamp(), // Add this for TTL
      });

      // Listen for the Cloud Function to add the checkout URL to the document.
      StreamSubscription? checkoutSubscription;
      checkoutSubscription = docRef.snapshots().listen((snap) async {
        final data = snap.data();
        if (data != null && data.containsKey('url')) {
          final uri = Uri.parse(data['url']);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          // After it works, cancel the subscription to avoid memory leaks.
          await checkoutSubscription?.cancel();
        } else if (data != null && data.containsKey('error')) {
          // Handle potential errors from the Cloud Function
          await checkoutSubscription?.cancel();
        }
      });
    } catch (e) {
      // ignore: avoid_print
      print("Error creating checkout session request: $e");
    }
  }

  /// Creates a document that triggers a Cloud Function to generate a Stripe
  /// Customer Portal link for subscription management
  Future<void> launchCustomerPortal() async {
    if (_authProvider?.user == null) return; // Guard against null user
    final userId = _authProvider!.user!.uid;

    // Use a custom scheme for local dev, and https for production App Links.
    const returnUrl = kDebugMode
        ? 'studentsuite://account_settings'
        : 'https://app.studentsuite.com/account_settings';

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('portal_links')
        .doc();

    // The return_url is where the user will be redirected after managing their subscription.
    // This should match a deep link configured in your app.
    await docRef.set(
        {'return_url': returnUrl, 'timestamp': FieldValue.serverTimestamp()});

    StreamSubscription? portalSubscription;
    portalSubscription = docRef.snapshots().listen((snap) async {
      final data = snap.data();
      if (data != null && data.containsKey('url')) {
        final uri = Uri.parse(data['url']);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        await portalSubscription?.cancel();
      } else if (data != null && data.containsKey('error')) {
        await portalSubscription?.cancel();
      }
    });
  }

  @override
  void dispose() {
    // No longer managing a listener, so nothing to cancel here.
    super.dispose();
  }
}
