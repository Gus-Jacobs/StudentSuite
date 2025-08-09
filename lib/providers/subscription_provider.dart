import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Still needed for Stripe flow on other platforms
import 'package:in_app_purchase/in_app_purchase.dart'; // NEW: For Apple IAP

class SubscriptionProvider with ChangeNotifier {
  AuthProvider? _authProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance; // NEW: IAP instance

  // --- IAP Specific Variables ---
  // IMPORTANT: Replace these with your actual Product IDs configured in App Store Connect.
  // These should match the product IDs you create in App Store Connect for your subscriptions.
  static const String _appleSubscriptionProductId = 'com.pegumax.studentsuite.pro_monthly'; // Example ID
  // If you have different prices for founder/standard tiers in Apple IAP, you'd define multiple product IDs here.
  // For simplicity, we'll assume one main IAP product.

  // Stream subscription to listen for purchase updates
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // --- Getters ---
  bool get isSubscribed => _authProvider?.isPro ?? false;
  bool get isLoading => _authProvider?.isLoading ?? true;
  String? get referralCode => _authProvider?.user?.uid.substring(0, 8).toUpperCase();

  SubscriptionProvider() {
    // Listen to purchase updates as soon as the provider is created
    _listenToPurchaseUpdates();
  }

  /// Called by ChangeNotifierProxyProvider when AuthProvider updates.
  void update(AuthProvider authProvider) {
    final bool wasSubscribed = _authProvider?.isPro ?? false;
    final bool wasLoading = _authProvider?.isLoading ?? true;

    _authProvider = authProvider;

    final bool isNowSubscribed = _authProvider?.isPro ?? false;
    final bool isNowLoading = _authProvider?.isLoading ?? true;

    if (wasSubscribed != isNowSubscribed || wasLoading != isNowLoading) {
      notifyListeners();
    }
  }

  /// Initiates the subscription process based on the current platform.
  Future<void> initiateSubscription() async {
    if (_authProvider?.user == null) {
      print('User not logged in. Cannot initiate subscription.');
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      // --- Apple In-App Purchase Flow ---
      print('Initiating Apple In-App Purchase...');
      await _buyAppleSubscription();
    } else {
      // --- Stripe Checkout Flow (for Android, Web, Linux, Windows) ---
      print('Initiating Stripe Checkout...');
      await _launchStripeCheckoutSession();
    }
  }

  /// --- Apple In-App Purchase Specific Methods ---

  void _listenToPurchaseUpdates() {
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      (purchaseDetailsList) {
        for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
          if (purchaseDetails.status == PurchaseStatus.pending) {
            // Handle pending state (e.g., show a loading indicator)
            print('Purchase pending: ${purchaseDetails.productID}');
          } else {
            if (purchaseDetails.status == PurchaseStatus.error) {
              // Handle error (e.g., show an error message)
              print('Purchase error: ${purchaseDetails.error?.message}');
              _inAppPurchase.completePurchase(purchaseDetails); // Acknowledge the error
            } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                       purchaseDetails.status == PurchaseStatus.restored) {
              // Purchase successful or restored
              print('Purchase successful/restored: ${purchaseDetails.productID}');
              _verifyApplePurchase(purchaseDetails); // Verify with your backend
            }
            // Always complete the purchase after handling it to clear the transaction queue
            if (purchaseDetails.pendingCompletePurchase) {
              _inAppPurchase.completePurchase(purchaseDetails);
            }
          }
        }
      },
      onDone: () {
        _purchaseSubscription?.cancel();
      },
      onError: (error) {
        print('Error in purchase stream: $error');
      },
    );
  }

  Future<void> _buyAppleSubscription() async {
    // Check if IAP is available on the device
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      print('In-App Purchases are not available on this device.');
      // Optionally show a user-friendly message
      return;
    }

    // Query product details from Apple App Store
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({_appleSubscriptionProductId});

    if (response.error != null) {
      print('Error querying Apple products: ${response.error?.message}');
      // Show error to user
      return;
    }

    if (response.productDetails.isEmpty) {
      print('Apple product $_appleSubscriptionProductId not found in App Store Connect.');
      // Show user-friendly message if product is misconfigured
      return;
    }

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

    // Initiate the purchase
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam); // Or buySubscription for subscriptions
  }

  /// Sends the Apple purchase receipt to your backend for validation.
  /// Your backend will then communicate with Apple's servers to verify.
  Future<void> _verifyApplePurchase(PurchaseDetails purchaseDetails) async {
    try {
      // Example: Send receipt data to a Cloud Function
      final userId = _authProvider!.user!.uid;
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('iap_receipts')
          .doc(purchaseDetails.purchaseID);

      await docRef.set({
        'platform': 'apple',
        'product_id': purchaseDetails.productID,
        'purchase_id': purchaseDetails.purchaseID,
        'transaction_date': purchaseDetails.transactionDate,
        'verification_data': purchaseDetails.verificationData.serverVerificationData,
        'status': 'pending_validation',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Optionally, listen for a response from your Cloud Function on this document
      // to confirm subscription status update.
      print('Sent Apple receipt to backend for validation.');

    } catch (e) {
      print('Error sending Apple receipt to backend: $e');
    }
  }

  /// Allows users to restore past Apple In-App Purchases.
  Future<void> restoreApplePurchases() async {
    print('Attempting to restore Apple In-App Purchases...');
    await _inAppPurchase.restorePurchases();
    // The _listenToPurchaseUpdates stream will handle the restored purchases.
  }

  /// --- Existing Stripe Specific Methods ---

  /// Creates a document in Firestore that a Cloud Function will use to create
  /// a Stripe Checkout session.
  Future<void> _launchStripeCheckoutSession() async {
    if (_authProvider?.user == null) return;
    final userId = _authProvider!.user!.uid;

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

    const founderPriceId = 'price_1PQTGDRx6a951Jv7e425a7a1';
    const standardPriceId = 'price_1RpIkuAt2vKSOayIyqw5nZnO';

    final bool isFounder = _authProvider?.isFounder ?? false;
    final String priceIdToUse = isFounder ? founderPriceId : standardPriceId;

    try {
      await docRef.set({
        'price': priceIdToUse,
        'success_url': successUrl,
        'cancel_url': cancelUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      StreamSubscription? checkoutSubscription;
      checkoutSubscription = docRef.snapshots().listen((snap) async {
        final data = snap.data();
        if (data != null && data.containsKey('url')) {
          final uri = Uri.parse(data['url']);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          await checkoutSubscription?.cancel();
        } else if (data != null && data.containsKey('error')) {
          await checkoutSubscription?.cancel();
        }
      });
    } catch (e) {
      print("Error creating checkout session request: $e");
    }
  }

  /// Creates a document that triggers a Cloud Function to generate a Stripe
  /// Customer Portal link for subscription management
  Future<void> launchCustomerPortal() async {
    if (_authProvider?.user == null) return;
    final userId = _authProvider!.user!.uid;

    // IMPORTANT: If running on iOS/macOS, this function should NOT be called directly.
    // Instead, for Apple platforms, users should manage subscriptions via App Store settings.
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      print('Customer portal not directly available on Apple platforms. Users manage subscriptions via App Store settings.');
      // Optionally, you might launch a URL to Apple's subscription management page,
      // though typically users find this through their device settings.
      // E.g., launchUrl(Uri.parse('https://apps.apple.com/account/subscriptions'));
      return;
    }

    const returnUrl = kDebugMode
        ? 'studentsuite://account_settings'
        : 'https://app.studentsuite.com/account_settings';

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('portal_links')
        .doc();

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
    _purchaseSubscription?.cancel(); // Cancel the IAP stream subscription
    super.dispose();
  }
}
