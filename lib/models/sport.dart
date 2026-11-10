import 'package:cloud_firestore/cloud_firestore.dart';

/// A sport Podium supports, stored at sports/{name} (Use Case 2).
class Sport {
  const Sport({required this.name, required this.apiCode, required this.isActive});

  final String name; // "NFL", "NBA", "MLB", "Soccer"
  final String apiCode;
  final bool isActive;

  /// Used when the sports collection is empty, so league creation still works.
  static const defaults = [
    Sport(name: 'NFL', apiCode: 'american-football', isActive: true),
    Sport(name: 'NBA', apiCode: 'basketball', isActive: true),
    Sport(name: 'MLB', apiCode: 'baseball', isActive: true),
    Sport(name: 'Soccer', apiCode: 'football', isActive: true),
  ];

  factory Sport.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Sport(
      name: data['name'] as String? ?? doc.id,
      apiCode: data['apiCode'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}
