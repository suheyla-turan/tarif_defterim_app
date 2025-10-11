import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingProvider extends ChangeNotifier {
  static const _key = 'onboarding_completed';

  bool _isCompleted = false;
  bool _isReady = false;

  bool get isCompleted => _isCompleted;
  bool get isReady => _isReady;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isCompleted = prefs.getBool(_key) ?? false;
    _isReady = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    _isCompleted = true;
    await prefs.setBool(_key, true);
    notifyListeners();
  }

  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    _isCompleted = false;
    await prefs.setBool(_key, false);
    notifyListeners();
  }
}
