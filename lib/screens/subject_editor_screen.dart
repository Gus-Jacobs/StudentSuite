import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:student_suite/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/models/subject.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:student_suite/widgets/error_dialog.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_pdf;

class SubjectEditorScreen extends StatefulWidget {
  final String subjectId;
  const SubjectEditorScreen({super.key, required this.subjectId});

  @override
  State<SubjectEditorScreen> createState() => _SubjectEditorScreenState();
}

class _SubjectEditorScreenState extends State<SubjectEditorScreen> {
  late Subject _subject;
  bool _isLoading = true;
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubject();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _loadSubject() {
    final box = context.read<AuthProvider>().subjectsBox;
    final subject = box.get(widget.subjectId);
    if (subject != null) {
      setState(() {
        _subject = subject;
        _nameController.text = _subject.name;
        _contentController.text = _subject.content;
        _isLoading = false;
      });
    } else {
      // Should not happen if navigation is correct
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveSubject() async {
    if (_nameController.text.trim().isEmpty) {
      showErrorDialog(context, 'Subject name cannot be empty.');
      return;
    }
    setState(() {
      _subject.name = _nameController.text.trim();
      _subject.content = _contentController.text.trim();
      _subject.lastUpdated = DateTime.now();
    });
    await _subject.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject saved!')),
      );
    }
  }

  Future<void> _addFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (result != null) {
        final platformFile = result.files.single;
        setState(() => _isLoading = true);

        String text;
        Uint8List fileBytes;

        if (kIsWeb) {
          fileBytes = platformFile.bytes!;
        } else {
          fileBytes = await File(platformFile.path!).readAsBytes();
        }

        if (platformFile.extension?.toLowerCase() == 'pdf') {
          final syncfusion_pdf.PdfDocument document =
              syncfusion_pdf.PdfDocument(inputBytes: fileBytes);
          text = syncfusion_pdf.PdfTextExtractor(document).extractText();
          document.dispose();
        } else {
          // txt file
          text = String.fromCharCodes(fileBytes);
        }

        if (mounted) {
          setState(() {
            // If there's existing text, add a separator.
            if (_contentController.text.isNotEmpty) {
              _contentController.text += '\n\n';
            }
            _contentController.text += text;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Content added from file. Tap save to persist changes.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Failed to read file: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        // If there's existing text, add a separator.
        if (_contentController.text.isNotEmpty) {
          _contentController.text += '\n\n';
        }
        _contentController.text += clipboardData.text!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Pasted content. Tap save to persist changes.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
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
          title: _isLoading
              ? const Text('Loading...')
              : TextField(
                  controller: _nameController,
                  decoration: const InputDecoration.collapsed(
                    hintText: 'Subject Name',
                    hintStyle: TextStyle(color: Colors.white70),
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white),
                  onSubmitted: (_) => _saveSubject(),
                ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _isLoading ? null : _saveSubject,
                icon: const Icon(Icons.save_outlined, color: Colors.white),
                label:
                    const Text('Save', style: TextStyle(color: Colors.white)),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.white.withOpacity(0.5))),
                ),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _contentController,
                        maxLines: null, // Allows infinite lines
                        expands: true,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: 'Paste text or upload files...',
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        textAlignVertical: TextAlignVertical.top,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _addFromFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Add from File'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pasteFromClipboard,
                          icon: const Icon(Icons.content_paste),
                          label: const Text('Paste'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
      ),
    );
  }
}
