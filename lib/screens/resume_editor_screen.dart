import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:student_suite/widgets/placeholder_highlighting_controller.dart';
import 'package:student_suite/widgets/editor_field.dart';
import 'dart:ui'; // For ImageFilter
import 'package:google_fonts/google_fonts.dart'; // Import GoogleFonts for UI consistency

class ResumeEditorScreen extends StatefulWidget {
  final Map<String, dynamic> initialContent;
  final Map<String, String> contactInfo;
  final String templateName;

  const ResumeEditorScreen({
    super.key,
    required this.initialContent,
    required this.contactInfo,
    required this.templateName,
  });

  @override
  State<ResumeEditorScreen> createState() => _ResumeEditorScreenState();
}

class _ResumeEditorScreenState extends State<ResumeEditorScreen> {
  late PlaceholderHighlightingController _summaryController;
  late List<Map<String, dynamic>> _experiences;
  late List<Map<String, dynamic>> _education;
  late List<Map<String, dynamic>> _certificates;
  late Map<String, dynamic> _skills;

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

    _summaryController = PlaceholderHighlightingController(
      text: widget.initialContent['professional_summary'] ?? '',
      placeholderRegex: _placeholderRegex,
      placeholderStyle: placeholderStyle,
    );

    // Deep copy and create controllers for experiences
    _experiences =
        (widget.initialContent['formatted_experience'] as List<dynamic>? ?? [])
            .map((exp) {
      final bulletPoints = (exp['bullet_points'] as List<dynamic>? ?? [])
          .map((bp) => PlaceholderHighlightingController(
              text: bp.toString(),
              placeholderRegex: _placeholderRegex,
              placeholderStyle: placeholderStyle))
          .toList();
      return {
        'company': TextEditingController(text: exp['company'] ?? ''),
        'title': TextEditingController(text: exp['title'] ?? ''),
        'dates': TextEditingController(text: exp['dates'] ?? ''),
        'bullet_points': bulletPoints,
      };
    }).toList();

    // Deep copy and create controllers for education
    _education =
        (widget.initialContent['formatted_education'] as List<dynamic>? ?? [])
            .map((edu) {
      return {
        'school': PlaceholderHighlightingController(
            text: edu['school'] ?? '',
            placeholderRegex: _placeholderRegex,
            placeholderStyle: placeholderStyle),
        'degree': PlaceholderHighlightingController(
            text: edu['degree'] ?? '',
            placeholderRegex: _placeholderRegex,
            placeholderStyle: placeholderStyle),
        'grad_date': PlaceholderHighlightingController(
            text: edu['grad_date'] ?? '',
            placeholderRegex: _placeholderRegex,
            placeholderStyle: placeholderStyle),
      };
    }).toList();

    // Deep copy and create controllers for certificates
    _certificates =
        (widget.initialContent['formatted_certificates'] as List<dynamic>? ??
                [])
            .map((cert) {
      return {
        'name': PlaceholderHighlightingController(
            text: cert['name'] ?? '',
            placeholderRegex: _placeholderRegex,
            placeholderStyle: placeholderStyle),
        'organization': PlaceholderHighlightingController(
            text: cert['organization'] ?? '',
            placeholderRegex: _placeholderRegex,
            placeholderStyle: placeholderStyle),
        'date': PlaceholderHighlightingController(
            text: cert['date'] ?? '',
            placeholderRegex: _placeholderRegex,
            placeholderStyle: placeholderStyle),
      };
    }).toList();

    // Just copy skills, they are not editable in this screen for simplicity
    _skills = widget.initialContent['skills_section'] ??
        {'hard_skills': [], 'soft_skills': []};
  }

  @override
  void dispose() {
    _summaryController.dispose();
    for (final exp in _experiences) {
      (exp['company'] as TextEditingController).dispose();
      (exp['title'] as TextEditingController).dispose();
      (exp['dates'] as TextEditingController).dispose();
      for (final bp
          in exp['bullet_points'] as List<PlaceholderHighlightingController>) {
        bp.dispose();
      }
    }
    for (final edu in _education) {
      (edu['school'] as PlaceholderHighlightingController).dispose();
      (edu['degree'] as PlaceholderHighlightingController).dispose();
      (edu['grad_date'] as PlaceholderHighlightingController).dispose();
    }
    for (final cert in _certificates) {
      (cert['name'] as PlaceholderHighlightingController).dispose();
      (cert['organization'] as PlaceholderHighlightingController).dispose();
      (cert['date'] as PlaceholderHighlightingController).dispose();
    }
    super.dispose();
  }

  // UPDATED SANITIZATION FUNCTION
  String _sanitizeTextForPdf(String input) {
    // First, handle specific problematic Unicode characters like smart quotes/dashes
    String sanitized = input
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('—', '--')
        .replaceAll('…', '...');

    // Then, remove any remaining non-printable or unsupported characters.
    // This regex keeps printable ASCII characters (0x20-0x7E), plus common whitespace characters (\n, \r, \t).
    // This provides "heavy sanitization" to prevent truly "weird" characters.
    // If you need to support specific Unicode characters outside this range (e.g., accented letters, specific symbols),
    // you will need to adjust this regular expression.
    sanitized = sanitized.replaceAllMapped(
        RegExp(r'[^\x20-\x7E\n\r\t]'), (match) => '');

    return sanitized.trim();
  }

  Future<void> _generateAndSavePdf() async {
    setState(() => _isSaving = true);

    final pdf = pw.Document();

    // Load ALL Roboto fonts from assets as per user's pubspec.yaml snippet
    final robotoThin = await rootBundle.load("assets/fonts/Roboto-Thin.ttf");
    final robotoLight = await rootBundle.load("assets/fonts/Roboto-Light.ttf");
    final robotoRegular =
        await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final robotoMedium =
        await rootBundle.load("assets/fonts/Roboto-Medium.ttf");
    final robotoBold = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final robotoBlack = await rootBundle.load("assets/fonts/Roboto-Black.ttf");

    final robotoThinItalic =
        await rootBundle.load("assets/fonts/Roboto-ThinItalic.ttf");
    final robotoLightItalic =
        await rootBundle.load("assets/fonts/Roboto-LightItalic.ttf");
    final robotoItalic =
        await rootBundle.load("assets/fonts/Roboto-Italic.ttf");
    final robotoMediumItalic =
        await rootBundle.load("assets/fonts/Roboto-MediumItalic.ttf");
    final robotoBoldItalic =
        await rootBundle.load("assets/fonts/Roboto-BoldItalic.ttf");
    final robotoBlackItalic =
        await rootBundle.load("assets/fonts/Roboto-BlackItalic.ttf");

    // Create a single Roboto theme to be used across all templates
    final robotoTheme = pw.ThemeData.withFont(
      base: pw.Font.ttf(robotoRegular),
      bold: pw.Font.ttf(robotoBold),
      italic: pw.Font.ttf(robotoItalic),
      boldItalic: pw.Font.ttf(robotoBoldItalic),
    );

    pw.Widget content;
    switch (widget.templateName) {
      case 'Modern':
        content = _buildModernResume(robotoTheme); // Use robotoTheme
        break;
      case 'Creative':
        content = _buildCreativeResume(robotoTheme); // Use robotoTheme
        break;
      case 'Classic':
      default:
        content = _buildClassicResume(robotoTheme); // Use robotoTheme
        break;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0), // We control margins per template
        build: (pw.Context context) => content,
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  pw.Widget _buildClassicResume(pw.ThemeData theme) {
    pw.Widget section(String title, pw.Widget child) {
      return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title.toUpperCase(),
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1)),
            pw.Divider(height: 8, thickness: 1.5),
            pw.SizedBox(height: 8),
            child,
          ]);
    }

    // Sanitize contact info items before joining
    final contactItems = [
      widget.contactInfo['email'],
      widget.contactInfo['phone'],
      widget.contactInfo['linkedin'],
    ]
        .where((s) => s != null && s.isNotEmpty)
        .map((s) => _sanitizeTextForPdf(s!))
        .join(' | ');

    return pw.Theme(
      data: theme,
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(40),
        child: pw
            .Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Center(
              child: pw.Text(
                  _sanitizeTextForPdf(
                      widget.contactInfo['name'] ?? 'Your Name'),
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.Center(
              child: pw.Text(contactItems, // Already sanitized
                  style: const pw.TextStyle(fontSize: 10))),
          pw.SizedBox(height: 20),
          section('Professional Summary',
              pw.Paragraph(text: _sanitizeTextForPdf(_summaryController.text))),
          pw.SizedBox(height: 16),
          section(
              'Skills',
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_sanitizeTextForPdf(
                        'Hard Skills: ${(_skills['hard_skills'] as List<dynamic>? ?? []).map((s) => _sanitizeTextForPdf(s.toString())).join(', ')}')),
                    pw.SizedBox(height: 4),
                    pw.Text(_sanitizeTextForPdf(
                        'Soft Skills: ${(_skills['soft_skills'] as List<dynamic>? ?? []).map((s) => _sanitizeTextForPdf(s.toString())).join(', ')}')),
                  ])),
          pw.SizedBox(height: 16),
          section(
              'Experience',
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: _experiences.map((exp) {
                    return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 12),
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(children: [
                                pw.Expanded(
                                    child: pw.Text(
                                        _sanitizeTextForPdf((exp['company']
                                                as TextEditingController)
                                            .text),
                                        style: pw.TextStyle(
                                            fontWeight: pw.FontWeight.bold))),
                                pw.Text(
                                    _sanitizeTextForPdf(
                                        (exp['dates'] as TextEditingController)
                                            .text),
                                    style: pw.TextStyle(
                                        fontStyle: pw.FontStyle.italic)),
                              ]),
                              pw.Text(
                                  _sanitizeTextForPdf(
                                      (exp['title'] as TextEditingController)
                                          .text),
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontStyle: pw.FontStyle.italic)),
                              pw.SizedBox(height: 4),
                              pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: (exp['bullet_points'] as List<
                                          PlaceholderHighlightingController>)
                                      .map((bp) => pw.Bullet(
                                          text: _sanitizeTextForPdf(bp.text),
                                          style:
                                              const pw.TextStyle(fontSize: 10)))
                                      .toList()),
                            ]));
                  }).toList())),
          if (_education.isNotEmpty) pw.SizedBox(height: 16),
          if (_education.isNotEmpty)
            section(
                'Education',
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: _education.map((edu) {
                      return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 8),
                          child: pw.Text(_sanitizeTextForPdf(
                              '${_sanitizeTextForPdf((edu['degree'] as PlaceholderHighlightingController).text)}, ${_sanitizeTextForPdf((edu['school'] as PlaceholderHighlightingController).text)} - ${_sanitizeTextForPdf((edu['grad_date'] as PlaceholderHighlightingController).text)}')));
                    }).toList())),
          if (_certificates.isNotEmpty) pw.SizedBox(height: 16),
          if (_certificates.isNotEmpty)
            section(
                'Certificates',
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: _certificates.map((cert) {
                      return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Text(_sanitizeTextForPdf(
                              '• ${_sanitizeTextForPdf((cert['name'] as PlaceholderHighlightingController).text)} - ${_sanitizeTextForPdf((cert['organization'] as PlaceholderHighlightingController).text)}, ${_sanitizeTextForPdf((cert['date'] as PlaceholderHighlightingController).text)}')));
                    }).toList())),
        ]),
      ),
    );
  }

  pw.Widget _buildModernResume(pw.ThemeData theme) {
    const accentColor = PdfColor.fromInt(0xFF6366f1); // Indigo

    pw.Widget sidebarSection(String title, List<pw.Widget> children) {
      return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title.toUpperCase(),
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: PdfColors.grey600,
                    letterSpacing: 1)),
            pw.SizedBox(height: 8),
            ...children,
          ]);
    }

    return pw.Theme(
      data: theme,
      child: pw.Row(children: [
        // Sidebar
        pw.Container(
          width: 180,
          padding: const pw.EdgeInsets.all(30),
          color: const PdfColor.fromInt(0xFFF0F0F0), // Light grey
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                sidebarSection('Contact', [
                  pw.Text(
                      _sanitizeTextForPdf(widget.contactInfo['email'] ?? '')),
                  pw.Text(
                      _sanitizeTextForPdf(widget.contactInfo['phone'] ?? '')),
                  if ((widget.contactInfo['linkedin'] ?? '').isNotEmpty)
                    pw.UrlLink(
                        destination: widget.contactInfo['linkedin']!,
                        child: pw.Text(_sanitizeTextForPdf('LinkedIn'),
                            style: const pw.TextStyle(
                                color: PdfColors.blue,
                                decoration: pw.TextDecoration.underline))),
                ]),
                pw.SizedBox(height: 20),
                sidebarSection('Skills', [
                  pw.Text(_sanitizeTextForPdf('Hard Skills:'),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(_sanitizeTextForPdf(
                      (_skills['hard_skills'] as List<dynamic>? ?? [])
                          .map((s) => _sanitizeTextForPdf(s.toString()))
                          .join(', '))),
                  pw.SizedBox(height: 8),
                  pw.Text(_sanitizeTextForPdf('Soft Skills:'),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(_sanitizeTextForPdf(
                      (_skills['soft_skills'] as List<dynamic>? ?? [])
                          .map((s) => _sanitizeTextForPdf(s.toString()))
                          .join(', '))),
                ]),
                if (_education.isNotEmpty) pw.SizedBox(height: 20),
                if (_education.isNotEmpty)
                  sidebarSection(
                      'Education',
                      _education.map((e) {
                        return pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                  _sanitizeTextForPdf((e['school']
                                          as PlaceholderHighlightingController)
                                      .text),
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text(_sanitizeTextForPdf((e['degree']
                                      as PlaceholderHighlightingController)
                                  .text)),
                              pw.Text(
                                  _sanitizeTextForPdf((e['grad_date']
                                          as PlaceholderHighlightingController)
                                      .text),
                                  style: const pw.TextStyle(
                                      color: PdfColors.grey700)),
                              pw.SizedBox(height: 8),
                            ]);
                      }).toList()),
              ]),
        ),
        // Main Content
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                      _sanitizeTextForPdf(
                          widget.contactInfo['name'] ?? 'Your Name'),
                      style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF333333))),
                  pw.SizedBox(height: 4),
                  pw.Text('Professional Summary',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600)),
                  pw.Divider(color: PdfColors.grey400),
                  pw.Paragraph(
                      text: _sanitizeTextForPdf(_summaryController.text)),
                  pw.SizedBox(height: 24),
                  pw.Text('EXPERIENCE',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600,
                          letterSpacing: 1)),
                  pw.Divider(color: PdfColors.grey400),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: _experiences.map((exp) {
                        return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 12),
                            child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Row(
                                      mainAxisAlignment:
                                          pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text(
                                            _sanitizeTextForPdf((exp['company']
                                                    as TextEditingController)
                                                .text),
                                            style: pw.TextStyle(
                                                fontWeight:
                                                    pw.FontWeight.bold)),
                                        pw.Text(
                                            _sanitizeTextForPdf((exp['dates']
                                                    as TextEditingController)
                                                .text),
                                            style: const pw.TextStyle(
                                                color: PdfColors.grey700)),
                                      ]),
                                  pw.Text(
                                      _sanitizeTextForPdf((exp['title']
                                              as TextEditingController)
                                          .text),
                                      style: pw.TextStyle(
                                          fontStyle: pw.FontStyle.italic)),
                                  pw.SizedBox(height: 4),
                                  pw.Column(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      children: (exp['bullet_points'] as List<
                                              PlaceholderHighlightingController>)
                                          .map((bp) => pw.Bullet(
                                              text:
                                                  _sanitizeTextForPdf(bp.text),
                                              style: const pw.TextStyle(
                                                  fontSize: 10,
                                                  lineSpacing: 2)))
                                          .toList()),
                                ]));
                      }).toList()),
                ]),
          ),
        ),
      ]),
    );
  }

  pw.Widget _buildCreativeResume(pw.ThemeData theme) {
    const accentColor = PdfColor.fromInt(0xFF6366f1); // Indigo

    pw.Widget section(String title, List<pw.Widget> children) {
      return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title.toUpperCase(),
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                    color: accentColor,
                    letterSpacing: 1)),
            pw.Container(
                height: 2,
                width: 40,
                color: accentColor,
                margin: const pw.EdgeInsets.symmetric(vertical: 4)),
            pw.SizedBox(height: 8),
            ...children,
          ]);
    }

    return pw.Theme(
      data: theme,
      child: pw.Padding(
          padding: const pw.EdgeInsets.all(40),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    _sanitizeTextForPdf(
                        widget.contactInfo['name'] ?? 'Your Name'),
                    style: pw.TextStyle(
                        fontSize: 42,
                        fontWeight: pw.FontWeight.bold,
                        color: accentColor)),
                pw.Text(
                    _sanitizeTextForPdf(
                        '${widget.contactInfo['email']} | ${widget.contactInfo['phone']}'),
                    style: const pw.TextStyle(color: PdfColors.grey700)),
                pw.SizedBox(height: 24),
                section('Summary', [
                  pw.Paragraph(
                      text: _sanitizeTextForPdf(_summaryController.text))
                ]),
                section(
                    'Experience',
                    _experiences.map((exp) {
                      return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 12),
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Expanded(
                                          child: pw.Text(
                                              _sanitizeTextForPdf(
                                                  '${(exp['title'] as TextEditingController).text} | ${(exp['company'] as TextEditingController).text}'),
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold))),
                                      pw.Text(
                                          _sanitizeTextForPdf((exp['dates']
                                                  as TextEditingController)
                                              .text),
                                          style: const pw.TextStyle(
                                              color: PdfColors.grey700)),
                                    ]),
                                pw.SizedBox(height: 4),
                                pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: (exp['bullet_points'] as List<
                                            PlaceholderHighlightingController>)
                                        .map((bp) => pw.Bullet(
                                            text: _sanitizeTextForPdf(bp.text),
                                            style: const pw.TextStyle(
                                                fontSize: 10, lineSpacing: 2)))
                                        .toList()),
                              ]));
                    }).toList()),
                section('Skills', [
                  pw.Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ...(_skills['hard_skills'] as List<dynamic>? ?? []).map(
                          (s) => pw.Text(_sanitizeTextForPdf(
                              '• ${_sanitizeTextForPdf(s.toString())}'))),
                      ...(_skills['soft_skills'] as List<dynamic>? ?? []).map(
                          (s) => pw.Text(_sanitizeTextForPdf(
                              '• ${_sanitizeTextForPdf(s.toString())}'))),
                    ],
                  ),
                ]),
                if (_education.isNotEmpty)
                  section(
                      'Education',
                      _education.map((edu) {
                        return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 8),
                            child: pw.Text(_sanitizeTextForPdf(
                                '${_sanitizeTextForPdf((edu['degree'] as PlaceholderHighlightingController).text)}, ${_sanitizeTextForPdf((edu['school'] as PlaceholderHighlightingController).text)} - ${_sanitizeTextForPdf((edu['grad_date'] as PlaceholderHighlightingController).text)}')));
                      }).toList()),
                if (_certificates.isNotEmpty)
                  section(
                      'Certificates',
                      _certificates.map((cert) {
                        return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 4),
                            child: pw.Text(_sanitizeTextForPdf(
                                '• ${_sanitizeTextForPdf((cert['name'] as PlaceholderHighlightingController).text)} - ${_sanitizeTextForPdf((cert['organization'] as PlaceholderHighlightingController).text)}, ${_sanitizeTextForPdf((cert['date'] as PlaceholderHighlightingController).text)}')));
                      }).toList()),
              ])),
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
          title: const Text('Preview & Edit Resume'),
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
        // APPLY ROBOTO FONT TO UI HERE
        body: DefaultTextStyle.merge(
          style: GoogleFonts.roboto(
              // You can specify a base font size, weight, or color if needed
              // e.g., fontSize: 16.0, fontWeight: FontWeight.normal
              ),
          child: ListView(
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
                      // Summary
                      Text('Professional Summary',
                          style: textTheme.titleMedium),
                      const Divider(),
                      EditorField(
                        controller: _summaryController,
                        style: textTheme.bodyLarge,
                        maxLines: null,
                        hintText: 'Your professional summary...',
                      ),
                      const SizedBox(height: 24),

                      // Experience
                      Text('Experience', style: textTheme.titleMedium),
                      const Divider(),
                      ..._experiences.map((exp) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              EditorField(
                                controller:
                                    exp['company'] as TextEditingController,
                                style: textTheme.bodyLarge,
                                fontWeight: FontWeight.bold,
                                hintText: 'Company Name',
                              ),
                              EditorField(
                                controller:
                                    exp['title'] as TextEditingController,
                                style: textTheme.bodyLarge,
                                hintText: 'Job Title',
                              ),
                              EditorField(
                                controller:
                                    exp['dates'] as TextEditingController,
                                style: textTheme.bodyMedium,
                                hintText: 'Dates',
                              ),
                              const SizedBox(height: 8),
                              ...(exp['bullet_points'] as List<
                                      PlaceholderHighlightingController>)
                                  .map((bpController) => Padding(
                                        padding: const EdgeInsets.only(
                                            left: 16.0, bottom: 4.0),
                                        child: EditorField(
                                          controller: bpController,
                                          style: textTheme.bodyLarge,
                                          maxLines: null,
                                          hintText: '• Achievement or task...',
                                        ),
                                      ))
                                  .toList(),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 24),

                      // Education
                      Text('Education', style: textTheme.titleMedium),
                      const Divider(),
                      ..._education.map((edu) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              EditorField(
                                controller: edu['school']
                                    as PlaceholderHighlightingController,
                                style: textTheme.bodyLarge,
                                hintText: 'School/University',
                              ),
                              EditorField(
                                controller: edu['degree']
                                    as PlaceholderHighlightingController,
                                style: textTheme.bodyLarge,
                                hintText: 'Degree',
                              ),
                              EditorField(
                                controller: edu['grad_date']
                                    as PlaceholderHighlightingController,
                                style: textTheme.bodyMedium,
                                hintText: 'Graduation Date',
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 24),

                      // Certificates
                      if (_certificates.isNotEmpty) ...[
                        Text('Certificates', style: textTheme.titleMedium),
                        const Divider(),
                        ..._certificates.map((cert) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                EditorField(
                                  controller: cert['name']
                                      as PlaceholderHighlightingController,
                                  style: textTheme.bodyLarge,
                                  hintText: 'Certificate Name',
                                ),
                                EditorField(
                                  controller: cert['organization']
                                      as PlaceholderHighlightingController,
                                  style: textTheme.bodyLarge,
                                  hintText: 'Issuing Organization',
                                ),
                                EditorField(
                                  controller: cert['date']
                                      as PlaceholderHighlightingController,
                                  style: textTheme.bodyMedium,
                                  hintText: 'Date Issued',
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
