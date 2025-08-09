// The full, updated subscription_provider.dart file
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';

class SubscriptionProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get _user => _auth.currentUser;
  AuthProvider? _authProvider;

  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  String? _referralCode;
  String? get referralCode => _referralCode;

  void updateAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  SubscriptionProvider() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToUserSubscriptionStatus(user.uid);
      } else {
        _isSubscribed = false;
        _referralCode = null;
        notifyListeners();
      }
    });
  }

  void _listenToUserSubscriptionStatus(String userId) {
    _firestore.collection('users').doc(userId).snapshots().listen((docSnapshot) {
      final data = docSnapshot.data();
      if (data != null) {
        _isSubscribed = (data['stripeRole'] == 'pro');
        _referralCode = data['referralCode'];
      } else {
        _isSubscribed = false;
        _referralCode = null;
      }
      notifyListeners();
    });
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

  /// Initiates a subscription cancellation process.
  /// This should be called before account deletion.
  Future<void> cancelSubscription() async {
    if (_user == null) {
      print('No user logged in to cancel subscription for.');
      return;
    }
    final userId = _user!.uid;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // For Apple platforms, you must provide a link to their subscription management page.
      final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('Redirecting to Apple subscription management page.');
      }
    } else {
      // For Stripe, we can trigger a backend function to cancel the subscription.
      print('Triggering Stripe subscription cancellation via backend...');
      final docRef = _firestore.collection('users').doc(userId).collection('stripe_commands').doc();
      await docRef.set({
        'command': 'cancel_subscription',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }
}
