/// Form validators shared across auth and data-entry screens.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[\w\.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$');
  static final RegExp _tp = RegExp(r'^TP\d{6}$', caseSensitive: false);
  static final RegExp _phone = RegExp(r'^\+?[0-9\s\-]{9,15}$');

  static String? required(String? v, [String field = 'This field']) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email address is required';
    if (!_email.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!v.contains(RegExp(r'[A-Za-z]')) || !v.contains(RegExp(r'\d'))) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != original) return 'Passwords do not match';
    return null;
  }

  /// APU TP numbers look like TP087014.
  static String? studentId(String? v) {
    if (v == null || v.trim().isEmpty) return 'Student ID / TP number is required';
    if (!_tp.hasMatch(v.trim())) return 'Use the format TP012345';
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Contact number is required';
    if (!_phone.hasMatch(v.trim())) return 'Enter a valid phone number';
    return null;
  }

  static String? positiveInt(String? v, [String field = 'Value']) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    final n = int.tryParse(v.trim());
    if (n == null || n <= 0) return '$field must be a whole number above 0';
    return null;
  }

  static String? nonNegativeInt(String? v, [String field = 'Value']) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) return '$field must be 0 or more';
    return null;
  }

  static String? money(String? v, [String field = 'Amount']) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    final n = double.tryParse(v.trim());
    if (n == null || n < 0) return '$field must be a valid amount';
    return null;
  }
}
