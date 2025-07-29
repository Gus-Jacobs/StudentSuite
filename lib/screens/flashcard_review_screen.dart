import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../models/flashcard_deck.dart';
import '../models/flashcard.dart';
import '../providers/theme_provider.dart' as app_theme;

enum ReviewMode { review, test }

class FlashcardReviewScreen extends StatefulWidget {
  final FlashcardDeck deck;

  const FlashcardReviewScreen({super.key, required this.deck});

  @override
  State<FlashcardReviewScreen> createState() => _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends State<FlashcardReviewScreen> {
  late List<Flashcard> _shuffledCards;
  late PageController _pageController;
  late ConfettiController _confettiController;
  int _currentIndex = 0;
  // New state for test mode
  ReviewMode _mode = ReviewMode.review;
  late List<String?> _userAnswers;
  late List<bool?> _isCorrect;
  final _answerController = TextEditingController();
  bool _showAnswerFeedback = false; // To show correct/incorrect status

  @override
  void initState() {
    super.initState();
    _shuffledCards = List.from(widget.deck.cards)..shuffle();
    _pageController = PageController();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
    // Initialize test mode state
    _resetTestState();
  }

  void _resetTestState() {
    // Ensure lists are correctly sized, even if the deck is empty.
    final cardCount = _shuffledCards.length;
    _userAnswers = List.filled(cardCount, null);
    _isCorrect = List.filled(cardCount, null);
    _answerController.clear();
    _showAnswerFeedback = false;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      // Reset input fields when moving to a new card in test mode
      if (_mode == ReviewMode.test) {
        _answerController.clear();
        _showAnswerFeedback = false;
      }
    });
    if (index == _shuffledCards.length) {
      _confettiController.play();
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _nextCard() {
    if (_currentIndex < _shuffledCards.length) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _checkAnswer() {
    if (_answerController.text.trim().isEmpty) return;

    final userAnswer = _answerController.text.trim().toLowerCase();
    final correctAnswer =
        _shuffledCards[_currentIndex].answer.trim().toLowerCase();

    setState(() {
      _userAnswers[_currentIndex] = _answerController.text.trim();
      _isCorrect[_currentIndex] = (userAnswer == correctAnswer);
      _showAnswerFeedback = true;
    });
  }

  Widget _buildCardSide(String text, String label) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(int index) {
    final card = _shuffledCards[index];
    final bool? isCorrect = _isCorrect[index];

    Color borderColor = Colors.transparent;
    if (_showAnswerFeedback) {
      borderColor = isCorrect == true ? Colors.green : Colors.red;
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 4),
      ),
      margin: const EdgeInsets.all(24.0),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Question',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 2,
              child: Center(
                child: SingleChildScrollView(
                  child: Text(
                    card.question,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
            ),
            const Divider(height: 24),
            if (_showAnswerFeedback)
              _buildAnswerFeedback(card.answer, isCorrect)
            else
              _buildAnswerInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerInput() {
    return Column(
      children: [
        TextField(
          controller: _answerController,
          decoration: const InputDecoration(
            labelText: 'Your Answer',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _checkAnswer(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _checkAnswer,
          child: const Text('Check Answer'),
        ),
      ],
    );
  }

  Widget _buildCompletionScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration_outlined,
                size: 100, color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              'Congratulations!',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  shadows: [
                    const Shadow(blurRadius: 4, color: Colors.black54)
                  ]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'You have reviewed all cards in this deck.',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text('Study Again'),
              onPressed: () {
                _pageController.jumpToPage(0);
                setState(() {
                  _shuffledCards.shuffle();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCompletionScreen() {
    final score = _isCorrect.where((c) => c == true).length;
    final total = _shuffledCards.length;
    final percentage = total > 0 ? (score / total * 100).round() : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Test Complete!',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  shadows: [
                    const Shadow(blurRadius: 4, color: Colors.black54)
                  ]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'Your Score: $score / $total ($percentage%)',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text('Try Again'),
              onPressed: () {
                _pageController.jumpToPage(0);
                setState(() {
                  _shuffledCards.shuffle();
                  _resetTestState();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<app_theme.ThemeProvider>(context);
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
          title: Text('Study: ${widget.deck.name}'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            if (_shuffledCards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: SegmentedButton<ReviewMode>(
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    selectedForegroundColor: currentTheme.navBarColor,
                    selectedBackgroundColor: Colors.white.withOpacity(0.9),
                  ),
                  segments: const [
                    ButtonSegment(
                        value: ReviewMode.review, label: Text('Review')),
                    ButtonSegment(value: ReviewMode.test, label: Text('Test')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _mode = newSelection.first;
                      _resetTestState();
                      if (_pageController.hasClients)
                        _pageController.jumpToPage(0);
                    });
                  },
                ),
              )
          ],
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              children: [
                const SizedBox(height: kToolbarHeight + 40),
                if (_shuffledCards.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / (_shuffledCards.length + 1),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _shuffledCards.length + 1,
                    itemBuilder: (context, index) {
                      if (index >= _shuffledCards.length) {
                        return _mode == ReviewMode.test
                            ? _buildTestCompletionScreen()
                            : _buildCompletionScreen();
                      }
                      if (_mode == ReviewMode.review) {
                        return Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: FlipCard(
                                front: _buildCardSide(
                                    _shuffledCards[index].question, "Question"),
                                back: _buildCardSide(
                                    _shuffledCards[index].answer, "Answer")));
                      } else {
                        return _buildTestCard(index);
                      }
                    },
                  ),
                ),
                if (_shuffledCards.isNotEmpty &&
                    _currentIndex < _shuffledCards.length)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Prev'),
                          onPressed: _currentIndex > 0 ? _previousCard : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.2),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        Text(
                          '${_currentIndex + 1} / ${_shuffledCards.length}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white, shadows: [
                            const Shadow(blurRadius: 2, color: Colors.black54)
                          ]),
                        ),
                        ElevatedButton.icon(
                          label: const Text('Next'),
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _nextCard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.2),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 80), // Placeholder for spacing
              ],
            ),
            // Confetti should be on top of the column
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
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
        ),
      ),
    );
  }

  Widget _buildAnswerFeedback(String correctAnswer, bool? isCorrect) {
    return Expanded(
      flex: 1,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isCorrect == true ? 'Correct!' : 'Incorrect',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isCorrect == true ? Colors.green : Colors.red,
              ),
            ),
            if (isCorrect == false) ...[
              const SizedBox(height: 8),
              const Text('The correct answer is:'),
              Text(
                correctAnswer,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
