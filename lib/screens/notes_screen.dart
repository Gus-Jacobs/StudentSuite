import 'package:flutter/material.dart';
import 'dart:ui'; // For ImageFilter
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/mixins/tutorial_support_mixin.dart';
import 'package:student_suite/models/note.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/models/tutorial_step.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import 'package:student_suite/services/ai_service.dart';
import 'package:student_suite/widgets/error_dialog.dart';
import 'package:student_suite/widgets/upgrade_dialog.dart';
import '../providers/theme_provider.dart';
import '../providers/tutorial_provider.dart';
import '../widgets/tutorial_dialog.dart';
import 'dart:math';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with TutorialSupport<NotesScreen> {
  final AiService _aiService = AiService();
  bool _isAiLoading = false;
  String? _activeNoteId; // Track the note being dragged or clicked

  @override
  String get tutorialKey => 'notes';

  @override
  List<TutorialStep> get tutorialSteps => const [
        TutorialStep(
            icon: Icons.add_circle_outline,
            title: 'Add Notes Manually',
            description:
                "Tap the '+' button to create a new note for any subject."),
        TutorialStep(
            icon: Icons.auto_awesome_outlined,
            title: 'Generate with AI',
            description:
                "Use the magic wand icon to get a concise study tip or definition for any topic, saved instantly as a note."),
      ];

  Future<void> _addNote(Note newNote) async {
    final box = context.read<AuthProvider>().notesBox;
    await box.put(newNote.id, newNote);
    await box.flush(); // Ensure data is written to IndexedDB
  }

  Future<void> _deleteNote(Note note) async {
    // The note object is a HiveObject, so we can call delete on it directly.
    await note.delete();
    await context
        .read<AuthProvider>()
        .notesBox
        .flush(); // Explicitly flush for web
  }

  void _showAddNoteDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a New Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Type your note here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addNote(Note.create(content: controller.text.trim()));
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAiGenerateDialog() {
    final topicController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Study Tip'),
        content: TextField(
          controller: topicController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Topic',
            hintText: 'e.g., "The Krebs Cycle"',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (topicController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(); // Close dialog first
                await _runAiGeneration(topicController.text.trim());
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Future<void> _runAiGeneration(String topic) async {
    setState(() => _isAiLoading = true);
    try {
      final noteContent = await _aiService.generateStudyNote(topic: topic);
      await _addNote(Note.create(content: noteContent, isAiGenerated: true));
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Failed to generate note: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isAiLoading = false);
      }
    }
  }

  void _bringNoteToFront(String noteId) {
    setState(() {
      _activeNoteId = noteId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final subscription = Provider.of<SubscriptionProvider>(context);
    final currentTheme = themeProvider.currentTheme;

    BoxDecoration backgroundDecoration;
    if (currentTheme.imageAssetPath != null) {
      backgroundDecoration = BoxDecoration(
        image: DecorationImage(
          image: AssetImage(currentTheme.imageAssetPath!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
            BlendMode.darken,
          ),
        ),
      );
    } else {
      backgroundDecoration = BoxDecoration(gradient: currentTheme.gradient);
    }

    return Container(
      decoration: backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Notes'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (_isAiLoading)
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white))),
              )
            else
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Help',
                onPressed: showTutorialDialog,
              ),
            IconButton(
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: () {
                if (!subscription.isSubscribed) {
                  showUpgradeDialog(context);
                } else {
                  _showAiGenerateDialog();
                }
              },
              tooltip: 'Generate Study Tip with AI (Pro)',
            ),
          ],
        ),
        body: ValueListenableBuilder<Box<Note>>(
          valueListenable: authProvider.notesBox.listenable(),
          builder: (context, box, _) {
            final notes = box.values.toList();
            if (notes.isEmpty) {
              return const Center(child: Text('No notes yet.'));
            }
            // Bring the active note to the top of the stack
            List<Note> sortedNotes = List.from(notes);
            if (_activeNoteId != null) {
              sortedNotes.sort((a, b) {
                if (a.id == _activeNoteId) return 1;
                if (b.id == _activeNoteId) return -1;
                return 0;
              });
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    for (final note in sortedNotes)
                      DraggableNoteCard(
                        note: note,
                        onDelete: () async => await _deleteNote(note),
                        onDragEnd: (offset) async {
                          // The note's posX and posY are updated by the drag gesture.
                          await note
                              .save(); // We just need to call save() on the HiveObject to persist the changes.
                          await context.read<AuthProvider>().notesBox.flush();
                        },
                        onTap: () => _bringNoteToFront(note.id),
                        isActive: note.id == _activeNoteId,
                      ),
                  ],
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddNoteDialog,
          tooltip: 'Add Note',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _GlassNoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onDelete;

  const _GlassNoteCard({
    required this.note,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurfaceColor = theme.colorScheme.onSurface;

    final glassColor =
        isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1);
    final glassBorderColor =
        isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 80,
            maxWidth: 260,
            minHeight: 40,
            maxHeight: 400,
          ),
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: glassBorderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
                child: Text(
                  note.content,
                  style: TextStyle(
                    fontSize: 16,
                    color: onSurfaceColor,
                    shadows: const [
                      Shadow(blurRadius: 2, color: Colors.black38)
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 18, color: onSurfaceColor),
                  ),
                ),
              ),
              if (note.isAiGenerated)
                Positioned(
                  bottom: 6,
                  left: 8,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: onSurfaceColor.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DraggableNoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onDelete;
  final Function(Offset) onDragEnd;
  final VoidCallback onTap;
  final bool isActive;

  const DraggableNoteCard({
    required this.note,
    required this.onDelete,
    required this.onDragEnd,
    required this.onTap,
    required this.isActive,
    super.key,
  });

  @override
  State<DraggableNoteCard> createState() => _DraggableNoteCardState();
}

class _DraggableNoteCardState extends State<DraggableNoteCard> {
  Offset? _dragStart;
  Offset? _startPos;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.note.posX,
      top: widget.note.posY,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (details) {
          setState(() {
            _dragging = true;
            _dragStart = details.globalPosition;
            _startPos = Offset(widget.note.posX, widget.note.posY);
          });
        },
        onPanUpdate: (details) {
          if (_dragStart != null && _startPos != null) {
            final delta = details.globalPosition - _dragStart!;
            setState(() {
              widget.note.posX = (_startPos!.dx + delta.dx);
              widget.note.posY = (_startPos!.dy + delta.dy);
            });
          }
        },
        onPanEnd: (details) {
          setState(() {
            _dragging = false;
            _dragStart = null;
            _startPos = null;
          });
          widget.onDragEnd(Offset(widget.note.posX, widget.note.posY));
        },
        child: Material(
          elevation: widget.isActive ? 16 : 4,
          color: Colors.transparent,
          child: IntrinsicWidth(
            child: IntrinsicHeight(
              child: _GlassNoteCard(
                note: widget.note,
                onDelete: widget.onDelete,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
