import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import 'dart:ui'; // For ImageFilter
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/models/task.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/widgets/error_dialog.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:student_suite/widgets/glass_action_tile.dart';
import 'package:student_suite/widgets/profile_avatar.dart';
import 'task_manager_dialog.dart';
import 'dart:math';

// --- Helper Classes and Functions ---

bool isSameDay(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;

// --- Main Widget ---

class PlannerScreen extends StatefulWidget {
  final VoidCallback? onCalendarToggle;

  const PlannerScreen({super.key, this.onCalendarToggle});

  @override
  PlannerScreenState createState() => PlannerScreenState();
}

class PlannerScreenState extends State<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _taskCompleteAnimationController;
  late Animation<double> _taskCompleteAnimation;

  // --- View State ---
  bool _isCalendarView = false; // This is the crucial boolean

  final ValueNotifier<Map<DateTime, List<Task>>> _tasksNotifier =
      ValueNotifier({});

  // --- Calendar State ---
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 400));

    _taskCompleteAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _taskCompleteAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _taskCompleteAnimationController,
        curve: Curves.easeOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasks();
      context
          .read<AuthProvider>()
          .tasksBox
          .listenable()
          .addListener(_loadTasks);
    });
  }

  @override
  void dispose() {
    _tasksNotifier.dispose();
    _confettiController.dispose();
    _taskCompleteAnimationController.dispose();
    if (mounted) {
      context
          .read<AuthProvider>()
          .tasksBox
          .listenable()
          .removeListener(_loadTasks);
    }
    super.dispose();
  }

  // --- Public Getters & Methods for HomeScreen ---

  bool get isCalendarView => _isCalendarView;
  String get currentTitle =>
      _isCalendarView ? DateFormat.yMMMM().format(_focusedDay) : 'Dashboard';

  DateTime? get selectedDay => _selectedDay;

  void toggleCalendarView() {
    print(
        'PlannerScreenState: toggleCalendarView called. Current _isCalendarView: $_isCalendarView');
    setState(() {
      _isCalendarView = !_isCalendarView;
      print(
          'PlannerScreenState: _isCalendarView SET to $_isCalendarView'); // Crucial confirmation
    });
    // Notify the parent (HomeScreen) to rebuild its AppBar,
    // which then reads the updated `isCalendarView` from this state.
    widget.onCalendarToggle?.call();
  }

  // --- Data Handling ---

  Future<void> _loadTasks() async {
    if (!mounted) return;
    try {
      final box = context.read<AuthProvider>().tasksBox;
      if (!box.isOpen) return;

      final allTasks = box.values.toList();
      final Map<DateTime, List<Task>> loadedTasks = {};
      for (var task in allTasks) {
        final dateKey =
            DateTime(task.date.year, task.date.month, task.date.day);
        loadedTasks.putIfAbsent(dateKey, () => []).add(task);
      }
      _tasksNotifier.value = loadedTasks;
    } catch (e) {
      if (mounted) {
        showErrorDialog(
            context, "Failed to load tasks. Data might be corrupt.");
      }
    }
  }

  List<Task> _getTasksForDay(DateTime day, Map<DateTime, List<Task>> tasks) {
    final dateKey = DateTime(day.year, day.month, day.day);
    final dayTasks = tasks[dateKey] ?? [];
    return List<Task>.from(dayTasks)
      ..sort((a, b) {
        if (a.isCompleted && !b.isCompleted) return 1;
        if (!a.isCompleted && b.isCompleted) return -1;
        return a.date.compareTo(b.date);
      });
  }

  // --- Task Modification Methods (now called by TaskManagerDialog) ---

  void _updateTask(Task taskToUpdate) {
    final currentTasks = Map<DateTime, List<Task>>.from(_tasksNotifier.value);
    final dateKey = DateTime(
        taskToUpdate.date.year, taskToUpdate.date.month, taskToUpdate.date.day);

    if (currentTasks.containsKey(dateKey)) {
      final List<Task> dayTasks = currentTasks[dateKey]!;
      final index = dayTasks.indexWhere((t) => t.id == taskToUpdate.id);
      if (index != -1) {
        dayTasks[index] = taskToUpdate;
        // Confetti logic only for dashboard task completion, if applicable
        if (taskToUpdate.isCompleted &&
            isSameDay(taskToUpdate.date, DateTime.now())) {
          _taskCompleteAnimationController.forward(from: 0.0).then((_) {
            _taskCompleteAnimationController.reverse();
            _confettiController.play(); // Confetti on dashboard task completion
          });
        }
      }
    }
    _tasksNotifier.value = currentTasks;
    taskToUpdate.save(); // Persist the change
  }

  void _addTask(Task newTask) {
    final newTasks = Map<DateTime, List<Task>>.from(_tasksNotifier.value);
    final dateKey =
        DateTime(newTask.date.year, newTask.date.month, newTask.date.day);
    final dayTasks = newTasks.putIfAbsent(dateKey, () => []);

    dayTasks.add(newTask);
    _tasksNotifier.value = newTasks; // Update notifier
    final box = context.read<AuthProvider>().tasksBox;
    box.put(newTask.id, newTask); // Persist
  }

  void _deleteTask(Task taskToDelete) {
    final newTasks = Map<DateTime, List<Task>>.from(_tasksNotifier.value);
    final dateKey = DateTime(
        taskToDelete.date.year, taskToDelete.date.month, taskToDelete.date.day);
    final dayTasks = newTasks[dateKey];
    if (dayTasks == null) return;

    dayTasks.removeWhere((t) => t.id == taskToDelete.id);

    if (dayTasks.isEmpty) {
      newTasks.remove(dateKey);
    }
    _tasksNotifier.value = newTasks; // Update notifier
    taskToDelete.delete(); // Persist
    // Confetti on dashboard delete (as per request)
    if (isSameDay(taskToDelete.date, DateTime.now())) {
      _confettiController.play();
    }
  }

  // This method now opens the TaskManagerDialog with custom animation
  void showTaskDialog({DateTime? selectedDate}) async {
    final dateForDialog = selectedDate ?? DateTime.now();
    final tasksForSelectedDay =
        _getTasksForDay(dateForDialog, _tasksNotifier.value);

    // Using showGeneralDialog for custom transition
    await showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) {
        return TaskManagerDialog(
          selectedDate: dateForDialog,
          tasksForDay: tasksForSelectedDay,
          onAddTask: _addTask,
          onUpdateTask: _updateTask,
          onDeleteTask: _deleteTask,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Scale and Fade transition
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.5),
    );
    // After TaskManagerDialog closes, reload tasks to reflect any changes and update markers.
    _loadTasks();
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();

    print(
        'PlannerScreenState: Building. Current _isCalendarView: $_isCalendarView');

    return ValueListenableBuilder<Map<DateTime, List<Task>>>(
      valueListenable: _tasksNotifier,
      builder: (context, tasks, _) {
        return Stack(
          children: [
            _buildDashboardView(tasks),
            // The calendar overlay, conditionally visible based on _isCalendarView
            _buildCalendarOverlay(tasks),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: -pi / 2,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.1,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarOverlay(Map<DateTime, List<Task>> tasks) {
    final theme = Theme.of(context);

    print(
        'PlannerScreenState: _buildCalendarOverlay is building. _isCalendarView: $_isCalendarView, ignoring: ${!_isCalendarView}, opacity: ${_isCalendarView ? 1.0 : 0.0}');

    return IgnorePointer(
      ignoring: !_isCalendarView,
      child: AnimatedOpacity(
        opacity: _isCalendarView ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
        child: SizedBox.expand(
          child: Material(
            color: Colors.black.withOpacity(0.6),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Center(
                child: SingleChildScrollView(
                  child: Card(
                    margin: const EdgeInsets.all(12.0),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      eventLoader: (day) => _getTasksForDay(day, tasks),
                      calendarFormat: CalendarFormat.month,
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        // Open task manager dialog for the selected day
                        showTaskDialog(selectedDate: selectedDay);
                      },
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                        defaultTextStyle:
                            TextStyle(color: theme.colorScheme.onSurface),
                        weekendTextStyle: TextStyle(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.7)),
                        outsideTextStyle: TextStyle(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.4)),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: theme.textTheme.titleLarge!.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        leftChevronIcon: Icon(Icons.chevron_left,
                            color: theme.colorScheme.onSurface),
                        rightChevronIcon: Icon(Icons.chevron_right,
                            color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardView(Map<DateTime, List<Task>> tasks) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final todaysTasks = _getTasksForDay(todayKey, tasks);

    return ListView(
      key: const ValueKey('dashboard'), // Key helps Flutter optimize rebuilds
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            ProfileAvatar(
              imageUrl: auth.profilePictureURL,
              frameName: auth.profileFrame,
              radius: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Welcome, ${auth.displayName}!',
                style: theme.textTheme.headlineSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('Manage Courses', style: theme.textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 8),
        GlassActionTile(
          icon: Icons.book_outlined,
          title: 'Courses',
          onTap: () => Navigator.pushNamed(context, '/subjects'),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text("Today's Tasks", style: theme.textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 8),
        todaysTasks.isEmpty
            ? Card(
                color: theme.brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'No tasks for today. Time for a break!',
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add a new task with the + button below.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children:
                    todaysTasks.map((task) => _buildTaskTile(task)).toList(),
              ),
        const SizedBox(height: 70),
      ],
    );
  }

  Widget _buildTaskTile(Task task) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tileColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

    return AnimatedBuilder(
      animation: _taskCompleteAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: task.isCompleted ? _taskCompleteAnimation.value : 1.0,
          child: Card(
            color: tileColor,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Checkbox(
                value: task.isCompleted,
                onChanged: (val) {
                  task.isCompleted = val!;
                  _updateTask(task); // This will now trigger confetti
                },
              ),
              title: Text(
                task.title,
                style: TextStyle(
                  decoration:
                      task.isCompleted ? TextDecoration.lineThrough : null,
                  color: theme.colorScheme.onSurface,
                  fontWeight:
                      task.isCompleted ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              subtitle: task.description.isNotEmpty
                  ? Text(
                      task.description,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    onPressed: () => showTaskDialog(
                        selectedDate:
                            task.date), // Open task manager for this task's day
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: () =>
                        _deleteTask(task), // This will trigger explode/confetti
                  ),
                ],
              ),
              onTap: () => showTaskDialog(
                  selectedDate:
                      task.date), // Open task manager for this task's day
            ),
          ),
        );
      },
    );
  }
}
