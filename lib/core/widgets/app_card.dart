import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// La carte arrondie qu'on retrouve sur tous les écrans des maquettes.
///
/// Deux variantes : [AppCard] (fond teinté, cas courant) et
/// [AppCard.highlighted] (fond blanc + liseré sombre, pour l'élément mis en
/// avant — la facture en cours, le total payé).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surfaceMuted,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
  });

  /// Carte mise en avant : blanche, cerclée de sombre.
  const AppCard.highlighted({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  })  : color = AppColors.surface,
        borderColor = AppColors.primary,
        borderWidth = 1.5;

  /// Carte d'alerte : fond rosé, liseré rouge (facture impayée).
  const AppCard.danger({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  })  : color = AppColors.dangerBg,
        borderColor = AppColors.danger,
        borderWidth = 1.5;

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: borderColor ?? AppColors.border,
              width: borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
