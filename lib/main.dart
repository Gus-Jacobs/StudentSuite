import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:student_suite/widgets/themed_loading_overlay.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/models/ai_interview_session.dart';
import 'package:student_suite/models/ai_teacher_session.dart';
import 'package:student_suite/models/flashcard.dart';
import 'package:student_suite/models/subject.dart';
import 'package:student_suite/models/resume_data.dart';
import 'package:student_suite/models/flashcard_deck.dart';
import 'package:student_suite/models/hive_chat_message.dart';
import 'package:student_suite/models/note.dart';
import 'package:student_suite/models/task.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/providers/pomodoro_provider.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:student_suite/providers/tutorial_provider.dart';
import 'package:student_suite/screens/account_settings_screen.dart';
import 'package:student_suite/screens/ai_interviewer_screen.dart';
import 'package:student_suite/screens/ai_teacher_screen.dart';
import 'package:student_suite/screens/cover_letter_screen.dart';
import 'package:student_suite/screens/interview_tips_screen.dart';
import 'package:student_suite/screens/pomodoro_screen.dart';
import 'package:student_suite/screens/flashcard_screen.dart';
import 'package:student_suite/screens/font_settings_screen.dart';
import 'package:student_suite/screens/frame_settings_screen.dart';
import 'package:student_suite/screens/home_screen.dart';
import 'package:student_suite/screens/login_screen.dart';
import 'package:student_suite/screens/notes_screen.dart';
import 'package:student_suite/screens/onboarding_screen.dart';
import 'package:student_suite/screens/profile_screen.dart';
import 'package:student_suite/screens/resume_builder_screen.dart';
import 'package:student_suite/screens/signup_screen.dart';
import 'package:student_suite/screens/subject_manager_screen.dart';
import 'package:student_suite/screens/theme_settings_screen.dart';
import 'package:student_suite/firebase_options.dart';
import 'package:student_suite/services/ai_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter(); // Initialize Hive for Flutter

  // Register all Hive adapters (as you already have them)
  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(FlashcardAdapter());
  Hive.registerAdapter(FlashcardDeckAdapter());
  Hive.registerAdapter(HiveChatMessageAdapter()); // Ensure this is registered
  Hive.registerAdapter(AITeacherSessionAdapter());
  Hive.registerAdapter(AIInterviewSessionAdapter());
  Hive.registerAdapter(SubjectAdapter());
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(ResumeDataAdapter());
  Hive.registerAdapter(ContactInfoDataAdapter());
  Hive.registerAdapter(EducationDataAdapter());
  Hive.registerAdapter(ExperienceDataAdapter());
  Hive.registerAdapter(CertificateDataAdapter());

  // Open ALL global/guest boxes BEFORE initializing AuthProvider.
  // These boxes persist data for non-logged-in users and are used for migration.
  final guestNotesBox = await Hive.openBox<Note>('notes');
  final guestFlashcardDecksBox =
      await Hive.openBox<FlashcardDeck>('flashcardDecks');
  final guestSubjectsBox = await Hive.openBox<Subject>('subjects');
  final guestTasksBox = await Hive.openBox<Task>('tasks');
  final guestResumeDataBox = await Hive.openBox<ResumeData>('resumeData');
  // Note: AI session boxes and chat messages are typically user-specific,
  // so no global/guest versions are usually needed for them.

  await Hive.openBox(
      'pomodoro'); // Assuming pomodoro data is global/not user-specific for this box

  // Create and initialize tutorial provider
  final tutorialProvider = TutorialProvider();
  await tutorialProvider.init();

  // Create the AuthProvider instance
  final authProvider = AuthProvider();

  // Pass the opened guest boxes to the AuthProvider
  authProvider.setGuestNotesBox(guestNotesBox);
  authProvider.setGuestFlashcardDecksBox(guestFlashcardDecksBox);
  authProvider.setGuestSubjectsBox(guestSubjectsBox);
  authProvider.setGuestTasksBox(guestTasksBox);
  authProvider.setGuestResumeDataBox(guestResumeDataBox);

  // Initialize the AuthProvider. AWAIT this call to ensure auth state
  // and user-specific Hive boxes are resolved before the app builds.
  await authProvider.init();

  runApp(MyApp(
    tutorialProvider: tutorialProvider,
    authProvider: authProvider, // Pass the pre-initialized AuthProvider
  ));
}

class MyApp extends StatelessWidget {
  final TutorialProvider tutorialProvider;
  final AuthProvider authProvider; // AuthProvider is now passed in

  const MyApp({
    super.key,
    required this.tutorialProvider,
    required this.authProvider, // Update constructor to receive authProvider
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Use ChangeNotifierProvider.value to provide the pre-initialized authProvider
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProxyProvider<AuthProvider, ThemeProvider>(
          create: (_) => ThemeProvider(),
          update: (_, auth, previous) => previous!..updateForUser(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SubscriptionProvider>(
          create: (_) => SubscriptionProvider(),
          update: (_, auth, previous) => previous!..update(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, PomodoroProvider>(
          create: (_) => PomodoroProvider(),
          update: (_, auth, previous) => previous!..update(auth),
          lazy: false,
        ),
        ChangeNotifierProvider.value(value: tutorialProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // This Consumer is for applying theme data.
          return Consumer<AuthProvider>(
            builder: (context, auth, _) {
              // This Consumer is for showing the global loading overlay based on AuthProvider's state.
              return MaterialApp(
                title: 'Student Suite',
                theme: themeProvider.lightThemeData,
                darkTheme: themeProvider.darkThemeData,
                themeMode: themeProvider.themeMode,
                builder: (context, child) {
                  // Wrap the entire app with the loading overlay.
                  return ThemedLoadingOverlay(
                    isLoading: auth.isLoading,
                    child: child!,
                  );
                },
                home: const AuthGate(), // AuthGate decides initial screen
                routes: {
                  '/home': (context) => const HomeScreen(),
                  '/login': (context) => const LoginScreen(),
                  '/signup': (context) => const SignupScreen(),
                  '/profile': (context) => const ProfileScreen(),
                  '/account_settings': (context) =>
                      const AccountSettingsScreen(),
                  '/theme_settings': (context) => const ThemeSettingsScreen(),
                  '/font_settings': (context) => const FontSettingsScreen(),
                  '/frame_settings': (context) => const FrameSettingsScreen(),
                  '/notes': (context) => const NotesScreen(),
                  '/flashcards': (context) => const FlashcardScreen(),
                  '/ai_teacher': (context) => const AITeacherScreen(),
                  '/ai_interviewer': (context) => const AIInterviewerScreen(),
                  '/resume': (context) => const ResumeBuilderScreen(),
                  '/cover_letter': (context) => const CoverLetterScreen(),
                  '/subjects': (context) => const SubjectManagerScreen(),
                  '/pomodoro': (context) => const PomodoroScreen(),
                  '/interview_tips': (context) => const InterviewTipsScreen(),
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// AuthGate decides which screen to show based on the user's auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          // While AuthProvider is resolving the initial auth state,
          // show a minimal scaffold with the themed background.
          final themeProvider =
              Provider.of<ThemeProvider>(context, listen: false);
          return Scaffold(
            body: Container(
                decoration: BoxDecoration(
                    gradient: themeProvider.currentTheme.gradient)),
          );
        }
        // Once AuthProvider is no longer loading, determine which screen to show.
        if (auth.user == null) {
          return const OnboardingScreen(); // Show onboarding if not logged in
        } else {
          return const HomeScreen(); // Show home screen if logged in
        }
      },
    );
  }
}

/// A simple placeholder screen for features that are not yet implemented.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Center(
        child: Text(
          '$title is coming soon!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
