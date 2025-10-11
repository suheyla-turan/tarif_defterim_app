import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime createdAt;
  final bool emailVerified;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    required this.createdAt,
    required this.emailVerified,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'createdAt': Timestamp.fromDate(createdAt),
        'emailVerified': emailVerified,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        uid: map['uid'] as String,
        email: map['email'] as String,
        displayName: map['displayName'] as String?,
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        emailVerified: (map['emailVerified'] as bool?) ?? false,
      );
}
