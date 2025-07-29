import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/mixins/tutorial_support_mixin.dart';
import 'package:student_suite/models/tutorial_step.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import 'dart:ui';
import 'package:student_suite/screens/cover_letter_editor_screen.dart';
import 'package:student_suite/services/ai_service.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/upgrade_dialog.dart';
import '../widgets/error_dialog.dart';
import '../widgets/glass_text_field.dart';
import '../providers/tutorial_provider.dart';
import '../widgets/tutorial_dialog.dart';
import '../widgets/template_preview_card.dart';

class CoverLetterScreen extends StatefulWidget {
  const CoverLetterScreen({super.key});
  @override
  State<CoverLetterScreen> createState() => _CoverLetterScreenState();
}

class _CoverLetterScreenState extends State<CoverLetterScreen>
    with TutorialSupport<CoverLetterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _managerController = TextEditingController();
  final _jobDescController = TextEditingController();
  final AiService _aiService = AiService();

  bool _isLoading = false;
  String _selectedTemplate = 'Classic';

  @override
  String get tutorialKey => 'cover_letter';

  @override
  List<TutorialStep> get tutorialSteps => const [
        TutorialStep(
            icon: Icons.business_center_outlined,
            title: 'Provide Job Details',
            description:
                'Enter your name, the company, and paste the job description. The AI uses this to tailor your letter.'),
        TutorialStep(
            icon: Icons.auto_fix_high,
            title: 'Generate with AI',
            description:
                'Our AI will write a professional, three-paragraph cover letter based on the info you provided.'),
      ];

  @override
  void initState() {
    super.initState();
    // Pre-fill the user's name from their profile for convenience.
    // It's safe to use context.read in initState.
    final auth = context.read<AuthProvider>();
    _nameController.text = auth.displayName;
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

    return Container(
      decoration: backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Cover Letter Generator'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help',
              onPressed: showTutorialDialog,
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassTextField(
                controller: _nameController,
                label: 'Your Name',
                icon: Icons.person_outline,
                isRequired: true,
              ),
              GlassTextField(
                controller: _companyController,
                label: 'Company Name',
                icon: Icons.business_outlined,
                isRequired: true,
              ),
              GlassTextField(
                controller: _managerController,
                label: 'Hiring Manager (Optional)',
                icon: Icons.person_search_outlined,
                isRequired: false,
              ),
              GlassTextField(
                controller: _jobDescController,
                label: 'Paste Job Description',
                maxLines: 6,
                icon: Icons.description_outlined,
                isRequired: true,
              ),
              const SizedBox(height: 24),
              Text('Select a Template', // Now uses the default theme text color
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildTemplateSelector(),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_fix_high),
                label: Text(_isLoading ? 'Generating...' : 'Generate with AI'),
                onPressed: _isLoading ? null : _generateLetter,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateLetter() async {
    final subscription =
        Provider.of<SubscriptionProvider>(context, listen: false);
    if (!subscription.isSubscribed) {
      showUpgradeDialog(context);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final content = await _aiService.generateCoverLetter(
        userName: _nameController.text.trim(),
        companyName: _companyController.text.trim(),
        hiringManager: _managerController.text.trim(),
        jobDescription: _jobDescController.text.trim(),
        templateStyle: _selectedTemplate,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CoverLetterEditorScreen(
            initialContent: content,
            userName: _nameController.text.trim(),
            templateName: _selectedTemplate,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, "Failed to generate cover letter: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTemplateSelector() {
    const templates = ['Classic', 'Modern', 'Creative'];
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: templates.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final templateName = templates[index];
          final isSelected = _selectedTemplate == templateName;
          return TemplatePreviewCard(
            templateName: templateName,
            icon: Icons.article_outlined,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedTemplate = templateName),
          );
        },
      ),
    );
  }
}
