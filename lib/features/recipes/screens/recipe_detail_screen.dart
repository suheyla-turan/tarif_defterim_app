import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../application/recipes_provider.dart';
import '../../auth/application/auth_controller.dart' as feature_auth;
import '../models/recipe.dart';
import '../../shopping/application/shopping_provider.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();
  int _currentStepIndex = 0;
  bool _isSpeaking = false;
  bool _sttAvailable = false;

  @override
  void initState() {
    super.initState();
    _setupTts();
    _setupStt();
  }

  Future<void> _setupTts() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _setupStt() async {
    _sttAvailable = await _stt.initialize();
    setState(() {});
  }

  Future<void> _speakCurrent() async {
    if (_currentStepIndex < 0 || _currentStepIndex >= widget.recipe.steps.length) return;
    setState(() => _isSpeaking = true);
    await _tts.speak('Adım ${_currentStepIndex + 1}. ${widget.recipe.steps[_currentStepIndex]}');
  }

  Future<void> _stop() async {
    await _tts.stop();
    setState(() => _isSpeaking = false);
  }

  Future<void> _pause() async {
    await _tts.pause();
    setState(() => _isSpeaking = false);
  }

  void _nextStep() {
    if (_currentStepIndex < widget.recipe.steps.length - 1) {
      setState(() => _currentStepIndex++);
      _speakCurrent();
    }
  }

  void _prevStep() {
    if (_currentStepIndex > 0) {
      setState(() => _currentStepIndex--);
      _speakCurrent();
    }
  }

  void _startListening() async {
    if (!_sttAvailable) return;
    await _stt.listen(
      localeId: 'tr_TR',
      onResult: (res) {
        final text = res.recognizedWords.toLowerCase();
        if (text.contains('başlat') || text.contains('oku')) {
          _speakCurrent();
        } else if (text.contains('durdur') || text.contains('bitir')) {
          _stop();
        } else if (text.contains('devam')) {
          _speakCurrent();
        } else if (text.contains('sonraki') || text.contains('ileri')) {
          _nextStep();
        } else if (text.contains('önceki') || text.contains('geri')) {
          _prevStep();
        }
      },
    );
  }

  void _stopListening() async {
    if (!_sttAvailable) return;
    await _stt.stop();
  }

  @override
  void dispose() {
    _stop();
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(recipesRepositoryProvider);
    final user = ref.watch(feature_auth.authControllerProvider).user;
    final likedStream = (user == null)
        ? const Stream<bool>.empty()
        : repo.watchUserLiked(recipeId: widget.recipe.id, userId: user.uid);
    final shoppingCtrl = ref.read(shoppingControllerProvider.notifier);

    return StreamBuilder<bool>(
      stream: likedStream,
      builder: (context, snap) {
        final liked = snap.data == true;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.recipe.title),
            actions: [
              IconButton(
                tooltip: 'Alışverişe ekle',
                icon: const Icon(Icons.add_shopping_cart_outlined),
                onPressed: () async {
                  await shoppingCtrl.addRecipeToList(widget.recipe);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alışveriş listesine eklendi')),
                    );
                  }
                },
              ),
              IconButton(
                tooltip: liked ? 'Beğenmekten vazgeç' : 'Beğen',
                icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
                onPressed: user == null
                    ? null
                    : () async {
                        await repo.setUserLike(
                          recipeId: widget.recipe.id,
                          userId: user.uid,
                          like: !liked,
                        );
                      },
              )
            ],
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: 'tts',
                onPressed: _isSpeaking ? _pause : _speakCurrent,
                icon: Icon(_isSpeaking ? Icons.pause : Icons.play_arrow),
                label: Text(_isSpeaking ? 'Durdur' : 'Oku'),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: 'stt',
                onPressed: _stt.isListening ? _stopListening : _startListening,
                icon: Icon(_stt.isListening ? Icons.mic_off : Icons.mic),
                label: Text(_stt.isListening ? 'Komut: Kapalı' : 'Komut: Aç'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Tür: ${widget.recipe.mainType}')),
                  if (widget.recipe.subType != null)
                    Chip(label: Text('Alt tür: ${widget.recipe.subType}')),
                  if (widget.recipe.country != null)
                    Chip(label: Text('Ülke: ${widget.recipe.country}')),
                ],
              ),
              const SizedBox(height: 8),
              Text(widget.recipe.description ?? ''),
              const SizedBox(height: 16),
              Text('Beğeni: ${widget.recipe.likesCount}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Text('Malzemeler', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...widget.recipe.ingredients.map((e) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(e),
                  )),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Adımlar', style: Theme.of(context).textTheme.titleLarge),
                  Text('Adım ${_currentStepIndex + 1}/${widget.recipe.steps.length}')
                ],
              ),
              const SizedBox(height: 8),
              ...widget.recipe.steps.asMap().entries.map((e) {
                final idx = e.key;
                final step = e.value;
                final selected = idx == _currentStepIndex;
                return Card(
                  color: selected ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${idx + 1}')),
                    title: Text(step),
                    onTap: () {
                      setState(() => _currentStepIndex = idx);
                      _speakCurrent();
                    },
                  ),
                );
              }),
              const SizedBox(height: 72),
            ],
          ),
        );
      },
    );
  }
}


