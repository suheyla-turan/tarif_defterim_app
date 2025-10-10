import 'package:flutter/material.dart';
import '../../core/services/stt_service.dart';
import '../../core/services/tts_service.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final stt = STTService();
  final tts = TTSService();
  String lastHeard = '';

  @override
  void initState() {
    super.initState();
    tts.init();
    stt.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anasayfa')),
      body: ListView(
        children: [
          // mevcut listeler...
          const Divider(),
          ListTile(
            title: Text('Çırak test: $lastHeard'),
            subtitle: const Text('Bas-konuş (TR), duyduğunu tekrar et'),
            trailing: IconButton(
              icon: Icon(stt.isListening ? Icons.stop : Icons.mic),
              onPressed: () async {
                if (stt.isListening) {
                  await stt.stop();
                } else {
                  await stt.listen((text) {
                    setState(() => lastHeard = text);
                  });
                }
              },
            ),
            onLongPress: () async {
              if (lastHeard.isNotEmpty) await tts.speak(lastHeard);
            },
          ),
        ],
      ),
    );
  }
}
