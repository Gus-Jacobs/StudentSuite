import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:student_suite/models/resume_data.dart';
import 'package:student_suite/models/ai_interview_session.dart';
import 'package:student_suite/models/ai_teacher_session.dart';
import 'package:student_suite/models/flashcard_deck.dart';
import 'package:student_suite/models/note.dart';
import 'package:student_suite/models/subject.dart';
import 'package:student_suite/models/task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:student_suite/models/hive_chat_message.dart';

class AuthProvider extends ChangeNotifier {
  // Firebase User object
  User? user;

  // State Flags
  bool _isLoading = true; // Use private for internal state
  String? error;

  // User Profile Data (from Firestore)
  String _displayName = '';
  String? profilePictureURL;
  String? stripeRole;
  bool isFounder = false;
  String? themeName;
  String? themeMode;
  double? fontSizeScale;
  String? profileFrame;
  String? fontFamily;

  // User-specific Hive boxes (private, assigned when user logs in)
  Box<Note>? _notesBox;
  Box<FlashcardDeck>? _flashcardDecksBox;
  Box<AITeacherSession>? _aiTeacherSessionsBox;
  Box<AIInterviewSession>? _aiInterviewSessionsBox;
  Box<Subject>? _subjectsBox;
  Box<Task>? _tasksBox;
  Box<ResumeData>? _resumeDataBox;
  Box<HiveChatMessage>? _chatMessagesBox;

  // Global/Guest Hive boxes (passed from main.dart)
  late Box<Note> _guestNotesBox;
  late Box<FlashcardDeck> _guestFlashcardDecksBox;
  late Box<Subject> _guestSubjectsBox;
  late Box<Task> _guestTasksBox;
  late Box<ResumeData> _guestResumeDataBox;

  // Public getters
  bool get isLoading => _isLoading; // Public getter for _isLoading

  // Getters for Hive Boxes with defensive checks
  Box<Note> get notesBox {
    if (user != null) {
      // If user is logged in, ensure _notesBox is not null and is open.
      // If it's null or closed, something went wrong in _openUserSpecificBoxes.
      assert(_notesBox != null && _notesBox!.isOpen,
          'User is logged in but _notesBox is null or closed. Check _openUserSpecificBoxes.');
      return _notesBox!;
    } else {
      // For a guest, return the global notes box. This should always be open.
      assert(_guestNotesBox.isOpen, '_guestNotesBox is not open.');
      return _guestNotesBox;
    }
  }

  Box<FlashcardDeck> get flashcardDecksBox {
    if (user != null) {
      assert(_flashcardDecksBox != null && _flashcardDecksBox!.isOpen,
          'User is logged in but _flashcardDecksBox is null or closed.');
      return _flashcardDecksBox!;
    }
    assert(
        _guestFlashcardDecksBox.isOpen, '_guestFlashcardDecksBox is not open.');
    return _guestFlashcardDecksBox;
  }

  Box<AITeacherSession> get aiTeacherSessionsBox {
    if (user != null) {
      assert(_aiTeacherSessionsBox != null && _aiTeacherSessionsBox!.isOpen,
          'User is logged in but _aiTeacherSessionsBox is null or closed.');
      return _aiTeacherSessionsBox!;
    }
    throw StateError(
        "AITeacherSessionBox is only available for logged-in users.");
  }

  Box<AIInterviewSession> get aiInterviewSessionsBox {
    if (user != null) {
      assert(_aiInterviewSessionsBox != null && _aiInterviewSessionsBox!.isOpen,
          'User is logged in but _aiInterviewSessionsBox is null or closed.');
      return _aiInterviewSessionsBox!;
    }
    throw StateError(
        "AIInterviewSessionBox is only available for logged-in users.");
  }

  Box<Subject> get subjectsBox {
    if (user != null) {
      assert(_subjectsBox != null && _subjectsBox!.isOpen,
          'User is logged in but _subjectsBox is null or closed.');
      return _subjectsBox!;
    }
    assert(_guestSubjectsBox.isOpen, '_guestSubjectsBox is not open.');
    return _guestSubjectsBox;
  }

  Box<Task> get tasksBox {
    if (user != null) {
      assert(_tasksBox != null && _tasksBox!.isOpen,
          'User is logged in but _tasksBox is null or closed.');
      return _tasksBox!;
    }
    assert(_guestTasksBox.isOpen, '_guestTasksBox is not open.');
    return _guestTasksBox;
  }

  Box<ResumeData> get resumeDataBox {
    if (user != null) {
      assert(_resumeDataBox != null && _resumeDataBox!.isOpen,
          'User is logged in but _resumeDataBox is null or closed.');
      return _resumeDataBox!;
    }
    assert(_guestResumeDataBox.isOpen, '_guestResumeDataBox is not open.');
    return _guestResumeDataBox;
  }

  Box<HiveChatMessage> get chatMessagesBox {
    if (user != null) {
      assert(_chatMessagesBox != null && _chatMessagesBox!.isOpen,
          'User is logged in but _chatMessagesBox is null or closed.');
      return _chatMessagesBox!;
    }
    throw StateError("ChatMessagesBox is only available for logged-in users.");
  }

  // Setters for guest boxes (called from main.dart during app startup)
  void setGuestNotesBox(Box<Note> box) => _guestNotesBox = box;
  void setGuestFlashcardDecksBox(Box<FlashcardDeck> box) =>
      _guestFlashcardDecksBox = box;
  void setGuestSubjectsBox(Box<Subject> box) => _guestSubjectsBox = box;
  void setGuestTasksBox(Box<Task> box) => _guestTasksBox = box;
  void setGuestResumeDataBox(Box<ResumeData> box) => _guestResumeDataBox = box;

  // Internal state
  final _secureStorage = const FlutterSecureStorage();
  StreamSubscription<DocumentSnapshot>? _userProfileSubscription;
  Completer<void>? _profileLoadCompleter;
  final bool _isPersistenceEnabled = true;

  // --- Getters ---
  String get displayName => _displayName;
  bool get isPro => stripeRole == 'pro';

  // --- Initialization ---
  AuthProvider();

  Future<void> _configurePersistence() async {
    try {
      if (_isPersistenceEnabled) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      } else {
        await FirebaseAuth.instance.setPersistence(Persistence.NONE);
      }
    } catch (e) {
      debugPrint('Error setting persistence: $e');
    }
  }

  Future<void> init() async {
    _isLoading = true; // Use _isLoading
    error = null;
    notifyListeners();

    await _configurePersistence();

    FirebaseAuth.instance.authStateChanges().listen((newUser) async {
      debugPrint(
          'Auth state changed: user is ${newUser == null ? 'null' : newUser.uid}');
      _userProfileSubscription?.cancel();

      if (newUser == null) {
        user = null;
        _resetProfileData();
        await _closeUserSpecificBoxes();
        _isLoading = false; // Use _isLoading
        _profileLoadCompleter?.complete();
        _profileLoadCompleter = null;
        notifyListeners();
      } else {
        user = newUser;
        _profileLoadCompleter ??= Completer<void>();

        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(newUser.uid);
        final userDoc = await userDocRef.get();
        if (userDoc.exists && userDoc.data()?['email'] != newUser.email) {
          await userDocRef.update({'email': newUser.email});
        }

        await _migrateGuestData(newUser.uid);
        // This is the CRITICAL part: Ensure user-specific boxes are opened and assigned.
        await _openUserSpecificBoxes(newUser.uid);

        _listenToUserProfile(newUser.uid);
        // _isLoading remains true until the profile is fetched by the listener.
        // notifyListeners() will be called once profile data is loaded.
      }
    });
  }

  void _listenToUserProfile(String uid) {
    _userProfileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      debugPrint('User profile snapshot received.');
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _displayName = data['displayName'] ?? user?.displayName ?? '';
        profilePictureURL = data['photoURL'] ?? user?.photoURL;
        stripeRole = data['stripeRole'];
        isFounder = data['isFounder'] ?? false;
        themeName = data['themeName'];
        themeMode = data['themeMode'];
        fontSizeScale = (data['fontSizeScale'] as num?)?.toDouble();
        profileFrame = data['profileFrame'];
        fontFamily = data['fontFamily'];
      } else {
        _resetProfileData(useAuthObjectDefaults: true);
      }
      _isLoading = false; // Use _isLoading
      error = null;
      _profileLoadCompleter?.complete();
      _profileLoadCompleter = null;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error loading user profile: $e');
      error = "Failed to load user profile.";
      _isLoading = false; // Use _isLoading
      _resetProfileData();
      _profileLoadCompleter?.completeError(e);
      _profileLoadCompleter = null;
      notifyListeners();
    });
  }

  void _resetProfileData({bool useAuthObjectDefaults = false}) {
    if (useAuthObjectDefaults && user != null) {
      _displayName = user!.displayName ?? user!.email?.split('@').first ?? '';
      profilePictureURL = user!.photoURL;
    } else {
      _displayName = '';
      profilePictureURL = null;
    }
    stripeRole = null;
    isFounder = false;
    themeName = null;
    themeMode = null;
    fontSizeScale = null;
    profileFrame = null;
    fontFamily = null;
  }

  // --- Hive Box Management ---

  Future<void> _migrateGuestData(String uid) async {
    // NOTES MIGRATION
    if (_guestNotesBox.isNotEmpty) {
      debugPrint("Migrating guest notes to user: $uid");
      final userNotesBox = await Hive.openBox<Note>('notes_$uid');
      for (var note in _guestNotesBox.values) {
        // Use .add() which assigns an auto-incrementing int key
        // This avoids requiring an explicit 'id' field on your Note model for Hive keys
        await userNotesBox.add(note);
      }
      await _guestNotesBox
          .clear(); // Clear guest notes after successful migration
      await userNotesBox.close(); // Close the user-specific box temporarily
      debugPrint("Guest notes migration complete.");
    }

    // FLASHCARD DECKS MIGRATION
    if (_guestFlashcardDecksBox.isNotEmpty) {
      debugPrint("Migrating guest flashcard decks to user: $uid");
      final userFlashcardDecksBox =
          await Hive.openBox<FlashcardDeck>('flashcardDecks_$uid');
      for (var deck in _guestFlashcardDecksBox.values) {
        await userFlashcardDecksBox.add(deck);
      }
      await _guestFlashcardDecksBox.clear();
      await userFlashcardDecksBox.close();
      debugPrint("Guest flashcard decks migration complete.");
    }

    // SUBJECTS MIGRATION
    if (_guestSubjectsBox.isNotEmpty) {
      debugPrint("Migrating guest subjects to user: $uid");
      final userSubjectsBox = await Hive.openBox<Subject>('subjects_$uid');
      for (var subject in _guestSubjectsBox.values) {
        await userSubjectsBox.add(subject);
      }
      await _guestSubjectsBox.clear();
      await userSubjectsBox.close();
      debugPrint("Guest subjects migration complete.");
    }

    // TASKS MIGRATION
    if (_guestTasksBox.isNotEmpty) {
      debugPrint("Migrating guest tasks to user: $uid");
      final userTasksBox = await Hive.openBox<Task>('tasks_$uid');
      for (var task in _guestTasksBox.values) {
        await userTasksBox.add(task);
      }
      await _guestTasksBox.clear();
      await userTasksBox.close();
      debugPrint("Guest tasks migration complete.");
    }

    // RESUME DATA MIGRATION
    if (_guestResumeDataBox.isNotEmpty) {
      debugPrint("Migrating guest resume data to user: $uid");
      final userResumeDataBox =
          await Hive.openBox<ResumeData>('resumeData_$uid');
      for (var resumeData in _guestResumeDataBox.values) {
        await userResumeDataBox.add(resumeData);
      }
      await _guestResumeDataBox.clear();
      await userResumeDataBox.close();
      debugPrint("Guest resume data migration complete.");
    }
  }

  // Opens all user-specific Hive boxes and assigns them to class members.
  Future<void> _openUserSpecificBoxes(String uid) async {
    debugPrint("Attempting to open user-specific boxes for UID: $uid");

    // Close any previously opened user-specific boxes to prevent conflicts.
    await _closeUserSpecificBoxes();

    // Open and assign each box individually to ensure _notesBox, etc., are set.
    try {
      _notesBox = await Hive.openBox<Note>('notes_$uid');
      debugPrint(
          'notes_$uid opened successfully. Is open: ${_notesBox!.isOpen}');

      _flashcardDecksBox =
          await Hive.openBox<FlashcardDeck>('flashcardDecks_$uid');
      debugPrint(
          'flashcardDecks_$uid opened successfully. Is open: ${_flashcardDecksBox!.isOpen}');

      _aiTeacherSessionsBox =
          await Hive.openBox<AITeacherSession>('aiTeacherSessions_$uid');
      debugPrint(
          'aiTeacherSessions_$uid opened successfully. Is open: ${_aiTeacherSessionsBox!.isOpen}');

      _aiInterviewSessionsBox =
          await Hive.openBox<AIInterviewSession>('aiInterviewSessions_$uid');
      debugPrint(
          'aiInterviewSessions_$uid opened successfully. Is open: ${_aiInterviewSessionsBox!.isOpen}');

      _subjectsBox = await Hive.openBox<Subject>('subjects_$uid');
      debugPrint(
          'subjects_$uid opened successfully. Is open: ${_subjectsBox!.isOpen}');

      _tasksBox = await Hive.openBox<Task>('tasks_$uid');
      debugPrint(
          'tasks_$uid opened successfully. Is open: ${_tasksBox!.isOpen}');

      _resumeDataBox = await Hive.openBox<ResumeData>('resumeData_$uid');
      debugPrint(
          'resumeData_$uid opened successfully. Is open: ${_resumeDataBox!.isOpen}');

      _chatMessagesBox =
          await Hive.openBox<HiveChatMessage>('chatMessages_$uid');
      debugPrint(
          'chatMessages_$uid opened successfully. Is open: ${_chatMessagesBox!.isOpen}');

      debugPrint(
          "All user-specific boxes assigned and verified as open for UID: $uid");
    } catch (e) {
      debugPrint("Error opening user-specific Hive boxes for UID $uid: $e");
      // Optionally re-throw or set an internal error state if this is critical
      // error = "Failed to load user data: $e"; // You might want to display this to the user
      // _isLoading = false;
      // notifyListeners();
    }
  }

  // Closes only the boxes that are specific to a logged-in user.
  Future<void> _closeUserSpecificBoxes() async {
    debugPrint("Attempting to close user-specific boxes.");
    // Only close if the box is not null and is currently open.
    await Future.wait([
      if (_notesBox != null && _notesBox!.isOpen) _notesBox!.close(),
      if (_flashcardDecksBox != null && _flashcardDecksBox!.isOpen)
        _flashcardDecksBox!.close(),
      if (_aiTeacherSessionsBox != null && _aiTeacherSessionsBox!.isOpen)
        _aiTeacherSessionsBox!.close(),
      if (_aiInterviewSessionsBox != null && _aiInterviewSessionsBox!.isOpen)
        _aiInterviewSessionsBox!.close(),
      if (_subjectsBox != null && _subjectsBox!.isOpen) _subjectsBox!.close(),
      if (_tasksBox != null && _tasksBox!.isOpen) _tasksBox!.close(),
      if (_resumeDataBox != null && _resumeDataBox!.isOpen)
        _resumeDataBox!.close(),
      if (_chatMessagesBox != null && _chatMessagesBox!.isOpen)
        _chatMessagesBox!.close(),
    ]).catchError((e) {
      debugPrint("Error closing one or more user-specific boxes: $e");
    });

    // Explicitly set references to null after closing
    _notesBox = null;
    _flashcardDecksBox = null;
    _aiTeacherSessionsBox = null;
    _aiInterviewSessionsBox = null;
    _subjectsBox = null;
    _tasksBox = null;
    _resumeDataBox = null;
    _chatMessagesBox = null;
    debugPrint("All user-specific box references set to null.");
  }

  // --- Authentication Methods (Restored and Unchanged from your original) ---

  Future<bool> signUp(String email, String password,
      {String? referralCode}) async {
    _isLoading = true; // Use _isLoading
    error = null;
    notifyListeners();

    _profileLoadCompleter = Completer<void>();

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = cred.user;
      if (user == null) throw Exception("User creation failed.");

      await _secureStorage.write(
          key: 'auth_token', value: await user!.getIdToken());

      _displayName = email.split('@').first; // Default display name
      await user!.updateDisplayName(_displayName);

      String? referredBy;
      if (referralCode != null && referralCode.isNotEmpty) {
        try {
          final HttpsCallable callable =
              FirebaseFunctions.instance.httpsCallable('validateReferralCode');
          final result =
              await callable.call<Map<String, dynamic>>({'code': referralCode});
          referredBy = result.data['referrerId'];
        } on FirebaseFunctionsException catch (e) {
          debugPrint(
              "Referral code check failed: ${e.code} - ${e.message}. Proceeding without referral.");
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'email': email,
        'displayName': _displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'stripeRole': 'free',
        'photoURL': null,
        'uid_prefix': user!.uid.substring(0, 8).toUpperCase(),
        if (referredBy != null) 'referredBy': referredBy,
      }, SetOptions(merge: true));

      await _profileLoadCompleter!.future;
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.message;
      _isLoading = false; // Use _isLoading
      _profileLoadCompleter?.complete();
      _profileLoadCompleter = null;
      notifyListeners();
      return false;
    } catch (e) {
      error = 'An unexpected error occurred during sign up.';
      _isLoading = false; // Use _isLoading
      _profileLoadCompleter?.complete();
      _profileLoadCompleter = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true; // Use _isLoading
    error = null;
    notifyListeners();

    _profileLoadCompleter = Completer<void>();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _profileLoadCompleter!.future;
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.message;
      _isLoading = false; // Use _isLoading
      _profileLoadCompleter?.complete();
      _profileLoadCompleter = null;
      notifyListeners();
      return false;
    } catch (e) {
      error = 'An unexpected error occurred during login.';
      _isLoading = false; // Use _isLoading
      _profileLoadCompleter?.complete();
      _profileLoadCompleter = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _userProfileSubscription?.cancel();
    _userProfileSubscription = null;

    await FirebaseAuth.instance.signOut();

    await _secureStorage.delete(key: 'auth_token');

    debugPrint('User logged out.');
  }

  // --- Profile Management ---

  Future<void> updateDisplayName(String newDisplayName) async {
    if (user == null) return;

    try {
      await user!.updateDisplayName(newDisplayName);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'displayName': newDisplayName});
      error = null;
    } catch (e) {
      error = 'Failed to update display name.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProfilePicture() async {
    if (user == null) return;

    final imagePicker = ImagePicker();
    final XFile? file = await imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);

    if (file == null) return;

    _isLoading = true; // Use _isLoading
    error = null;
    notifyListeners();

    try {
      final ref = FirebaseStorage.instance.ref('profile_pics/${user!.uid}');
      UploadTask uploadTask;

      if (kIsWeb) {
        uploadTask = ref.putData(await file.readAsBytes());
      } else {
        uploadTask = ref.putFile(File(file.path));
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String photoURL = await snapshot.ref.getDownloadURL();

      await user!.updatePhotoURL(photoURL);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'photoURL': photoURL});

      error = null;
    } catch (e) {
      error = "Failed to upload image: $e";
    } finally {
      _isLoading = false; // Use _isLoading
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true; // Use _isLoading
    error = null;
    notifyListeners();
    bool success = false;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      success = true;
    } on FirebaseAuthException catch (e) {
      error = e.message;
      if (e.code == 'user-not-found') {
        error = 'No user found for that email.';
      } else if (e.code == 'invalid-email') {
        error = 'The email address is not valid.';
      }
      success = false;
    } finally {
      _isLoading = false; // Use _isLoading
      notifyListeners();
    }
    return success;
  }

  // --- Account Management ---

  Future<void> _reauthenticate(String password) async {
    if (user == null || user!.email == null) {
      throw Exception('Not logged in or user email is missing.');
    }
    final cred =
        EmailAuthProvider.credential(email: user!.email!, password: password);
    await user!.reauthenticateWithCredential(cred);
  }

  Future<void> updateUserEmail(String newEmail, String currentPassword) async {
    if (user == null) return;
    _isLoading = true; // Use _isLoading
    error = null;
    notifyListeners();
    try {
      await _reauthenticate(currentPassword);
      await user!.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      error = e.message;
      rethrow;
    } finally {
      _isLoading = false; // Use _isLoading
      notifyListeners();
    }
  }

  Future<void> updateUserPassword(
      String newPassword, String currentPassword) async {
    if (user == null) return;
    _isLoading = true; // Use _isLoading
    error = null;
    notifyListeners();
    try {
      await _reauthenticate(currentPassword);
      await user!.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      error = e.message;
      rethrow;
    } finally {
      _isLoading = false; // Use _isLoading
      notifyListeners();
    }
  }

  Future<void> deleteAccount(String password) async {
    if (user == null) {
      throw Exception('Not logged in.');
    }
    _isLoading = true; // Use _isLoading
    error = null;
    notifyListeners();
    try {
      await _reauthenticate(password);
      await user!.delete();
    } on FirebaseAuthException catch (e) {
      error = e.message;
      _isLoading = false; // Use _isLoading
      notifyListeners();
      rethrow;
    } catch (e) {
      error = 'An unexpected error occurred while deleting the account.';
      _isLoading = false; // Use _isLoading
      notifyListeners();
      rethrow;
    }
  }

  // --- Preferences ---

  Future<void> updateUserPreferences(Map<String, dynamic> preferences) async {
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update(preferences);
      error = null;
    } catch (e) {
      error = 'Failed to save preferences.';
      notifyListeners();
    }
  }
}
