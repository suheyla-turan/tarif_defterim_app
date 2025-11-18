import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../application/recipes_provider.dart';
import '../../../core/providers/auth_provider.dart' as feature_auth;
import '../../../core/providers/localization_provider.dart';
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
  bool _isReadingAllSteps = false; // Tüm adımları okuma modunda mıyız?
  bool _isPaused = false; // Duraklatıldı mı?
  bool _isContinuousListeningEnabled = false; // Sürekli dinleme modu aktif mi?

  bool _ttsInitialized = false;
  bool _sttInitialized = false;

  @override
  void initState() {
    super.initState();
    // TTS ve STT'yi lazy olarak başlat - main thread'i bloklamamak için
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTts();
      _setupStt();
    });
  }

  Future<void> _setupTts() async {
    if (_ttsInitialized) return;
    _ttsInitialized = true;
    
    try {
      // TTS servisinin hazır olmasını bekle
      await Future.delayed(const Duration(milliseconds: 500));

      // Android'de Google TTS motorunu tercih et (mevcutsa) - opsiyonel
      try {
        await _tts.setEngine('com.google.android.tts')
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        // Engine ayarı başarısız olursa varsayılan engine'i kullan
      }

      // Konuşma tamamlanmasını bekleme davranışını aç
      try {
        await _tts.awaitSpeakCompletion(true);
      } catch (_) {
        // Bu ayar başarısız olursa devam et
      }

      // Dil uygun mu kontrol et; değilse güvenli bir zemine düş
      String selectedLanguage = 'en-US'; // Varsayılan dil
      try {
        final languageCheck = await _tts.isLanguageAvailable('tr-TR')
            .timeout(const Duration(seconds: 2));
        if (languageCheck == true) {
          selectedLanguage = 'tr-TR';
        }
      } catch (_) {
        // Dil kontrolü başarısız olursa varsayılan dili kullan
      }

      // Dil ayarını yap
      try {
        await _tts.setLanguage(selectedLanguage);
      } catch (_) {
        // Dil ayarı başarısız olursa devam et
      }

      // Konuşma hızı ve perde ayarları
      try {
        await _tts.setSpeechRate(0.5);
        await _tts.setPitch(1.0);
      } catch (_) {
        // Bu ayarlar başarısız olursa devam et
      }

      // Ses listesinden TR ses seçmeyi dene
      try {
        final voices = await _tts.getVoices
            .timeout(const Duration(seconds: 2));
        if (voices is List && voices.isNotEmpty) {
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
      } catch (_) {
        // Ses seçimi başarısız olursa devam et
      }

      // Completion handler ayarla
      try {
        _tts.setCompletionHandler(() {
          if (mounted) {
            setState(() => _isSpeaking = false);
            // Eğer tüm adımları okuyorsak ve duraklatılmadıysa bir sonraki adıma geç
            if (_isReadingAllSteps && !_isPaused) {
              _continueToNextStep();
            }
          }
        });
      } catch (_) {
        // Handler ayarı başarısız olursa devam et
      }
    } catch (_) {
      // Init sırasında hata olursa (ör. emülatörde TTS motoru yok), sessizce geç
      // Uygulama çalışmaya devam edecek, sadece TTS özelliği çalışmayabilir
    }
  }

  Future<void> _setupStt() async {
    if (_sttInitialized) return;
    _sttInitialized = true;
    
    try {
      _sttAvailable = await _stt.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // STT başlatma başarısız olursa sessizce geç
      _sttAvailable = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  // Sayıyı Türkçe metne çevir (ör: 1 -> "bir", 2 -> "iki")
  String _numberToTurkishText(int number) {
    const turkishNumbers = [
      'bir', 'iki', 'üç', 'dört', 'beş', 'altı', 'yedi', 'sekiz', 'dokuz', 'on',
      'on bir', 'on iki', 'on üç', 'on dört', 'on beş', 'on altı', 'on yedi', 'on sekiz', 'on dokuz', 'yirmi',
      'yirmi bir', 'yirmi iki', 'yirmi üç', 'yirmi dört', 'yirmi beş', 'yirmi altı', 'yirmi yedi', 'yirmi sekiz', 'yirmi dokuz', 'otuz',
      'otuz bir', 'otuz iki', 'otuz üç', 'otuz dört', 'otuz beş', 'otuz altı', 'otuz yedi', 'otuz sekiz', 'otuz dokuz', 'kırk',
      'kırk bir', 'kırk iki', 'kırk üç', 'kırk dört', 'kırk beş', 'kırk altı', 'kırk yedi', 'kırk sekiz', 'kırk dokuz', 'elli',
    ];
    
    if (number > 0 && number <= turkishNumbers.length) {
      return turkishNumbers[number - 1];
    }
    // Eğer sayı listede yoksa, sayıyı string olarak döndür
    return number.toString();
  }

  Future<void> _speakCurrent() async {
    if (_currentStepIndex < 0 || _currentStepIndex >= widget.recipe.steps.length) {
      // Tüm adımlar bitti
      if (_isReadingAllSteps) {
        _isReadingAllSteps = false;
        _isPaused = false;
        if (mounted) {
          setState(() {});
        }
      }
      return;
    }
    if (!_ttsInitialized) {
      await _setupTts();
    }
    if (mounted) {
      setState(() => _isSpeaking = true);
    }
    try {
      final stepNumber = _currentStepIndex + 1;
      final stepNumberText = _numberToTurkishText(stepNumber);
      await _tts.speak('Adım $stepNumberText. ${widget.recipe.steps[_currentStepIndex]}');
    } catch (_) {
      // Konuşma başarısız olursa sessizce geç
      if (mounted) {
        setState(() => _isSpeaking = false);
        // Hata olursa da bir sonraki adıma geçmeyi dene
        if (_isReadingAllSteps && !_isPaused) {
          _continueToNextStep();
        }
      }
    }
  }

  void _continueToNextStep() {
    if (_currentStepIndex < widget.recipe.steps.length - 1) {
      setState(() => _currentStepIndex++);
      _speakCurrent();
    } else {
      // Tüm adımlar bitti
      _isReadingAllSteps = false;
      _isPaused = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Durdurma başarısız olursa sessizce geç
    }
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isReadingAllSteps = false;
        _isPaused = false;
      });
    }
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

  void _startContinuousListening() async {
    if (!_sttAvailable) return;
    
    // Eğer zaten dinliyorsa, tekrar başlatma
    if (_stt.isListening) return;
    
    _isContinuousListeningEnabled = true;
    
    try {
      await _stt.listen(
        localeId: 'tr_TR',
        listenFor: const Duration(minutes: 10), // Uzun süre dinle
        pauseFor: const Duration(seconds: 3),
        onResult: (res) {
          final text = res.recognizedWords.toLowerCase().trim();
          
          // "çırak dur" komutunu algıla - sadece okumayı durdur, dinlemeye devam et
          if (text.contains('çırak') && text.contains('dur')) {
            _pauseReading();
            // Dinlemeyi durdurma, sürekli dinlemeye devam et
            return;
          }
          // "çırak devam et" komutunu algıla
          else if (text.contains('çırak') && (text.contains('devam') || text.contains('devam et'))) {
            _resumeReading();
            // Eğer dinleme durmuşsa ve sürekli dinleme modu aktifse tekrar başlat
            if (!_stt.isListening && _isContinuousListeningEnabled) {
              _startContinuousListening();
            }
            return;
          }
          // "çırak başla" veya sadece "çırak" komutunu algıla - tüm adımları okumaya başla
          else if (text.contains('çırak') && (text.contains('başla') || (!text.contains('dur') && !text.contains('devam')))) {
            if (!_isReadingAllSteps && !_isSpeaking) {
              _startReadingAllSteps();
            }
            return;
          }
          // "başla" komutunu algıla (çırak olmadan da çalışır)
          else if (text.contains('başla') || text.contains('başlat') || text.contains('oku')) {
            if (!_isReadingAllSteps && !_isSpeaking) {
              _startReadingAllSteps();
            }
            return;
          }
          // "dur" komutunu algıla (çırak olmadan da çalışır) - sadece okumayı durdur
          else if (text.contains('dur') || text.contains('durdur') || text.contains('bitir')) {
            // Eğer "çırak dur" ise zaten yukarıda işlendi
            if (!text.contains('çırak')) {
              _pauseReading();
            }
            return;
          }
          // "devam et" komutunu algıla (çırak olmadan da çalışır)
          else if (text.contains('devam')) {
            // Eğer "çırak devam" ise zaten yukarıda işlendi
            if (!text.contains('çırak')) {
              _resumeReading();
              // Eğer dinleme durmuşsa ve sürekli dinleme modu aktifse tekrar başlat
              if (!_stt.isListening && _isContinuousListeningEnabled) {
                _startContinuousListening();
              }
            }
            return;
          }
          // Navigasyon komutları
          else if (text.contains('sonraki') || text.contains('ileri')) {
            if (!_isReadingAllSteps) {
              _nextStep();
            }
          } else if (text.contains('önceki') || text.contains('geri')) {
            if (!_isReadingAllSteps) {
              _prevStep();
            }
          }
        },
        onSoundLevelChange: (_) {
          // Ses seviyesi değişikliklerini dinle (opsiyonel)
        },
      );
      
      // Dinleme süresi dolduğunda otomatik olarak yeniden başlat
      Future.delayed(const Duration(minutes: 10), () {
        if (mounted && _isContinuousListeningEnabled && !_stt.isListening) {
          _startContinuousListening();
        }
      });
      
      // Periyodik olarak dinleme durumunu kontrol et ve gerekirse yeniden başlat
      _monitorListeningStatus();
    } catch (e) {
      // Hata olursa tekrar dene
      if (mounted && _isContinuousListeningEnabled) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isContinuousListeningEnabled) {
            _startContinuousListening();
          }
        });
      }
    }
  }
  
  void _monitorListeningStatus() {
    // Her 2 saniyede bir dinleme durumunu kontrol et
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isContinuousListeningEnabled) {
        if (!_stt.isListening && _sttAvailable) {
          // Dinleme durmuş, yeniden başlat
          _startContinuousListening();
        } else {
          // Hala dinliyorsa tekrar kontrol et
          _monitorListeningStatus();
        }
      }
    });
  }

  void _startReadingAllSteps() {
    if (_isReadingAllSteps) return;
    
    _isReadingAllSteps = true;
    _isPaused = false;
    _currentStepIndex = 0; // Baştan başla
    if (mounted) {
      setState(() {});
    }
    _speakCurrent();
  }

  void _pauseReading() {
    _isPaused = true;
    _stop();
    if (mounted) {
      setState(() {});
    }
  }

  void _resumeReading() {
    if (!_isReadingAllSteps) {
      // Eğer hiç başlamadıysa başlat
      _startReadingAllSteps();
    } else if (_isPaused) {
      // Duraklatılmışsa devam et
      _isPaused = false;
      if (mounted) {
        setState(() {});
      }
      _speakCurrent();
    }
  }

  void _stopListening() async {
    if (!_sttAvailable) return;
    _isContinuousListeningEnabled = false;
    await _stt.stop();
  }

  @override
  void dispose() {
    _isContinuousListeningEnabled = false;
    _stop();
    _stopListening();
    // Bazı cihazlarda sızıntıyı önlemek için konuşmayı bekleme kapatılabilir
    try {
      _tts.awaitSpeakCompletion(false);
    } catch (_) {
      // Hata olursa sessizce geç
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(recipesRepositoryProvider);
    final user = ref.watch(feature_auth.authControllerProvider).user;
    final l10n = AppLocalizations.of(context);
    final likedStream = (user == null)
        ? const Stream<bool>.empty()
        : repo.watchUserLiked(recipeId: widget.recipe.id, userId: user.uid);
    final recipeStream = repo.watchRecipeById(widget.recipe.id);
    final shoppingCtrl = ref.read(shoppingControllerProvider.notifier);

    return StreamBuilder<Recipe>(
      stream: recipeStream,
      builder: (context, recipeSnap) {
        final currentRecipe = recipeSnap.data ?? widget.recipe;
        return StreamBuilder<bool>(
          stream: likedStream,
          builder: (context, likedSnap) {
            final liked = likedSnap.data == true;
            return Scaffold(
          appBar: AppBar(
            title: Text(currentRecipe.title),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                tooltip: l10n.addToShoppingList,
                icon: const Icon(Icons.add_shopping_cart_outlined),
                onPressed: () async {
                  await shoppingCtrl.addRecipeToList(currentRecipe);
                  if (!mounted) return;
                  
                  // State'i kontrol et
                  final state = ref.read(shoppingControllerProvider);
                  if (state.hasError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: ${state.error}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.addedToShoppingList)),
                    );
                  }
                },
              ),
              IconButton(
                tooltip: liked ? l10n.unlike : l10n.like,
                icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
                onPressed: user == null
                    ? null
                    : () async {
                        await repo.setUserLike(
                          recipeId: currentRecipe.id,
                          userId: user.uid,
                          like: !liked,
                        );
                      },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'vegan') {
                    final service = ref.read(ai.aiRecipeServiceProvider);
                    final transformed = await service.transformRecipe(
                      base: currentRecipe,
                      type: ai.RecipeTransformType.vegan,
                    );
                    if (!mounted) return;
                    _showTransformedSheet(context, transformed);
                  } else if (value == 'diet') {
                    final service = ref.read(ai.aiRecipeServiceProvider);
                    final transformed = await service.transformRecipe(
                      base: currentRecipe,
                      type: ai.RecipeTransformType.diet,
                    );
                    if (!mounted) return;
                    _showTransformedSheet(context, transformed);
                  } else if (value == 'portion') {
                    final portions = await _askPortion(context);
                    if (portions == null) return;
                    final service = ref.read(ai.aiRecipeServiceProvider);
                    final transformed = await service.transformRecipe(
                      base: currentRecipe,
                      type: ai.RecipeTransformType.portion,
                      targetPortions: portions,
                    );
                    if (!mounted) return;
                    _showTransformedSheet(context, transformed);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'vegan',
                    child: Row(
                      children: [
                        const Icon(Icons.eco_outlined),
                        const SizedBox(width: 8),
                        Text(l10n.vegan),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'diet',
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department_outlined),
                        const SizedBox(width: 8),
                        Text(l10n.diet),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'portion',
                    child: Row(
                      children: [
                        const Icon(Icons.reduce_capacity_outlined),
                        const SizedBox(width: 8),
                        Text(l10n.portion),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: _sttAvailable
              ? FloatingActionButton.extended(
                  heroTag: 'cirak',
                  onPressed: () {
                    final l10n = AppLocalizations.of(context);
                    if (!_isContinuousListeningEnabled || !_stt.isListening) {
                      // Dinleme modunu başlat - bir kez basınca sürekli dinlemeye başla
                      _startContinuousListening();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.isTurkish 
                              ? 'Çırak aktif! "Çırak başla", "Çırak dur", "Çırak devam et" komutlarını kullanabilirsiniz.' 
                              : 'Assistant active! Use "Assistant start", "Assistant stop", "Assistant continue" commands.'),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    } else {
                      // Tekrar basınca dinlemeyi durdur
                      _stopListening();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.isTurkish 
                              ? 'Çırak durduruldu. Tekrar başlatmak için butona basın.' 
                              : 'Assistant stopped. Press the button to start again.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: Icon(_stt.isListening 
                      ? (_isReadingAllSteps ? Icons.volume_up : Icons.mic) 
                      : Icons.mic_none),
                  label: Text(_stt.isListening 
                      ? (_isReadingAllSteps 
                          ? (AppLocalizations.of(context).isTurkish ? 'Okuyor...' : 'Reading...')
                          : AppLocalizations.of(context).cirakListening) 
                      : AppLocalizations.of(context).cirak),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (currentRecipe.imageUrls.isNotEmpty) ...[
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: currentRecipe.imageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final url = currentRecipe.imageUrls[index];
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
              Row(
                children: [
                  Text('${AppLocalizations.of(context).type}: ', style: Theme.of(context).textTheme.titleMedium),
                  Text(currentRecipe.mainType, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
              if (currentRecipe.subType != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${AppLocalizations.of(context).subType}: ', style: Theme.of(context).textTheme.titleMedium),
                    Text(currentRecipe.subType!, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${AppLocalizations.of(context).likes}: ', style: Theme.of(context).textTheme.titleMedium),
                  Text('${currentRecipe.likesCount}', style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
              if (currentRecipe.description != null && currentRecipe.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context).description, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(currentRecipe.description!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).ingredients, style: Theme.of(context).textTheme.titleLarge),
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
                  Text(AppLocalizations.of(context).steps, style: Theme.of(context).textTheme.titleLarge),
                  Text('${AppLocalizations.of(context).step} ${_currentStepIndex + 1}/${widget.recipe.steps.length}')
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
              const SizedBox(height: 100),
            ],
          ),
            );
          },
        );
      },
    );
  }

  Future<int?> _askPortion(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: '2');
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.portionCount),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: l10n.portionExample),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                Navigator.pop(ctx, val);
              },
              child: Text(l10n.apply),
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
                Text(AppLocalizations.of(context).ingredients, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                ...transformed.ingredients.map((e) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(e),
                    )),
                const SizedBox(height: 12),
                Text(AppLocalizations.of(context).steps, style: Theme.of(context).textTheme.titleMedium),
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


