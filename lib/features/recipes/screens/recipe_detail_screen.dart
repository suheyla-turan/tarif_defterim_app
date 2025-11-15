import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../application/recipes_provider.dart';
import '../../../core/providers/auth_provider.dart' as feature_auth;
import '../models/recipe.dart';
import '../../shopping/application/shopping_provider.dart';
import '../../ai/application/ai_recipe_service.dart' as ai;

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
    try {
      // Android'de Google TTS motorunu tercih et (mevcutsa)
      await _tts.setEngine('com.google.android.tts');

      // Konuşma tamamlanmasını bekleme davranışını aç
      await _tts.awaitSpeakCompletion(true);

      // Dil uygun mu kontrol et; değilse güvenli bir zemine düş
      final isTrAvailable = await _tts.isLanguageAvailable('tr-TR') == true;
      await _tts.setLanguage(isTrAvailable ? 'tr-TR' : 'en-US');

      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);

      // Bazı cihazlarda başlangıçta null ses dönebiliyor; ses listesinden TR seçmeyi dene
      final voices = await _tts.getVoices;
      if (voices is List) {
        final trVoice = voices.cast<Map>().cast<Map<dynamic, dynamic>>().firstWhere(
          (v) => (v['locale']?.toString().toLowerCase() == 'tr-tr'),
          orElse: () => const {},
        );
        if (trVoice.isNotEmpty) {
          await _tts.setVoice({
            'name': trVoice['name'],
            'locale': trVoice['locale'],
          });
        }
      }

      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = false);
        }
      });
    } catch (_) {
      // Init sırasında hata olursa (ör. emülatörde TTS motoru yok), sessizce geç
    }
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
    // Bazı cihazlarda sızıntıyı önlemek için konuşmayı bekleme kapatılabilir
    _tts.awaitSpeakCompletion(false);
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
                heroTag: 'ai-vegan',
                onPressed: () async {
                  final service = ref.read(ai.aiRecipeServiceProvider);
                  final transformed = await service.transformRecipe(
                    base: widget.recipe,
                    type: ai.RecipeTransformType.vegan,
                  );
                  if (!mounted) return;
                  _showTransformedSheet(context, transformed);
                },
                icon: const Icon(Icons.eco_outlined),
                label: const Text('Vegan'),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: 'ai-diet',
                onPressed: () async {
                  final service = ref.read(ai.aiRecipeServiceProvider);
                  final transformed = await service.transformRecipe(
                    base: widget.recipe,
                    type: ai.RecipeTransformType.diet,
                  );
                  if (!mounted) return;
                  _showTransformedSheet(context, transformed);
                },
                icon: const Icon(Icons.local_fire_department_outlined),
                label: const Text('Diyet'),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: 'ai-portion',
                onPressed: () async {
                  final portions = await _askPortion(context);
                  if (portions == null) return;
                  final service = ref.read(ai.aiRecipeServiceProvider);
                  final transformed = await service.transformRecipe(
                    base: widget.recipe,
                    type: ai.RecipeTransformType.portion,
                    targetPortions: portions,
                  );
                  if (!mounted) return;
                  _showTransformedSheet(context, transformed);
                },
                icon: const Icon(Icons.reduce_capacity_outlined),
                label: const Text('Porsiyon'),
              ),
              const SizedBox(height: 8),
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
              if (widget.recipe.imageUrls.isNotEmpty) ...[
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.recipe.imageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final url = widget.recipe.imageUrls[index];
                      return InkWell(
                        onTap: () => _openImageViewer(url),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Theme.of(context).colorScheme.surface,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
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

  Future<int?> _askPortion(BuildContext context) async {
    final controller = TextEditingController(text: '2');
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Porsiyon sayısı'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Örn: 2'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            FilledButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                Navigator.pop(ctx, val);
              },
              child: const Text('Uygula'),
            ),
          ],
        );
      },
    );
    return res;
  }

  void _showTransformedSheet(BuildContext context, Recipe transformed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                Text(transformed.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('Malzemeler', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                ...transformed.ingredients.map((e) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(e),
                    )),
                const SizedBox(height: 12),
                Text('Adımlar', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                ...transformed.steps.asMap().entries.map((e) => ListTile(
                      dense: true,
                      leading: CircleAvatar(child: Text('${e.key + 1}')),
                      title: Text(e.value),
                    )),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  void _openImageViewer(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}


