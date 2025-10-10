import 'package:speech_to_text/speech_to_text.dart' as stt;

class STTService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool get isListening => _speech.isListening;

  Future<bool> init() async {
    _available = await _speech.initialize();
    return _available;
  }

  Future<void> listen(void Function(String text) onText, {String localeId = 'tr_TR'}) async {
    if (!_available) await init();
    if (!_available) return;
    await _speech.listen(
      localeId: localeId,
      partialResults: true,
      onResult: (r) { if (r.recognizedWords.isNotEmpty) onText(r.recognizedWords); },
    );
  }

  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();
}
