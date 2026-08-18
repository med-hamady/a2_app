import 'package:intl/intl.dart';

/// Mise en forme des montants et des dates, au format des maquettes.
///
/// Tout passe par ici : le jour où A2 Connect demande un autre séparateur ou
/// une autre devise, il n'y a qu'un fichier à toucher.
abstract final class Fmt {
  /// Devise de facturation : l'ouguiya mauritanien.
  static const currency = 'MRU';

  static final _amount = NumberFormat('#,##0', 'fr_FR');
  static final _amountDecimal = NumberFormat('#,##0.##', 'fr_FR');

  /// « 12 400 MRU ».
  static String money(double value) => '${_amount.format(value)} $currency';

  /// Le montant seul, sans la devise — pour les mises en page où « MRU » est
  /// affiché dans un style différent (écran 07).
  static String amount(double value) => _amount.format(value);

  static String amountPrecise(double value) => _amountDecimal.format(value);

  /// « 05/03/2026 » — format court des listes et des détails.
  static String date(DateTime? d) =>
      d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);

  /// « 15 Mars 2026 » — format long de l'historique des paiements.
  static String dateLong(DateTime? d) {
    if (d == null) return '—';
    final s = DateFormat('d MMMM yyyy', 'fr_FR').format(d);
    // Les maquettes capitalisent le mois (« 15 Mars 2026 »), pas la locale fr.
    return s.replaceFirstMapped(
      RegExp(r'\d+\s(\p{L})', unicode: true),
      (m) => m[0]!.replaceFirst(m[1]!, m[1]!.toUpperCase()),
    );
  }

  /// « 12 Mars 2026 • 14:35 » — en-tête du détail d'un paiement.
  static String dateTimeLong(DateTime? d) =>
      d == null ? '—' : '${dateLong(d)} • ${DateFormat('HH:mm').format(d)}';

  /// « Mars 2026 » — libellé de période, quand l'API n'en fournit pas.
  static String monthYear(DateTime? d) {
    if (d == null) return '—';
    final s = DateFormat('MMMM yyyy', 'fr_FR').format(d);
    return s[0].toUpperCase() + s.substring(1);
  }

  /// « Hier », « 08:30 », « 22 Oct. » — datation relative de la liste de
  /// notifications (écran 11).
  static String relative(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return DateFormat('HH:mm').format(d);
    if (diff == 1) return 'Hier';
    return DateFormat('d MMM', 'fr_FR').format(d);
  }
}
