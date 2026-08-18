import 'package:flutter/material.dart';

/// Palette de la marque A2 Connect.
///
/// Les valeurs ne sont pas approximatives : [brand] et [sage] sont
/// échantillonnées dans le logo officiel (a2connect.mr), les autres dans les
/// maquettes PNG du dossier `Archive/`.
abstract final class AppColors {
  // ── Fonds ────────────────────────────────────────────────────────────────
  /// Fond général de l'application : le vert d'eau très clair des maquettes.
  static const background = Color(0xFFF2FCFB);

  /// Carte blanche mise en avant (facture en cours, bloc « total payé »).
  static const surface = Color(0xFFFFFFFF);

  /// Carte secondaire, légèrement teintée (facture payée, champs de saisie).
  static const surfaceMuted = Color(0xFFECF6F5);

  // ── Marque ───────────────────────────────────────────────────────────────
  /// Le vert-noir des boutons principaux, relevé dans les maquettes.
  ///
  /// Volontairement plus sombre que [brand] : le logo doit rester lisible sur
  /// un fond clair, un bouton plein a besoin de plus de contraste.
  static const primary = Color(0xFF1A2121);

  /// Le gris-vert EXACT du chevron du logo officiel.
  static const brand = Color(0xFF2E3838);

  /// Le vert sauge EXACT du mot « Connect » dans le logo officiel.
  static const sage = Color(0xFFA6B8AE);

  // ── Texte ────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF101815);
  static const textSecondary = Color(0xFF6B7B75);

  /// Libellés de section en capitales espacées (« STATUT DU RÉSEAU »).
  static const textMuted = Color(0xFF8B9A94);

  static const border = Color(0xFFDCE6E5);

  // ── États ────────────────────────────────────────────────────────────────
  // Chaque état a sa couleur de texte et son fond de pastille.
  static const success = Color(0xFF1E8449);
  static const successBg = Color(0xFFE3F2E8);

  static const warning = Color(0xFFA9781F);
  static const warningBg = Color(0xFFF7EBD7);

  static const danger = Color(0xFFC0392B);
  static const dangerBg = Color(0xFFFBE4E4);

  static const neutralBg = Color(0xFFE1EBEA);
}
