import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// La pastille de statut des maquettes : « PAYÉE », « EN ATTENTE »,
/// « IMPAYÉE », « Actif », « Confirmé »…
///
/// Les constructeurs nommés garantissent qu'un même statut a partout la même
/// couleur — c'est le genre d'écart qui se voit immédiatement à la recette.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
    this.uppercase = false,
    this.dense = false,
  });

  factory StatusPill.invoice(InvoiceStatus status, {bool uppercase = true}) {
    final (fg, bg) = switch (status) {
      InvoiceStatus.paid => (AppColors.success, AppColors.successBg),
      InvoiceStatus.pending => (AppColors.warning, AppColors.warningBg),
      InvoiceStatus.overdue => (AppColors.danger, AppColors.dangerBg),
      InvoiceStatus.unknown => (AppColors.textSecondary, AppColors.neutralBg),
    };
    return StatusPill(
      label: status.label,
      foreground: fg,
      background: bg,
      uppercase: uppercase,
      dense: true,
    );
  }

  factory StatusPill.payment(PaymentStatus status) {
    final (fg, icon) = switch (status) {
      PaymentStatus.confirmed => (AppColors.success, Icons.check_circle_outline),
      PaymentStatus.pending => (AppColors.warning, Icons.schedule),
      PaymentStatus.refused => (AppColors.danger, Icons.cancel_outlined),
      PaymentStatus.unknown => (AppColors.textSecondary, Icons.help_outline),
    };
    // Dans l'historique (écran 07), le statut d'un paiement est affiché sans
    // fond : juste une icône et un libellé colorés.
    return StatusPill(
      label: status.label,
      foreground: fg,
      background: Colors.transparent,
      icon: icon,
      dense: true,
    );
  }

  factory StatusPill.subscription(SubscriptionStatus status) {
    final (fg, bg) = switch (status) {
      SubscriptionStatus.active => (Colors.white, AppColors.primary),
      SubscriptionStatus.suspended => (AppColors.warning, AppColors.warningBg),
      SubscriptionStatus.terminated => (AppColors.danger, AppColors.dangerBg),
      SubscriptionStatus.unknown => (AppColors.textSecondary, AppColors.neutralBg),
    };
    return StatusPill(
      label: status.label,
      foreground: fg,
      background: bg,
      icon: Icons.circle,
    );
  }

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;
  final bool uppercase;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final text = uppercase ? label.toUpperCase() : label;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: background == Colors.transparent ? 0 : (dense ? 10 : 14),
        vertical: dense ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: icon == Icons.circle ? 8 : 16, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  letterSpacing: uppercase ? 0.8 : 0,
                  fontSize: dense ? 12 : 13,
                ),
          ),
        ],
      ),
    );
  }
}
