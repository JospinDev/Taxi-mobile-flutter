import 'package:intl/intl.dart';
import 'package:characters/characters.dart';

/// Display helpers (dates, names, sizes, currency) — French locale.
class Formatters {
  const Formatters._();

  static final NumberFormat _money = NumberFormat.decimalPattern('fr_FR');

  static String initials(String? first, String? last, {String? username}) {
    final f = (first ?? '').trim();
    final l = (last ?? '').trim();
    if (f.isEmpty && l.isEmpty) {
      final u = (username ?? '').trim();
      return u.isEmpty ? '?' : u.characters.first.toUpperCase();
    }
    final buffer = StringBuffer();
    if (f.isNotEmpty) buffer.write(f.characters.first.toUpperCase());
    if (l.isNotEmpty) buffer.write(l.characters.first.toUpperCase());
    return buffer.toString();
  }

  static String fullName(String? first, String? last, {String? fallback}) {
    final name = '${first ?? ''} ${last ?? ''}'.trim();
    return name.isEmpty ? (fallback ?? '—') : name;
  }

  static String date(String? raw, {String pattern = 'dd/MM/yyyy'}) {
    if (raw == null || raw.isEmpty) return '—';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return DateFormat(pattern).format(d.toLocal());
  }

  static String dateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
  }

  static String fileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  /// Amount in Burundian Francs (FBu).
  static String money(num amount) => '${_money.format(amount)} FBu';

  static String rating(double? value) =>
      value == null ? '—' : value.toStringAsFixed(1);

  /// Short relative label, e.g. "il y a 5 min". Falls back to formatted date.
  static String timeAgo(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return raw;
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return DateFormat('dd/MM/yyyy').format(d);
  }

  static String yearRange(int? from, int? to) =>
      (from == null || to == null) ? '—' : '$from – $to';
}
