import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Error with a message that is safe to show to the user.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Registration, login, logout, and password reset.
/// Firebase Authentication keeps the session; Firestore stores the profile.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const _usernameTaken = 'That username is taken. Try another one.';

  /// Emits the signed-in user, or null when signed out. Used for session handling.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final name = username.trim().toLowerCase();

    // Quick check so most duplicate usernames are caught before an account is created.
    final bool alreadyTaken;
    try {
      alreadyTaken = (await _db.collection('usernames').doc(name).get()).exists;
    } on FirebaseException {
      throw AuthException('No connection. Check your internet and try again.');
    }
    if (alreadyTaken) throw AuthException(_usernameTaken);

    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }

    final uid = cred.user!.uid;
    var taken = false;

    try {
      // Claim the username and create the profile together, so two people
      // can never end up with the same username.
      await _db.runTransaction((tx) async {
        final nameRef = _db.collection('usernames').doc(name);
        final snapshot = await tx.get(nameRef);
        if (snapshot.exists) {
          taken = true;
          return;
        }
        tx.set(nameRef, {'uid': uid});
        tx.set(_db.collection('users').doc(uid), {
          'username': name,
          'email': email.trim(),
          'displayName': displayName.trim(),
          'role': 'user',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {
      await _deleteQuietly(cred.user);
      throw AuthException('Account setup failed. Check your connection and try again.');
    }

    if (taken) {
      await _deleteQuietly(cred.user);
      throw AuthException(_usernameTaken);
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Sends a reset email. Unknown emails succeed silently so the screen
  /// doesn't reveal which emails have accounts.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      throw AuthException(_messageFor(e));
    }
  }

  Future<void> _deleteQuietly(User? user) async {
    try {
      await user?.delete();
    } catch (_) {
      await _auth.signOut();
    }
  }

  static String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with that email already exists. Log in instead.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'weak-password':
        return 'Choose a stronger password with at least 8 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      case 'operation-not-allowed':
        return 'Email sign-in is not enabled for this Firebase project.';
      default:
        return 'Something went wrong. Try again.';
    }
  }
}
