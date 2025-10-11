import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  String? _userEmail;

  String? get userEmail => _userEmail;
  bool get isLoggedIn => _userEmail != null;

  Future<void> signIn({required String email, required String password}) async {
    // TODO: FirebaseAuth ile değiştir
    await Future.delayed(const Duration(milliseconds: 400));
    _userEmail = email;
    notifyListeners();
  }

  Future<void> signUp({required String name, required String email, required String password}) async {
    // TODO: Firebase createUser + Firestore profil
    await Future.delayed(const Duration(milliseconds: 600));
    _userEmail = email;
    notifyListeners();
  }

  Future<void> signOut() async {
    // TODO: FirebaseAuth signOut
    _userEmail = null;
    notifyListeners();
  }
}
