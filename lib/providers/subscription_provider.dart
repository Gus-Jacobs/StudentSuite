// The full, updated subscription_provider.dart file
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Your IAP product IDs
const String _kProSubscriptionId = 'your_iap_subscription_id';

class SubscriptionProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InAppPurchase _iap = InAppPurchase.instance;
  User? get _user => _auth.currentUser;

  bool _isPro = false;
  bool get isPro => _isPro;

  String? _referralCode;
  String? get referralCode => _referralCode;

  late Stream<List<PurchaseDetails>> _purchaseStream;

  SubscriptionProvider() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToUserSubscriptionStatus(user.uid);
        _initInAppPurchase();
      } else {
        _isPro = false;
        _referralCode = null;
        notifyListeners();
      }
    });
  }

  void _listenToUserSubscriptionStatus(String userId) {
    _firestore.collection('users').doc(userId).snapshots().listen((docSnapshot) {
      final data = docSnapshot.data();
      if (data != null) {
        final isStripePro = data['stripeRole'] == 'pro';
        final isIAPPro = data['iapRole'] == 'pro';
        _isPro = isStripePro || isIAPPro;
        _referralCode = data['referralCode'];
      } else {
        _isPro = false;
        _referralCode = null;
      }
      notifyListeners();
    });
  }

  void _initInAppPurchase() {
    _purchaseStream = _iap.purchaseStream;
    _purchaseStream.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    });
    // This is important for iOS to handle incomplete transactions.
    if (Platform.isIOS) {
      final iapStoreKitPlatform = _iap.getPlatformAddition<InAppPurchaseStoreKitPlatform>();
      iapStoreKitPlatform.set simulatesAskToBuyInSandbox(true);
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Handle pending status
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Handle error
        print(purchaseDetails.error);
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Handle successful purchase/restore
        _handleSuccessfulPurchase(purchaseDetails);
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    // Validate the receipt with your backend
    if (_user == null) return;
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('processIAPReceipt');
      final result = await callable.call(<String, dynamic>{
        'platform': Platform.isIOS ? 'ios' : 'android',
        'receiptData': Platform.isIOS ? purchaseDetails.verificationData.serverVerificationData : {
          'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
          'subscriptionId': _kProSubscriptionId,
        },
        'isSandbox': false, // You should set this dynamically
      });
      print('IAP receipt validation result: ${result.data}');

      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    } catch (e) {
      print('Failed to process IAP receipt: $e');
    }
  }

  Future<void> launchCheckoutSession() async {
    if (_user == null) {
      print('User is not logged in.');
      return;
    }
    final docRef = _firestore.collection('users').doc(_user!.uid).collection('checkout_sessions').doc();
    await docRef.set({
      'price': 'price_1PqJ1vH7s20mP73fX7Q7L5G3', // Replace with your actual price ID
      'success_url': 'https://your-domain.com/success', // Your success URL
      'cancel_url': 'https://your-domain.com/cancel', // Your cancel URL
    });
    final docSnapshot = await docRef.get();
    final url = docSnapshot.data()?['url'];
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        print('Could not launch Stripe Checkout URL.');
      }
    }
  }

  Future<void> launchCustomerPortal() async {
    if (_user == null) {
      print('User is not logged in.');
      return;
    }
    final docRef = _firestore.collection('users').doc(_user!.uid).collection('portal_links').doc();
    await docRef.set({
      'return_url': 'https://your-domain.com/account', // Your return URL
    });
    final docSnapshot = await docRef.get();
    final url = docSnapshot.data()?['url'];
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        print('Could not launch Stripe Portal URL.');
      }
    }
  }

  Future<void> purchaseIAPSubscription() async {
    if (_user == null) return;
    final bool available = await _iap.isAvailable();
    if (!available) {
      print('The store is not available.');
      return;
    }
    final ProductDetailsResponse response =
        await _iap.queryProductDetails({_kProSubscriptionId});
    if (response.notFoundIDs.isNotEmpty) {
      print('Product ID not found: ${_kProSubscriptionId}');
      return;
    }
    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Initiates a subscription cancellation process.
  /// This should be called before account deletion.
  Future<void> cancelSubscription() async {
    if (_user == null) {
      print('No user logged in to cancel subscription for.');
      return;
    }
    final userId = _user!.uid;

    if (Platform.isIOS) {
      // For Apple platforms, you must provide a link to their subscription management page.
      final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('Redirecting to Apple subscription management page.');
      }
    } else if (Platform.isAndroid) {
        final uri = Uri.parse('https://play.google.com/store/account/subscriptions');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          print('Redirecting to Google Play subscription management page.');
        }
    } else {
      // For Stripe (web/other), we can trigger a backend function.
      print('Triggering Stripe subscription cancellation via backend...');
      final docRef = _firestore.collection('users').doc(userId).collection('stripe_commands').doc();
      await docRef.set({
        'command': 'cancel_subscription',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }
}
