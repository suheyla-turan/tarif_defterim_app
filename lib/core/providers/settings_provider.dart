import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { turkish, english }

enum AppTheme { light, dark, system }

class SettingsState {
  final AppLanguage language;
  final AppTheme theme;

  const SettingsState({
    this.language = AppLanguage.turkish,
    this.theme = AppTheme.system,
  });

  SettingsState copyWith({
    AppLanguage? language,
    AppTheme? theme,
  }) {
    return SettingsState(
      language: language ?? this.language,
      theme: theme ?? this.theme,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController() : super(const SettingsState()) {
    _loadSettings();
  }

  static const String _keyLanguage = 'app_language';
  static const String _keyTheme = 'app_theme';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final langStr = prefs.getString(_keyLanguage) ?? 'turkish';
    final themeStr = prefs.getString(_keyTheme) ?? 'system';

    state = SettingsState(
      language: langStr == 'english' ? AppLanguage.english : AppLanguage.turkish,
      theme: themeStr == 'light'
          ? AppTheme.light
          : themeStr == 'dark'
              ? AppTheme.dark
              : AppTheme.system,
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language == AppLanguage.english ? 'english' : 'turkish');
    state = state.copyWith(language: language);
  }

  Future<void> setTheme(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyTheme,
      theme == AppTheme.light
          ? 'light'
          : theme == AppTheme.dark
              ? 'dark'
              : 'system',
    );
    state = state.copyWith(theme: theme);
  }
}

final settingsProvider = StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController();
});

