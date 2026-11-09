import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Opt-in FCM token registration; no exceptions escape into the home screen.
class PushRegistrationService {
  static final Set<String> _started = {};
  static void register(String uid) {
    if (!_started.add(uid)) return;
    _register(uid);
  }
  static Future<void> _register(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) return;
      Future<void> save(String? token) async {
        if(token==null||token.isEmpty) return;
        await FirebaseFirestore.instance.collection('users').doc(uid)
            .collection('fcmTokens').doc(token).set({'createdAt':FieldValue.serverTimestamp()});
      }
      await save(await messaging.getToken());
      messaging.onTokenRefresh.listen(save);
    } catch (_) {
      // Push setup may be unavailable in emulator or before APNs configuration.
    }
  }
}
