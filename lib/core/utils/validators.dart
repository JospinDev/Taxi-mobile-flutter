/// Form validation rules shared by all forms (client & driver registration,
/// profile editing, vehicle form...).
class Validators {
  const Validators._();

  static final RegExp _email = RegExp(
    r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$",
  );
  // Accepts local formats and international numbers, e.g. +25761234567 / 61234567
  static final RegExp _phone = RegExp(r'^\+?[0-9]{8,15}$');
  // Django-friendly password: ≥8 chars, at least one letter and one digit.
  static final RegExp _passwordStrong = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d).{8,}$',
  );
  static final RegExp _license = RegExp(r'^[A-Za-z0-9\-]{3,30}$');

  static String? required(String? value, [String label = 'Ce champ']) {
    if (value == null || value.trim().isEmpty) return '$label est requis.';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email requis.';
    if (!_email.hasMatch(value.trim())) return 'Format d\'email invalide.';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Téléphone requis.';
    if (!_phone.hasMatch(value.trim().replaceAll(' ', ''))) {
      return 'Numéro invalide (ex: +25761234567).';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Mot de passe requis.';
    if (!_passwordStrong.hasMatch(value)) {
      return '8 caractères min. avec au moins une lettre et un chiffre.';
    }
    return null;
  }

  static String? passwordConfirm(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirmation requise.';
    if (value != password) return 'Les mots de passe ne correspondent pas.';
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nom d\'utilisateur requis.';
    }
    if (value.trim().length < 3) return 'Au moins 3 caractères.';
    if (value.trim().contains(' ')) return 'Sans espace.';
    return null;
  }

  static String? licenseNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'N° de permis requis.';
    if (!_license.hasMatch(value.trim())) {
      return 'Format invalide (ex: PERM-2026-001).';
    }
    return null;
  }

  static String? year(String? value, {int min = 1980, int max = 2100}) {
    if (value == null || value.trim().isEmpty) return 'Année requise.';
    final y = int.tryParse(value.trim());
    if (y == null || y < min || y > max) return 'Année invalide ($min–$max).';
    return null;
  }

  static String? seats(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nombre de sièges requis.';
    }
    final s = int.tryParse(value.trim());
    if (s == null || s < 1 || s > 12) return 'Entre 1 et 12.';
    return null;
  }

  static String? plateNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Plaque requise.';
    if (value.trim().length < 3) return 'Plaque trop courte.';
    return null;
  }

  static String? compose(List<String?> errors) {
    for (final e in errors) {
      if (e != null) return e;
    }
    return null;
  }
}
