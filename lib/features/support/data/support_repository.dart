import 'package:cloud_firestore/cloud_firestore.dart';

class SupportRepository {
  final FirebaseFirestore _db;
  SupportRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _supportCol => _db.collection('support_tickets');
  CollectionReference<Map<String, dynamic>> get _feedbackCol => _db.collection('feedback');

  /// Destek mesajı gönder
  Future<String> submitSupportTicket({
    required String userId,
    required String userEmail,
    required String subject,
    required String message,
  }) async {
    final doc = await _supportCol.add({
      'userId': userId,
      'userEmail': userEmail,
      'subject': subject,
      'message': message,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Geribildirim gönder
  Future<String> submitFeedback({
    required String userId,
    required String userEmail,
    required String feedback,
    int? rating,
  }) async {
    final doc = await _feedbackCol.add({
      'userId': userId,
      'userEmail': userEmail,
      'feedback': feedback,
      'rating': rating,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Kullanıcının destek mesajlarını getir (admin paneli için)
  Stream<List<Map<String, dynamic>>> watchUserSupportTickets(String userId) {
    return _supportCol
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Tüm destek mesajlarını getir (admin paneli için)
  Stream<List<Map<String, dynamic>>> watchAllSupportTickets() {
    return _supportCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Tüm geribildirimleri getir (admin paneli için)
  Stream<List<Map<String, dynamic>>> watchAllFeedback() {
    return _feedbackCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList());
  }
}

