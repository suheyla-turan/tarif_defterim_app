import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    
    try {
      // TTS servisinin hazır olmasını bekle
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Dil ayarını yap - hata olursa varsayılan dili kullan
      try {
        final isTrAvailable = await _tts.isLanguageAvailable('tr-TR')
            .timeout(const Duration(seconds: 2));
        await _tts.setLanguage(isTrAvailable == true ? 'tr-TR' : 'en-US');
      } catch (_) {
        // Dil ayarı başarısız olursa varsayılan dili kullan
        try {
          await _tts.setLanguage('en-US');
        } catch (_) {
          // TTS servisi kullanılamıyor, devam et
        }
      }
      
      // Konuşma hızı ayarı
      try {
        await _tts.setSpeechRate(0.5);
      } catch (_) {
        // Hız ayarı başarısız olursa devam et
      }
      
      _initialized = true;
    } catch (_) {
      // Init başarısız olursa sessizce geç
      // Uygulama çalışmaya devam edecek
    }
  }

  Future<void> speak(String text) async {
    if (!_initialized) {
      await init();
    }
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Konuşma başarısız olursa sessizce geç
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Durdurma başarısız olursa sessizce geç
    }
  }
}
