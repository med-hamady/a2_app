/// Rayons, espacements et durées repris des maquettes.
///
/// Passer par ces constantes plutôt que des nombres en dur : c'est ce qui
/// permettra de recaler toute l'app d'un seul endroit quand le designer
/// livrera les valeurs exactes.
abstract final class AppRadius {
  static const card = 20.0;
  static const button = 14.0;
  static const field = 18.0;
  static const pill = 999.0;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;

  /// Marge latérale de tous les écrans.
  static const screen = 20.0;
}

abstract final class AppDurations {
  /// Latence simulée par l'API mockée — assez longue pour qu'on VOIE les
  /// écrans de chargement pendant le développement.
  static const mockLatency = Duration(milliseconds: 700);

  /// Durée minimale de présentation du splash : le temps que l'animation du
  /// logo se joue en entier, même si la session est résolue plus vite (cache
  /// local quasi instantané). Le routeur ne quitte jamais le splash avant.
  static const splashMinDisplay = Duration(milliseconds: 1900);
}
