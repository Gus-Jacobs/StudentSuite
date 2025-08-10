import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// A custom exception for the AI service to provide user-friendly error messages.
class AiServiceException implements Exception {
  final String message;
  AiServiceException(this.message);

  @override
  String toString() => message;
}

/// A standard class to represent a message in a chat history.
class ChatMessage {
  final String role; // 'user' or 'model'
  final String content;
  ChatMessage({required this.role, required this.content});
}

class AiService {
  // Singleton pattern
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  // The base URL for all your Cloud Functions
  static const _functionsBaseUrl =
      'https://us-central1-student-suite-9ae1d.cloudfunctions.net';

  // --- Core Generation Logic ---

  /// A helper method to get the authenticated user's ID token.
  Future<String?> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  /// Central generation function that calls a specified Cloud Function via HTTP.
  Future<dynamic> _callCloudFunction(
      String functionName, Map<String, dynamic> data) async {
    try {
      final url = '$_functionsBaseUrl/$functionName';
      final idToken = await _getIdToken();

      if (idToken == null) {
        throw AiServiceException('User not authenticated.');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['error']?['message'] ?? 'An unknown AI error occurred.';
        debugPrint('Cloud Function Error ($functionName): $errorMessage');
        throw AiServiceException(errorMessage);
      }

      final responseData = jsonDecode(response.body);
      return responseData['text'] ?? responseData;
    } on Exception catch (e, stacktrace) {
      debugPrint(
          "An unexpected error occurred calling the cloud function '$functionName': $e");
      debugPrint("StackTrace: $stacktrace");
      throw AiServiceException(
          "An unexpected error occurred. Please try again later.");
    }
  }

  // --- PUBLIC API METHODS ---

  Future<Map<String, dynamic>> generateResume({
    required Map<String, String> contactInfo,
    required List<Map<String, dynamic>> experiences,
    required List<Map<String, dynamic>> education,
    required List<Map<String, dynamic>> certificates,
    required List<String> skills,
    required String templateStyle,
  }) async {
    try {
      final prompt = _buildResumePrompt(contactInfo, experiences, education,
          certificates, skills, templateStyle);
      final data = {
        'prompt': prompt,
        'contactInfo': contactInfo,
        'experiences': experiences,
        'education': education,
        'certificates': certificates,
        'skills': skills,
        'templateStyle': templateStyle,
      };
      final generatedText =
          await _callCloudFunction('generateResume', data) as String;
      return _parseResumeOutput(generatedText, education, certificates);
    } catch (e) {
      debugPrint('Error in generateResume: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateCoverLetter({
    required String userName,
    required String companyName,
    required String hiringManager,
    required String jobDescription,
    required String templateStyle,
  }) async {
    try {
      final prompt = _buildCoverLetterPrompt(
          userName, companyName, hiringManager, jobDescription, templateStyle);
      final data = {
        'prompt': prompt,
        'userName': userName,
        'companyName': companyName,
        'hiringManager': hiringManager,
        'jobDescription': jobDescription,
        'templateStyle': templateStyle,
      };
      final generatedText =
          await _callCloudFunction('generateCoverLetter', data) as String;
      return _parseCoverLetterOutput(generatedText);
    } catch (e) {
      debugPrint('Error in generateCoverLetter: $e');
      rethrow;
    }
  }

  Future<String> generateStudyNote({required String topic}) async {
    try {
      final prompt = _buildStudyNotePrompt(topic);
      final data = {'prompt': prompt, 'topic': topic};
      return await _callCloudFunction('generateStudyNote', data) as String;
    } catch (e) {
      debugPrint('Error in generateStudyNote: $e');
      rethrow;
    }
  }

  Future<List<Map<String, String>>> generateFlashcards({
    required String topic,
    int count = 10,
    String? subjectContext,
  }) async {
    try {
      final prompt = _buildFlashcardPrompt(topic, count, subjectContext);
      final data = {
        'topic': topic,
        'count': count,
        'subjectContext': subjectContext,
        'prompt': prompt,
      };
      final generatedText =
          await _callCloudFunction('generateFlashcards', data) as String;
      return _parseFlashcardOutput(generatedText);
    } catch (e) {
      debugPrint('Error in generateFlashcards: $e');
      rethrow;
    }
  }

  Future<String> getTeacherResponse({
    required List<ChatMessage> history,
  }) async {
    try {
      const systemMessage =
          'You are an expert AI Teacher. Your goal is to explain complex topics clearly and concisely. Be encouraging and ask clarifying questions. If your explanation is long, end it with "[CONTINUE]" to signal that you have more to say.';

      var historyForApi = List<ChatMessage>.from(history);

      if (historyForApi.length == 1) {
        final firstUserMessage = historyForApi.first;
        historyForApi[0] = ChatMessage(
            role: 'user',
            content:
                '$systemMessage\n\nMy first question is: ${firstUserMessage.content}');
      }

      final prompt =
          historyForApi.map((m) => '${m.role}: ${m.content}').join('\n');
      final data = {
        'prompt': prompt,
        'history': historyForApi
            .map((m) => {'role': m.role, 'content': m.content})
            .toList()
      };
      return await _callCloudFunction('getTeacherResponse', data) as String;
    } catch (e) {
      debugPrint('Error in getTeacherResponse: $e');
      rethrow;
    }
  }

  Future<String> getInterviewerResponse({
    required List<ChatMessage> history,
    required String jobDescription,
    String? resumeText,
  }) async {
    try {
      const systemMessage =
          'You are a professional AI Interviewer. Your role is to conduct a realistic mock interview.\n'
          '- Ask one behavioral or technical question at a time, based on the provided job description and resume.\n'
          '- **Do NOT provide any feedback, commentary, or follow-up analysis on the user\'s answers.** Your only response should be the next question.\n'
          '- Keep the interview flowing naturally.\n'
          '- After asking 5-7 questions, conclude the interview by responding with only the text "[END_INTERVIEW]".';
      final context =
          'Job Description: $jobDescription\n\nResume: ${resumeText ?? 'Not provided.'}';

      var historyForApi = List<ChatMessage>.from(history);

      if (historyForApi.isEmpty) {
        historyForApi.add(ChatMessage(
            role: 'user',
            content:
                '$systemMessage\n\nHere is the context for our interview:\n$context\n\nPlease ask your first question.'));
      }

      final prompt =
          historyForApi.map((m) => '${m.role}: ${m.content}').join('\n');
      final data = {
        'prompt': prompt,
        'history': historyForApi
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
        'jobDescription': jobDescription,
        'resumeText': resumeText,
      };
      return await _callCloudFunction('getInterviewerResponse', data) as String;
    } catch (e) {
      debugPrint('Error in getInterviewerResponse: $e');
      rethrow;
    }
  }

  Future<String> getInterviewFeedback({
    required List<ChatMessage> history,
    required String jobDescription,
    String? resumeText,
  }) async {
    try {
      const systemMessage =
          'You are a helpful career coach. The user has just completed a mock interview. Your task is to provide constructive feedback on their answers based on the interview history and the job description. Format the feedback in Markdown with clear headings for "Overall Impression", "Strengths", and "Areas for Improvement".';
      final context =
          'Job Description: $jobDescription\n\nResume: ${resumeText ?? 'Not provided.'}';
      final transcript = history
          .map((m) =>
              '${m.role == 'user' ? 'Candidate' : 'Interviewer'}: ${m.content}')
          .join('\n');

      final prompt =
          '$systemMessage\n\nHere is the context for the interview:\n$context\n\nHere is the full interview transcript:\n$transcript\n\nPlease provide your feedback now.';
      final data = {
        'prompt': prompt,
        'history':
            history.map((m) => {'role': m.role, 'content': m.content}).toList(),
        'jobDescription': jobDescription,
        'resumeText': resumeText,
      };
      return await _callCloudFunction('getInterviewFeedback', data) as String;
    } catch (e) {
      debugPrint('Error in getInterviewFeedback: $e');
      rethrow;
    }
  }

  // --- PROMPT & PARSING HELPERS ---

  String _buildResumePrompt(
      Map<String, String> contactInfo,
      List<Map<String, dynamic>> experiences,
      List<Map<String, dynamic>> education,
      List<Map<String, dynamic>> certificates,
      List<String> skills,
      String templateStyle) {
    final experienceString = experiences.map((e) => """
Company: ${e['company']}
Title: ${e['title']}
Dates: ${e['dates']}
Responsibilities:
${e['responsibilities']}
""").join('\n---\n');

    final educationString = education
        .map((e) =>
            "- ${e['degree']} at ${e['school']}, graduated ${e['grad_date']}")
        .join('\n');

    final certificateString = certificates
        .map((c) => "- ${c['name']} from ${c['organization']}, ${c['date']}")
        .join('\n');

    return """
You are an expert resume writer and editor. Your task is to take the user's raw information and format it into a professional, compelling resume.
Your response must be polished and ready to use.

- Rewrite the user's responsibilities into concise, action-oriented bullet points. Use the STAR method (Situation, Task, Action, Result) where possible.
- Generate a professional summary based on the user's experience and skills.
- Categorize the provided skills into 'Hard Skills' and 'Soft Skills'. If the user-provided skill list is sparse, you may infer additional relevant skills based on their job experience.
- **Crucially, do not use placeholders like "[Your Major]" or "[Your Skill Here]". All generated text must be complete.**
- **Use the '$templateStyle' style for the overall tone and format.**
- **Ensure all text is spell-checked and uses correct capitalization (e.g., Title Case for headings, Sentence case for descriptions).**

Format the output EXACTLY as specified below, using the provided tags.

[SUMMARY]
A 2-4 sentence professional summary based on the user's experience and skills.
[/SUMMARY]

[EXPERIENCE]
Company: [Company Name]
Title: [Job Title]
Dates: [Dates of Employment]
- [Action-oriented bullet point 1]
- [Action-oriented bullet point 2]
[/EXPERIENCE]

(Repeat the [EXPERIENCE] block for each job)

[SKILLS]
Hard Skills: [Comma-separated list of hard skills]
Soft Skills: [Comma-separated list of soft skills]
[/SKILLS]

--- USER DATA ---
Contact Info: ${contactInfo.toString()}
Experience:
$experienceString
Education:
$educationString
Certificates:
$certificateString
Skills:
${skills.join(', ')}
""";
  }

  Map<String, dynamic> _parseResumeOutput(
      String text,
      List<Map<String, dynamic>> education,
      List<Map<String, dynamic>> certificates) {
    try {
      final summary =
          _extractSection(text, 'SUMMARY').replaceAll('[/SUMMARY]', '').trim();

      final skillsSection = _extractSection(text, 'SKILLS');
      final hardSkills = _extractLine(skillsSection, 'Hard Skills:')
          .split(', ')
          .where((s) => s.isNotEmpty)
          .toList();
      final softSkills = _extractLine(skillsSection, 'Soft Skills:')
          .split(', ')
          .where((s) => s.isNotEmpty)
          .toList();
      final List<Map<String, dynamic>> experiences;
      if (text.contains('[EXPERIENCE]')) {
        experiences = text
            .split('[EXPERIENCE]')
            .sublist(1) // Skip the part before the first tag
            .map((expBlock) {
              final cleanBlock =
                  expBlock.replaceAll('[/EXPERIENCE]', '').trim();
              return {
                'company': _extractLine(cleanBlock, 'Company:'),
                'title': _extractLine(cleanBlock, 'Title:'),
                'dates': _extractLine(cleanBlock, 'Dates:'),
                'bullet_points': cleanBlock
                    .split('\n')
                    .where((line) => line.trim().startsWith('-'))
                    .map((line) => line.trim().substring(1).trim())
                    .toList(),
              };
            })
            .where((e) => (e['company'] as String).isNotEmpty)
            .toList();
      } else {
        experiences = [];
      }

      return {
        'professional_summary': summary,
        'formatted_experience': experiences,
        'skills_section': {
          'hard_skills': hardSkills,
          'soft_skills': softSkills,
        },
        'formatted_education': education,
        'formatted_certificates': certificates,
      };
    } catch (e) {
      debugPrint("Error parsing resume output: $e");
      return {
        'professional_summary':
            "Error: Could not parse the AI's response. The raw response was:\n\n$text",
        'formatted_experience': [],
        'skills_section': {'hard_skills': [], 'soft_skills': []},
        'formatted_education': education,
        'formatted_certificates': certificates,
      };
    }
  }

  String _buildCoverLetterPrompt(String userName, String companyName,
      String hiringManager, String jobDescription, String templateStyle) {
    return """You are an AI assistant that writes professional, concise, and compelling cover letters.
Your response must be polished and ready to use.

- Generate a 3-paragraph cover letter based on the provided information.
- **Crucially, do not use placeholders like "[Your Accomplishment]". All generated text must be complete.**
- **Use the '$templateStyle' style for the overall tone and format.**
- **Ensure all text is spell-checked and uses correct grammar and punctuation.**

Format the output EXACTLY as specified below.

User Info:
My Name: $userName
Company: $companyName
Hiring Manager: ${hiringManager.isNotEmpty ? hiringManager : 'Hiring Team'}
Job Description:
$jobDescription

Template to use:
[SALUTATION]
Dear ${hiringManager.isNotEmpty ? hiringManager : 'Hiring Team'},
[/SALUTATION]

[OPENING]
I am writing to express my keen interest in the position...
[/OPENING]

[BODY]
A paragraph highlighting skills relevant to the job description...
[/BODY]

[CLOSING_P]
A paragraph summarizing interest and call to action...
[/CLOSING_P]

[CLOSING]
Sincerely,
[/CLOSING]
""";
  }

  Map<String, dynamic> _parseCoverLetterOutput(String text) {
    try {
      return {
        'salutation': _extractSection(text, 'SALUTATION'),
        'opening_paragraph': _extractSection(text, 'OPENING'),
        'body_paragraphs': [_extractSection(text, 'BODY')],
        'closing_paragraph': _extractSection(text, 'CLOSING_P'),
        'closing': _extractSection(text, 'CLOSING'),
      };
    } catch (e) {
      debugPrint("Error parsing cover letter output: $e");
      return {
        'salutation': 'Dear Hiring Team,',
        'opening_paragraph': 'Error: Could not parse AI response.',
        'body_paragraphs': [],
        'closing_paragraph': 'Please try generating again.',
        'closing': 'Sincerely,',
      };
    }
  }

  String _buildStudyNotePrompt(String topic) {
    return """You are an AI assistant that creates very short and simple study notes. For the given topic, provide a concise definition and a simple way to remember it (like a mnemonic or an analogy).

Format the output in Markdown like this:

**Definition:**
[Your one-sentence definition here]

**How to Remember:**
[Your mnemonic or analogy here]

Topic: "$topic"
""";
  }

  String _buildFlashcardPrompt(
      String topic, int count, String? subjectContext) {
    String contextInstruction = '';
    if (subjectContext != null && subjectContext.isNotEmpty) {
      contextInstruction =
          '\n\nUse the following course material as context when creating the cards:\n$subjectContext';
    }

    return """You are an AI assistant that creates flashcards for studying.
Generate exactly $count flashcards for the topic: "$topic".$contextInstruction
Format the output strictly as follows, with each card separated by '---'. Do not add any extra text or numbering outside the specified tags.

[Q]
Question 1
[/Q]
[A]
Answer 1
[/A]
---
[Q]
Question 2
[/Q]
[A]
Answer 2
[/A]
""";
  }

  List<Map<String, String>> _parseFlashcardOutput(String text) {
    try {
      final cards = <Map<String, String>>[];
      final cardBlocks = text.split('---');
      for (final block in cardBlocks) {
        if (block.contains('[Q]') && block.contains('[A]')) {
          final question = _extractSection(block, 'Q');
          final answer = _extractSection(block, 'A');
          if (question.isNotEmpty && answer.isNotEmpty) {
            cards.add({'question': question, 'answer': answer});
          }
        }
      }
      return cards;
    } catch (e) {
      debugPrint("Error parsing flashcard output: $e");
      return [
        {'question': 'Error', 'answer': 'Could not parse AI response.'}
      ];
    }
  }

  // --- PARSING HELPER METHODS ---

  String _extractSection(String text, String tag) {
    try {
      final startTag = '[$tag]';
      final endTag = '[/$tag]';
      final startIndex = text.indexOf(startTag);
      if (startIndex == -1) return '';
      final endIndex = text.indexOf(endTag, startIndex);
      if (endIndex == -1) return '';
      return text.substring(startIndex + startTag.length, endIndex).trim();
    } catch (e) {
      return '';
    }
  }

  String _extractLine(String text, String key) {
    try {
      final lines = text.split('\n');
      for (final line in lines) {
        if (line.trim().startsWith(key)) {
          return line.trim().substring(key.length).trim();
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}
