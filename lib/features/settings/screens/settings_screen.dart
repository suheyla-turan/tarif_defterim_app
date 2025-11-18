import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/localization_provider.dart';
import '../../support/screens/faq_screen.dart';
import '../../support/screens/support_screen.dart';
import '../../support/screens/feedback_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsCtrl = ref.read(settingsProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Dil Seçimi
          Card(
            child: ExpansionTile(
              title: Text(l10n.language),
              subtitle: Text(
                settings.language == AppLanguage.turkish ? l10n.turkish : l10n.english,
              ),
              children: [
                RadioListTile<AppLanguage>(
                  title: Text(l10n.turkish),
                  value: AppLanguage.turkish,
                  groupValue: settings.language,
                  onChanged: (value) {
                    if (value != null) {
                      settingsCtrl.setLanguage(value);
                    }
                  },
                ),
                RadioListTile<AppLanguage>(
                  title: Text(l10n.english),
                  value: AppLanguage.english,
                  groupValue: settings.language,
                  onChanged: (value) {
                    if (value != null) {
                      settingsCtrl.setLanguage(value);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tema Seçimi
          Card(
            child: ExpansionTile(
              title: Text(l10n.theme),
              subtitle: Text(
                settings.theme == AppTheme.light
                    ? l10n.light
                    : settings.theme == AppTheme.dark
                        ? l10n.dark
                        : l10n.systemDefault,
              ),
              children: [
                RadioListTile<AppTheme>(
                  title: Text(l10n.light),
                  value: AppTheme.light,
                  groupValue: settings.theme,
                  onChanged: (value) {
                    if (value != null) {
                      settingsCtrl.setTheme(value);
                    }
                  },
                ),
                RadioListTile<AppTheme>(
                  title: Text(l10n.dark),
                  value: AppTheme.dark,
                  groupValue: settings.theme,
                  onChanged: (value) {
                    if (value != null) {
                      settingsCtrl.setTheme(value);
                    }
                  },
                ),
                RadioListTile<AppTheme>(
                  title: Text(l10n.systemDefault),
                  value: AppTheme.system,
                  groupValue: settings.theme,
                  onChanged: (value) {
                    if (value != null) {
                      settingsCtrl.setTheme(value);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // SSS
          Card(
            child: ListTile(
              title: Text(l10n.faq),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FAQScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Destek
          Card(
            child: ListTile(
              title: Text(l10n.support),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SupportScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Geribildirim
          Card(
            child: ListTile(
              title: Text(l10n.feedback),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FeedbackScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Hakkında
          Card(
            child: ListTile(
              title: Text(l10n.about),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.about),
                    content: SingleChildScrollView(
                      child: Text(l10n.aboutContent),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l10n.close),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


