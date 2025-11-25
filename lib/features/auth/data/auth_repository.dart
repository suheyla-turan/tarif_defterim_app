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
    // DEBUG: Giriş isteğini logla
    // Not: Parolayı asla loglama!
    // Bu loglar sadece geliştirme sürecinde yardımcı olması için.
    // Üründe bırakacaksan debugPrint kullanıp gerektiğinde filtreleyebilirsin.
    print('DEBUG[AuthRepository]: signInWithEmail çağrıldı -> email=$email');

    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    print(
        'DEBUG[AuthRepository]: FirebaseAuth signInWithEmailAndPassword döndü -> uid=${cred.user?.uid}, email=${cred.user?.email}');

    final docRef = _db.collection('users').doc(cred.user!.uid);
    print(
        'DEBUG[AuthRepository]: Firestore kullanıcı dokümanı okunuyor -> docId=${cred.user!.uid}');
    final snap = await docRef.get();
    print(
        'DEBUG[AuthRepository]: Firestore doküman var mı? -> exists=${snap.exists}');

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

      print(
          'DEBUG[AuthRepository]: Firestore dokümanı yok, yeni minimal profil oluşturulacak.');

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
      print(
          'DEBUG[AuthRepository]: Yeni kullanıcı profili Firestore\'a yazıldı -> uid=${appUser.uid}');
      return appUser;
    }

    final fromDb = AppUser.fromMap(snap.data()!);
    print(
        'DEBUG[AuthRepository]: Var olan kullanıcı profili Firestore\'dan yüklendi -> uid=${fromDb.uid}, email=${fromDb.email}');
    return fromDb;
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

