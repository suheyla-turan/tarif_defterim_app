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
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

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
              IconButton(
                tooltip: l10n.isTurkish ? 'Tarif AI sohbeti' : 'Recipe AI chat',
                icon: const Icon(Icons.smart_toy_outlined),
                onPressed: () => _openRecipeAiChat(currentRecipe),
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

  void _openRecipeAiChat(Recipe recipe) {
    final service = ref.read(ai.aiRecipeServiceProvider);
    final l10n = AppLocalizations.of(context);
    final questionController = TextEditingController();
    final portionController = TextEditingController(text: (recipe.portions ?? 2).toString());
    String? answer;
    Recipe? transformedRecipe;
    bool isLoading = false;
    String? errorText;
    File? attachedImage;
    String? attachedImageUrl;
    bool isUploadingImage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: StatefulBuilder(
                builder: (ctx, setModalState) {
                  Future<void> runTransform(ai.RecipeTransformType type) async {
                    setModalState(() {
                      isLoading = true;
                      errorText = null;
                      answer = null;
                      transformedRecipe = null;
                    });
                    try {
                      final res = await service.transformRecipe(
                        base: recipe,
                        type: type,
                      );
                      setModalState(() {
                        transformedRecipe = res;
                      });
                    } catch (e) {
                      setModalState(() {
                        errorText = l10n.isTurkish
                            ? 'Tarif dönüştürülürken bir hata oluştu.'
                            : 'An error occurred while transforming the recipe.';
                      });
                    } finally {
                      setModalState(() {
                        isLoading = false;
                      });
                    }
                  }

                  Future<void> sendQuestion(String q) async {
                    final trimmed = q.trim();
                    if (trimmed.isEmpty) {
                      setModalState(() {
                        errorText = l10n.isTurkish
                            ? 'Lütfen tarifle ilgili bir soru yazın.'
                            : 'Please enter a question about the recipe.';
                      });
                      return;
                    }
                    // Kullanıcı "vegan/diyet versiyon" gibi bir ifade ile özellikle dönüşüm istiyorsa,
                    // metin tabanlı cevap yerine doğrudan tarif dönüştürme fonksiyonunu kullan.
                    final lower = trimmed.toLowerCase();
                    final wantsVegan = lower.contains('vegan versiyon') ||
                        lower.contains('vegan yap') ||
                        lower.contains('vegan hale') ||
                        lower.contains("vegana çevir") ||
                        lower.contains('vegan olsun');
                    final wantsDiet = lower.contains('diyet versiyon') ||
                        lower.contains('diyet yap') ||
                        lower.contains('diyet hale') ||
                        lower.contains("diyete çevir") ||
                        lower.contains('diyet olsun');
                    if (wantsVegan) {
                      await runTransform(ai.RecipeTransformType.vegan);
                      return;
                    }
                    if (wantsDiet) {
                      await runTransform(ai.RecipeTransformType.diet);
                      return;
                    }
                    setModalState(() {
                      isLoading = true;
                      errorText = null;
                      answer = null;
                      transformedRecipe = null;
                    });
                    try {
                      String? imageUrlToSend = attachedImageUrl;
                      if (attachedImage != null && attachedImageUrl == null) {
                        setModalState(() {
                          isUploadingImage = true;
                        });
                        try {
                          final storage = FirebaseStorage.instance;
                          final name =
                              'ai_questions/${DateTime.now().millisecondsSinceEpoch}_${attachedImage!.path.split('/').last}';
                          final ref = storage.ref().child(name);
                          final task = await ref.putFile(attachedImage!);
                          imageUrlToSend = await task.ref.getDownloadURL();
                          setModalState(() {
                            attachedImageUrl = imageUrlToSend;
                          });
                        } catch (_) {
                          // upload error, ignore image
                          imageUrlToSend = null;
                        } finally {
                          setModalState(() {
                            isUploadingImage = false;
                          });
                        }
                      }
                      final res = await service.askRecipeQuestion(
                        recipe: recipe,
                        question: trimmed,
                        imageUrl: imageUrlToSend,
                      );
                      setModalState(() {
                        answer = res;
                      });
                    } catch (e) {
                      setModalState(() {
                        errorText = l10n.isTurkish
                            ? 'Yanıt alınırken bir hata oluştu.'
                            : 'An error occurred while getting the answer.';
                      });
                    } finally {
                      setModalState(() {
                        isLoading = false;
                      });
                    }
                  }

                  Future<void> sendPortionQuestion() async {
                    final text = portionController.text.trim();
                    final val = int.tryParse(text);
                    if (val == null || val <= 0) {
                      setModalState(() {
                        errorText = l10n.isTurkish
                            ? 'Lütfen geçerli bir porsiyon sayısı yazın.'
                            : 'Please enter a valid portion count.';
                      });
                      return;
                    }
                    final q = l10n.isTurkish
                        ? '${recipe.title} tarifini $val kişilik olacak şekilde porsiyonla ve malzemeleri/adımları buna göre güncelle.'
                        : 'Scale the recipe "${recipe.title}" to serve $val people and update ingredients/steps accordingly.';
                    await sendQuestion(q);
                  }

                  Future<void> pickImage() async {
                    final picker = ImagePicker();
                    final source = await showModalBottomSheet<ImageSource>(
                      context: context,
                      builder: (c) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.photo_library_outlined),
                              title: Text(l10n.isTurkish ? 'Galeriden seç' : 'From gallery'),
                              onTap: () => Navigator.pop(c, ImageSource.gallery),
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_camera_outlined),
                              title: Text(l10n.isTurkish ? 'Kameradan çek' : 'From camera'),
                              onTap: () => Navigator.pop(c, ImageSource.camera),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (source == null) return;
                    final file = await picker.pickImage(
                      source: source,
                      imageQuality: 85,
                      maxWidth: 1600,
                    );
                    if (file == null) return;
                    setModalState(() {
                      attachedImage = File(file.path);
                      attachedImageUrl = null;
                    });
                  }

                  return SafeArea(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        Text(
                          l10n.isTurkish
                              ? 'Tarif AI asistan'
                              : 'Recipe AI assistant',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.isTurkish
                              ? 'Bu sayfa sadece bu tarifin başlığı, malzemeleri ve adımlarına göre cevap verir.'
                              : 'This page answers only based on this recipe\'s title, ingredients and steps.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.eco_outlined, size: 18),
                              label: Text(l10n.isTurkish ? 'Vegan yap' : 'Make vegan'),
                              onPressed: isLoading
                                  ? null
                                  : () => runTransform(ai.RecipeTransformType.vegan),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.local_fire_department_outlined, size: 18),
                              label: Text(l10n.isTurkish ? 'Diyet versiyon' : 'Diet version'),
                              onPressed: isLoading
                                  ? null
                                  : () => runTransform(ai.RecipeTransformType.diet),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.isTurkish
                              ? 'Porsiyon ayarla'
                              : 'Adjust portions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: portionController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: l10n.isTurkish
                                      ? 'Kaç kişilik olsun?'
                                      : 'How many servings?',
                                  hintText: l10n.isTurkish ? 'Örn: 4' : 'e.g. 4',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: isLoading ? null : sendPortionQuestion,
                              child: Text(l10n.isTurkish ? 'Uygula' : 'Apply'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.isTurkish
                              ? 'Kendi sorunuzu yazın'
                              : 'Ask your own question',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.isTurkish
                              ? 'Fotoğraflı soru (isteğe bağlı)'
                              : 'Photo question (optional)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: isUploadingImage ? null : pickImage,
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: Text(
                                l10n.isTurkish ? 'Fotoğraf ekle' : 'Add photo',
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (isUploadingImage)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (attachedImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              attachedImage!,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.isTurkish
                              ? 'Kendi sorunuzu yazın'
                              : 'Ask your own question',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: questionController,
                          textInputAction: TextInputAction.send,
                          maxLines: 4,
                          minLines: 1,
                          onSubmitted: (_) => sendQuestion(questionController.text),
                          decoration: InputDecoration(
                            hintText: l10n.isTurkish
                                ? 'Örn: Bu tarif kaç kalori? Hangi malzemeyi çıkarabilirim?'
                                : 'e.g. How many calories is this? Which ingredient can I remove?',
                            errorText: errorText,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: isLoading
                                ? null
                                : () => sendQuestion(questionController.text),
                            icon: isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                            label: Text(
                              l10n.isTurkish ? 'Sor' : 'Ask',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (transformedRecipe != null || answer != null) ...[
                          Divider(color: Theme.of(context).dividerColor),
                          const SizedBox(height: 8),
                          Text(
                            l10n.isTurkish ? 'Yapay zeka cevabı' : 'AI answer',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (transformedRecipe != null) ...[
                            Text(
                              transformedRecipe!.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.isTurkish ? 'Malzemeler:' : 'Ingredients:',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            ...transformedRecipe!.ingredients.map(
                              (ing) => Text('• $ing',
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.isTurkish ? 'Adımlar:' : 'Steps:',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            ...transformedRecipe!.steps.asMap().entries.map(
                              (e) => Text(
                                '${e.key + 1}. ${e.value}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (answer != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              answer!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
