import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            title: Text('Dil'),
            subtitle: Text('Türkçe'),
          ),
          ListTile(
            title: Text('Tema'),
            subtitle: Text('Sistem varsayılanı'),
          ),
        ],
      ),
    );
  }
}


