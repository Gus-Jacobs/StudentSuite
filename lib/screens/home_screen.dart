import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/mixins/tutorial_support_mixin.dart';
import 'package:student_suite/models/tutorial_step.dart';
import '../providers/theme_provider.dart';
import 'planner_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/post_login_upgrade_dialog.dart';
import 'career_screen.dart';
import 'search_screen.dart';
import 'study_screen.dart';
import 'settings_screen.dart';
import '../widgets/profile_avatar.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/tutorial_provider.dart';
import '../widgets/app_bar_pomodoro_widget.dart';
import '../widgets/tutorial_dialog.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';
import '../screens/notes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TutorialSupport<HomeScreen> {
  int _selectedIndex = 0;

  final GlobalKey<PlannerScreenState> _plannerKey =
      GlobalKey<PlannerScreenState>();

  late final List<Map<String, dynamic>> _screens;

  @override
  String get tutorialKey => 'home';

  @override
  List<TutorialStep> get tutorialSteps => const [
        TutorialStep(
            icon: Icons.dashboard_customize_outlined,
            title: 'Welcome to Your Dashboard!',
            description:
                'This is your central hub. You can navigate to all the tools from the bottom bar.'),
        TutorialStep(
            icon: Icons.search,
            title: 'Universal Search',
            description:
                'Use the search icon in the top right to instantly find any of your notes, flashcards, or AI lessons.'),
      ];

  @override
  void initState() {
    super.initState();

    _screens = [
      {
        'widget': PlannerScreen(
          key: _plannerKey,
          onCalendarToggle: _updateAppBarAndFAB,
        ),
        'title': 'Dashboard'
      },
      {'widget': const StudyScreen(), 'title': 'Study Tools'},
      {'widget': const CareerScreen(), 'title': 'Career Center'},
      {'widget': const SettingsScreen(), 'title': 'Settings'},
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeShowPostLoginDialog();
      }
    });
  }

  void _maybeShowPostLoginDialog() {
    final subscription = context.read<SubscriptionProvider>();
    final tutorialProvider = context.read<TutorialProvider>();
    const dialogKey = 'post_login_upgrade_dialog';

    if (!subscription.isSubscribed && !tutorialProvider.hasSeen(dialogKey)) {
      if (mounted) {
        showPostLoginUpgradeDialog(context);
        tutorialProvider.markAsSeen(dialogKey);
      }
    }
  }

  void _updateAppBarAndFAB() {
    setState(() {
      print(
          'HomeScreen: _updateAppBarAndFAB called, HomeScreen rebuild triggered. (App bar should update)');
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final pomodoroProvider = context.watch<PomodoroProvider>();
    final auth = context.watch<AuthProvider>();
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

    // This is the correct way to get the state of the child widget
    final PlannerScreenState? plannerState =
        _selectedIndex == 0 ? _plannerKey.currentState : null;

    final bool isCalendarView = plannerState?.isCalendarView ?? false;
    print(
        'HomeScreen: isCalendarView (from plannerState) = $isCalendarView. Selected Index: $_selectedIndex');

    final String appBarTitle = _selectedIndex == 0
        ? (plannerState?.currentTitle ?? _screens[0]['title'])
        : _screens[_selectedIndex]['title'];

    return Container(
      decoration: backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            appBarTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: currentTheme.navBarColor,
          elevation: 0,
          actions: [
            if (pomodoroProvider.isRunning &&
                !pomodoroProvider.isPomodoroScreenVisible)
              const AppBarPomodoroWidget(),
            if (_selectedIndex ==
                0) // Only show calendar toggle on Planner screen
              IconButton(
                key: const ValueKey('calendar_toggle_button'),
                icon: Icon(isCalendarView
                    ? Icons.dashboard_outlined
                    : Icons.calendar_today),
                tooltip: isCalendarView ? 'Show Dashboard' : 'Show Calendar',
                onPressed: () {
                  final currentPlannerState = _plannerKey.currentState;
                  print('HomeScreen: Calendar toggle button pressed.');
                  print(
                      'HomeScreen: _plannerKey.currentState is $currentPlannerState');
                  print(
                      'HomeScreen: isCalendarView before toggle: ${currentPlannerState?.isCalendarView}');

                  if (currentPlannerState != null) {
                    currentPlannerState.toggleCalendarView();
                    // Small delay to observe state after setState has a chance to propagate
                    Future.delayed(const Duration(milliseconds: 50), () {
                      print(
                          'HomeScreen: isCalendarView AFTER toggle (delayed): ${currentPlannerState.isCalendarView}');
                    });
                  } else {
                    print(
                        'HomeScreen ERROR: _plannerKey.currentState is NULL. Cannot toggle calendar.');
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help',
              onPressed: showTutorialDialog,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                  child: ProfileAvatar(
                    imageUrl: auth.profilePictureURL,
                    frameName: auth.profileFrame,
                    radius: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              // We must pass the actual widget instances here, initialized once.
              // The PlannerScreen's internal state manages its own visibility.
              children: _screens.map<Widget>((s) => s['widget']).toList(),
            ),
          ],
        ),
        floatingActionButton: _selectedIndex == 0
            ? FloatingActionButton(
                heroTag: 'planner_fab',
                onPressed: () {
                  final DateTime dateForDialog = (plannerState != null &&
                          plannerState.isCalendarView &&
                          plannerState.selectedDay != null)
                      ? plannerState.selectedDay!
                      : DateTime.now();
                  print(
                      'HomeScreen: FAB pressed. dateForDialog: $dateForDialog, plannerState: $plannerState');
                  // Call the showTaskDialog method directly on the PlannerScreenState
                  plannerState?.showTaskDialog(selectedDate: dateForDialog);
                },
                tooltip: 'Add Task',
                child: const Icon(Icons.add),
              )
            : null,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
              print('HomeScreen: Bottom nav index changed to $_selectedIndex');
              // If navigating away from Planner screen while calendar is open, close it
              if (index != 0 && (plannerState?.isCalendarView ?? false)) {
                print(
                    'HomeScreen: Navigating away from Planner. Calendar was open, closing it.');
                plannerState
                    ?.toggleCalendarView(); // This will also trigger _updateAppBarAndFAB
              }
            });
          },
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.event_note), label: 'Planner'),
            BottomNavigationBarItem(
                icon: Icon(Icons.menu_book), label: 'Study'),
            BottomNavigationBarItem(
                icon: Icon(Icons.work), label: 'Career'), // FIXED
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
          ],
          backgroundColor: currentTheme.navBarColor,
          selectedItemColor: currentTheme.primaryAccent,
          unselectedItemColor:
              (currentTheme.navBarBrightness == Brightness.light
                      ? Colors.white
                      : Colors.black)
                  .withOpacity(0.7),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildNotesScreen(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final notesBox = auth.notesBox;
    if (notesBox.isOpen) {
      return const NotesScreen();
    }
    return const Center(child: CircularProgressIndicator());
  }
}
