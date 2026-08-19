import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// Ouvre une feuille modale qui ne déborde jamais : `isScrollControlled`
/// laisse le contenu prendre toute la hauteur qu'il lui faut plutôt que
/// d'être limité à 9/16 de l'écran (c'est ce plafond par défaut qui causait
/// le débordement sur l'écran « Comment fonctionne le blocage »), et le
/// [SingleChildScrollView] absorbe le reste sur les petits écrans ou en
/// accessibilité (texte agrandi). Point de passage unique pour toutes les
/// feuilles de l'app.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(child: builder(sheetContext)),
    ),
  );
}

/// Le canal de contact du service client n'est pas défini par le cahier des
/// charges (numéro, WhatsApp, formulaire ?). En attendant, un pense-bête
/// honnête plutôt qu'un bouton qui ne mène nulle part — réutilisé partout où
/// les maquettes montrent l'icône casque (accueil, détail facture).
void showSupportSheet(BuildContext context) {
  showAppBottomSheet<void>(
    context,
    builder: (_) => const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: InfoBanner(
        text: 'Le canal de contact du service client reste à définir avec '
            'A2 Connect (téléphone, WhatsApp, formulaire).',
      ),
    ),
  );
}

/// Idem pour les préférences de notification (écran 12, bouton « Gérer les
/// préférences » et icône réglages) : pas d'écran de réglages dans le
/// périmètre actuel, on le dit plutôt que de faire semblant.
void showNotificationPreferencesStub(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text(
          'Les préférences de notification restent à définir avec A2 Connect.',
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Libellé de section en capitales espacées : « STATUT DU RÉSEAU »,
/// « DERNIÈRE FACTURE », « RÉSEAUX SOCIAUX ».
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textMuted;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: c),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          text.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
            color: c,
          ),
        ),
      ],
    );
  }
}

/// Le logo officiel A2 Connect.
///
/// Source : https://a2connect.mr — le PNG livré contient le mot-symbole
/// « Connect ⋀2 » ET la signature « Always be connected », exactement comme
/// sur les maquettes.
///
/// ⚠️ C'est un bitmap de 3768 px de large. Demander le **vectoriel (SVG/AI)**
/// à A2 Connect avant la mise en production : c'est le seul moyen d'avoir un
/// rendu net sur tous les écrans sans embarquer une image lourde.
class A2Logo extends StatelessWidget {
  const A2Logo({super.key, this.height = 40})
      : _asset = 'assets/images/logo_a2connect.png';

  /// Variante blanche, pour un fond sombre.
  const A2Logo.white({super.key, this.height = 40})
      : _asset = 'assets/images/logo_a2connect_blanc.png';

  /// Hauteur totale du bloc, signature comprise.
  final double height;

  final String _asset;

  /// Rapport largeur/hauteur du fichier source (3768 × 1877).
  static const _ratio = 3768 / 1877;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _asset,
      height: height,
      width: height * _ratio,
      fit: BoxFit.contain,
      // Le logo porte le nom de la marque : un lecteur d'écran doit l'annoncer.
      semanticLabel: 'A2 Connect',
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Ligne « libellé — valeur » du détail d'une facture (écran 06).
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SectionLabel(label),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const DividerAccent(),
        ],
      ),
    );
  }
}

/// Le petit accent « trait + tick diagonal », signature graphique des
/// maquettes (sous le sous-titre de l'écran 02, en bout de chaque
/// [DetailRow] de l'écran 06). Remplace un simple [Divider] nu.
///
/// Sans [width] : occupe toute la largeur disponible (usage dans une liste).
/// Avec [width] : ligne courte et centrée (usage sous un titre).
class DividerAccent extends StatelessWidget {
  const DividerAccent({super.key, this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: width == null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (width == null)
          const Expanded(child: Divider())
        else
          SizedBox(
            width: width! - 18,
            child: const Divider(),
          ),
        const SizedBox(width: 6),
        CustomPaint(size: const Size(11, 11), painter: _TickPainter()),
      ],
    );
    return width == null ? row : SizedBox(width: width, child: row);
  }
}

class _TickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.15, 0), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bandeau d'information neutre (avertissements, précisions).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.color = AppColors.textSecondary,
    this.background = AppColors.surfaceMuted,
  });

  final String text;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
