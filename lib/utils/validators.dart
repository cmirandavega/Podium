/// Form validators. Each returns an error message, or null when valid.
class Validators {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email.';
    if (!_emailPattern.hasMatch(text)) return 'Enter a valid email address.';
    return null;
  }

  /// Registration password rules.
  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter a password.';
    if (text.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  /// Login only checks that something was typed; Firebase checks the rest.
  static String? password(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    return null;
  }

  static String? username(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Choose a username.';
    if (!_usernamePattern.hasMatch(text)) {
      return 'Use 3 to 20 letters, numbers, or underscores.';
    }
    return null;
  }

  static String? displayName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your name.';
    if (text.length > 40) return 'Keep it under 40 characters.';
    return null;
  }

  static String? Function(String?) matches(String Function() original) {
    return (value) => value != original() ? 'Passwords do not match.' : null;
  }
}
