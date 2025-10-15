import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String? firstName;   // ✅
  final String? lastName;    // ✅
  final String? displayName; // opsiyonel (tam ad)
  final String? country;
  final String? city;
  final DateTime createdAt;
  final bool emailVerified;

  AppUser({
    required this.uid,
    required this.email,
    this.firstName,
    this.lastName,
    this.displayName,
    this.country,
    this.city,
    required this.createdAt,
    required this.emailVerified,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'displayName': displayName,
        'country': country,
        'city': city,
        'createdAt': Timestamp.fromDate(createdAt),
        'emailVerified': emailVerified,
      };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        uid: m['uid'] as String,
        email: m['email'] as String,
        firstName: m['firstName'] as String?,
        lastName: m['lastName'] as String?,
        displayName: m['displayName'] as String?,
        country: m['country'] as String?,
        city: m['city'] as String?,
        createdAt: (m['createdAt'] as Timestamp).toDate(),
        emailVerified: (m['emailVerified'] as bool?) ?? false,
      );
}
