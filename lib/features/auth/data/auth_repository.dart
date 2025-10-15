import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    String? firstName,   // ✅ yeni
    String? lastName,    // ✅ yeni
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Display name'i "İsim Soyisim" olarak ayarla (varsa)
    final fullName = [firstName, lastName]
        .where((e) => (e ?? '').trim().isNotEmpty)
        .join(' ')
        .trim();
    if (fullName.isNotEmpty) {
      await cred.user!.updateDisplayName(fullName);
    }

    // Firestore profil belgesi
    final appUser = AppUser(
      uid: cred.user!.uid,
      email: cred.user!.email!,
      firstName: firstName,
      lastName: lastName,
      displayName: fullName.isEmpty ? null : fullName,
      country: null,
      city: null,
      createdAt: DateTime.now(),
      emailVerified: cred.user!.emailVerified,
    );

    await _db
        .collection('users')
        .doc(appUser.uid)
        .set(appUser.toMap(), SetOptions(merge: true));

    // E-posta doğrulama (opsiyonel ama önerilir)
    if (!cred.user!.emailVerified) {
      await cred.user!.sendEmailVerification();
    }

    return appUser;
  }

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final docRef = _db.collection('users').doc(cred.user!.uid);
    final snap = await docRef.get();

    if (!snap.exists) {
      // Doküman yoksa, Firebase displayName'den isim/soyisim ayırıp minimal profil oluştur.
      final dn = cred.user!.displayName ?? '';
      final parts = dn.trim().split(RegExp(r'\s+'));
      String? firstName;
      String? lastName;
      if (parts.isNotEmpty && parts.first.isNotEmpty) {
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.sublist(1).join(' ').trim().isEmpty
              ? null
              : parts.sublist(1).join(' ').trim();
        }
      }

      final appUser = AppUser(
        uid: cred.user!.uid,
        email: cred.user!.email!,
        firstName: firstName,
        lastName: lastName,
        displayName: dn.isEmpty ? null : dn,
        country: null,
        city: null,
        createdAt: DateTime.now(),
        emailVerified: cred.user!.emailVerified,
      );
      await docRef.set(appUser.toMap(), SetOptions(merge: true));
      return appUser;
    }

    return AppUser.fromMap(snap.data()!);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<AppUser?> currentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snap = await _db.collection('users').doc(user.uid).get();
    if (!snap.exists) return null;
    return AppUser.fromMap(snap.data()!);
  }
}

