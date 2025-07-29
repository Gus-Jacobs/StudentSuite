import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:student_suite/widgets/placeholder_highlighting_controller.dart';
import 'package:student_suite/widgets/editor_field.dart';
import 'dart:ui'; // For ImageFilter

class CoverLetterEditorScreen extends StatefulWidget {
  final Map<String, dynamic> initialContent;
  final String userName;
  final String templateName;

  const CoverLetterEditorScreen({
    super.key,
    required this.initialContent,
    required this.userName,
    required this.templateName,
  });

  @override
  State<CoverLetterEditorScreen> createState() =>
      _CoverLetterEditorScreenState();
}

class _CoverLetterEditorScreenState extends State<CoverLetterEditorScreen> {
  late PlaceholderHighlightingController _userNameController;
  late PlaceholderHighlightingController _salutationController;
  late List<PlaceholderHighlightingController> _bodyControllers;
  late PlaceholderHighlightingController _openingController;
  late PlaceholderHighlightingController _closingParagraphController;
  late PlaceholderHighlightingController _closingController;

  bool _isSaving = false;
  final RegExp _placeholderRegex = RegExp(r'\[.*?\]');

  @override
  void initState() {
    super.initState();

    // Define the style for placeholders once
    final placeholderStyle = TextStyle(
      backgroundColor: Colors.amber.withOpacity(0.3),
      color: Colors.amber.shade900,
      fontWeight: FontWeight.bold,
    );

    _userNameController = PlaceholderHighlightingController(
      text: widget.userName,
      placeholderRegex: _placeholderRegex,
      placeholderStyle: placeholderStyle,
    );

    _salutationController = PlaceholderHighlightingController(
      text: widget.initialContent['salutation'] ?? '',
      placeholderRegex: _placeholderRegex,
      placeholderStyle: placeholderStyle,
    );
    _openingController = PlaceholderHighlightingController(
      text: widget.initialContent['opening_paragraph'] ?? '',
      placeholderRegex: _placeholderRegex,
      placeholderStyle: placeholderStyle,
    );

    final bodyParagraphs =
        (widget.initialContent['body_paragraphs'] as List<dynamic>?)
                ?.map((p) => p.toString())
                .toList() ??
            [];
    _bodyControllers = bodyParagraphs
        .map((p) => PlaceholderHighlightingController(
              text: p,
              placeholderRegex: _placeholderRegex,
              placeholderStyle: placeholderStyle,
            ))
        .toList();

    _closingParagraphController = PlaceholderHighlightingController(
      text: widget.initialContent['closing_paragraph'] ?? '',
      placeholderRegex: _placeholderRegex,
      placeholderStyle: placeholderStyle,
    );
    _closingController = PlaceholderHighlightingController(
      text: widget.initialContent['closing'] ?? '',
      placeholderRegex: _placeholderRegex,
      placeholderStyle: placeholderStyle,
    );
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _salutationController.dispose();
    _openingController.dispose();
    _closingParagraphController.dispose();
    _closingController.dispose();
    for (var controller in _bodyControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // This function sanitizes text for PDF rendering, replacing problematic characters.
  String _sanitizeTextForPdf(String input) {
    // Replace common smart quotes and dashes with their ASCII equivalents
    String sanitized = input
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('—', '--') // Em dash
        .replaceAll('–', '-') // En dash
        .replaceAll('…', '...'); // Ellipsis

    // Replace specific symbols that might cause issues with readable alternatives
    sanitized = sanitized
        .replaceAll('™', '(TM)') // Trademark
        .replaceAll('©', '(C)') // Copyright
        .replaceAll('®', '(R)') // Registered trademark
        .replaceAll('№', 'No.') // Numero sign
        .replaceAll('✓',
            ' (check) ') // Explicitly replace checkmark if it appears in raw text
        .replaceAll('✗',
            ' (X) '); // Explicitly replace ballot X if it appears in raw text

    // Address the specific "C#" issue.
    // Replace with "C Sharp" to ensure rendering, unless your font fully supports '#'.
    sanitized = sanitized.replaceAll('C#', 'C Sharp');

    // Remove any non-printable ASCII characters or control characters
    // (e.g., zero-width spaces, non-breaking spaces that aren't handled, etc.)
    // This regex keeps printable ASCII characters (\x20-\x7E), common line breaks (\n\r\t),
    // and some standard Unicode whitespace characters.
    sanitized = sanitized.replaceAll(
        RegExp(
            r'[^\x20-\x7E\n\r\t\x85\xA0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]'),
        '');

    // Remove multiple spaces, tabs, and newlines that might cause odd formatting,
    // replacing them with single spaces.
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    // Trim whitespace from the beginning and end of the entire string
    return sanitized.trim();
  }

  Future<void> _generateAndSavePdf() async {
    setState(() => _isSaving = true);

    final pdf = pw.Document();

    // Load all the specific Roboto font assets for comprehensive rendering
    final robotoThin = await rootBundle.load("assets/fonts/Roboto-Thin.ttf");
    final robotoThinItalic =
        await rootBundle.load("assets/fonts/Roboto-ThinItalic.ttf");
    final robotoLight = await rootBundle.load("assets/fonts/Roboto-Light.ttf");
    final robotoLightItalic =
        await rootBundle.load("assets/fonts/Roboto-LightItalic.ttf");
    final robotoRegular =
        await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final robotoItalic =
        await rootBundle.load("assets/fonts/Roboto-Italic.ttf");
    final robotoMedium =
        await rootBundle.load("assets/fonts/Roboto-Medium.ttf");
    final robotoMediumItalic =
        await rootBundle.load("assets/fonts/Roboto-MediumItalic.ttf");
    final robotoBold = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final robotoBoldItalic =
        await rootBundle.load("assets/fonts/Roboto-BoldItalic.ttf");
    final robotoBlack = await rootBundle.load("assets/fonts/Roboto-Black.ttf");
    final robotoBlackItalic =
        await rootBundle.load("assets/fonts/Roboto-BlackItalic.ttf");

    // Define the common theme using the loaded Roboto font variants.
    // The pdf package will intelligently select the best font based on the TextStyle's fontWeight and fontStyle.
    final commonTheme = pw.ThemeData.withFont(
      base: pw.Font.ttf(robotoRegular),
      bold: pw.Font.ttf(robotoBold),
      italic: pw.Font.ttf(robotoItalic),
      boldItalic: pw.Font.ttf(robotoBoldItalic),
      // Optionally provide other weights if you explicitly use them in pw.TextStyle
      // light: pw.Font.ttf(robotoLight),
      // medium: pw.Font.ttf(robotoMedium),
      // black: pw.Font.ttf(robotoBlack),
    );

    // Apply this common Roboto theme to all templates for consistent and reliable output
    final classicTheme = commonTheme;
    final modernTheme = commonTheme;
    final creativeTheme = commonTheme;

    pw.Widget content;
    switch (widget.templateName) {
      case 'Modern':
        content = _buildModernLetter(modernTheme);
        break;
      case 'Creative':
        content = _buildCreativeLetter(creativeTheme);
        break;
      case 'Classic':
      default:
        content = _buildClassicLetter(classicTheme);
        break;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return content;
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  pw.Widget _buildClassicLetter(pw.ThemeData theme) {
    return pw.Theme(
      data: theme,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_sanitizeTextForPdf(_userNameController.text),
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 24),
          pw.Text(DateFormat.yMMMMd().format(DateTime.now())),
          pw.SizedBox(height: 24),
          pw.Paragraph(text: _sanitizeTextForPdf(_salutationController.text)),
          pw.SizedBox(height: 12),
          pw.Paragraph(
              text: _sanitizeTextForPdf(_openingController.text),
              style: const pw.TextStyle(lineSpacing: 5)),
          pw.SizedBox(height: 12),
          ..._bodyControllers.map((c) => pw.Paragraph(
              text: _sanitizeTextForPdf(c.text),
              style: const pw.TextStyle(lineSpacing: 5))),
          pw.SizedBox(height: 12),
          pw.Paragraph(
              text: _sanitizeTextForPdf(_closingParagraphController.text),
              style: const pw.TextStyle(lineSpacing: 5)),
          pw.SizedBox(height: 24),
          pw.Paragraph(text: _sanitizeTextForPdf(_closingController.text)),
          pw.SizedBox(height: 8),
          pw.Paragraph(text: _sanitizeTextForPdf(_userNameController.text)),
        ],
      ),
    );
  }

  pw.Widget _buildModernLetter(pw.ThemeData theme) {
    return pw.Theme(
      data: theme,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(
              border:
                  pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(_sanitizeTextForPdf(_userNameController.text),
                    style: pw.TextStyle(
                        fontSize: 28, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat.yMMMMd().format(DateTime.now()),
                    style: const pw.TextStyle(color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(height: 32),
          pw.Paragraph(
              text: _sanitizeTextForPdf(_salutationController.text),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Paragraph(
              text: _sanitizeTextForPdf(_openingController.text),
              style: const pw.TextStyle(lineSpacing: 4)),
          pw.SizedBox(height: 16),
          ..._bodyControllers.map((c) => pw.Paragraph(
              text: _sanitizeTextForPdf(c.text),
              style: const pw.TextStyle(lineSpacing: 4))),
          pw.SizedBox(height: 16),
          pw.Paragraph(
              text: _sanitizeTextForPdf(_closingParagraphController.text),
              style: const pw.TextStyle(lineSpacing: 4)),
          pw.SizedBox(height: 32),
          pw.Paragraph(text: _sanitizeTextForPdf(_closingController.text)),
          pw.SizedBox(height: 8),
          pw.Paragraph(text: _sanitizeTextForPdf(_userNameController.text)),
        ],
      ),
    );
  }

  pw.Widget _buildCreativeLetter(pw.ThemeData theme) {
    const accentColor = PdfColor.fromInt(0xFF6366f1); // Indigo
    return pw.Theme(
      data: theme,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text(
              _sanitizeTextForPdf(_userNameController.text),
              style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                  color: accentColor),
            ),
          ),
          pw.Center(
            child: pw.Text(
              DateFormat.yMMMMd().format(DateTime.now()),
              style: const pw.TextStyle(color: PdfColors.grey600),
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Paragraph(
              text: _sanitizeTextForPdf(_salutationController.text),
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: accentColor)),
          pw.SizedBox(height: 16),
          pw.Paragraph(
              text: _sanitizeTextForPdf(_openingController.text),
              style: const pw.TextStyle(lineSpacing: 4)),
          pw.SizedBox(height: 16),
          ..._bodyControllers.map((c) => pw.Paragraph(
              text: _sanitizeTextForPdf(c.text),
              style: const pw.TextStyle(lineSpacing: 4))),
          pw.SizedBox(height: 16),
          pw.Paragraph(
              text: _sanitizeTextForPdf(_closingParagraphController.text),
              style: const pw.TextStyle(lineSpacing: 4)),
          pw.SizedBox(height: 32),
          pw.Paragraph(text: _sanitizeTextForPdf(_closingController.text)),
          pw.SizedBox(height: 8),
          pw.Paragraph(
              text: _sanitizeTextForPdf(_userNameController.text),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
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
          colorFilter:
              ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
        ),
      );
    } else {
      backgroundDecoration = BoxDecoration(gradient: currentTheme.gradient);
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme.apply(
      bodyColor: Colors.black87, // Text color for inside the "paper"
      displayColor: Colors.black87,
    );

    return Container(
      decoration: backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Preview & Edit Letter'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _generateAndSavePdf,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Download PDF'),
              ),
            )
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Card(
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    EditorField(
                      controller: _userNameController,
                      style: textTheme.titleLarge,
                      fontWeight: FontWeight.bold,
                      hintText: 'Your Name',
                    ),
                    Text(
                      DateFormat.yMMMMd().format(DateTime.now()),
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),

                    // Salutation
                    EditorField(
                      controller: _salutationController,
                      style: textTheme.bodyLarge,
                      hintText: 'Dear Hiring Manager,',
                    ),
                    const SizedBox(height: 16),

                    // Opening
                    EditorField(
                      controller: _openingController,
                      style: textTheme.bodyLarge,
                      maxLines: null,
                      hintText: 'Opening paragraph...',
                    ),
                    const SizedBox(height: 16),

                    // Body
                    ..._bodyControllers.map((controller) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: EditorField(
                            controller: controller,
                            style: textTheme.bodyLarge,
                            maxLines: null,
                            hintText: 'Body paragraph...',
                          ),
                        )),

                    // Closing Paragraph
                    EditorField(
                      controller: _closingParagraphController,
                      style: textTheme.bodyLarge,
                      maxLines: null,
                      hintText: 'Closing paragraph...',
                    ),
                    const SizedBox(height: 24),

                    // Closing
                    EditorField(
                      controller: _closingController,
                      style: textTheme.bodyLarge,
                      hintText: 'Sincerely,',
                    ),
                    const SizedBox(height: 8),
                    EditorField(
                        controller: _userNameController,
                        style: textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
