import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/models/app_user.dart';

// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

// FirebaseAuth stream -> oturum dinleme
final firebaseAuthStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

// ---- Controller & State ----
class AuthState {
  final bool loading;
  final String? error;
  final AppUser? user;

  const AuthState({this.loading = false, this.error, this.user});

  AuthState copyWith({bool? loading, String? error, AppUser? user}) => AuthState(
        loading: loading ?? this.loading,
        error: error,
        user: user ?? this.user,
      );
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  AuthController(this._repo) : super(const AuthState());

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final u = await _repo.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = AuthState(loading: false, user: u);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(loading: false, error: _mapAuthCode(e.code));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Bir hata oluştu.');
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final u = await _repo.signInWithEmail(email: email, password: password);
      state = AuthState(loading: false, user: u);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(loading: false, error: _mapAuthCode(e.code));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Bir hata oluştu.');
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState();
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _repo.sendPasswordReset(email);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(error: _mapAuthCode(e.code));
    }
  }

  String _mapAuthCode(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu e-posta zaten kayıtlı.';
      case 'invalid-email':
        return 'Geçersiz e-posta.';
      case 'weak-password':
        return 'Şifre çok zayıf.';
      case 'user-not-found':
        return 'Kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Şifre hatalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Biraz bekleyin.';
      default:
        return 'Hata: $code';
    }
  }
}
