/// Configuration d'exécution de l'application.
///
/// Toutes les valeurs sont surchargeables au lancement sans recompiler :
///
/// ```
/// flutter run --dart-define=USE_MOCK=false \
///             --dart-define=API_BASE_URL=https://api.a2connect.mr/v1
/// ```
abstract final class AppConfig {
  /// Tant que la documentation de l'API n'est pas disponible, l'app tourne
  /// sur les données factices. Passer à `false` bascule sur `RemoteA2Api`
  /// sans qu'aucun écran ne change.
  static const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);

  /// Racine de l'API. À renseigner quand A2 Connect l'aura communiquée.
  ///
  /// ⚠️ Doit être un nom de domaine avec un certificat TLS reconnu. Un
  /// certificat auto-signé impose de désactiver la vérification, ce qui est
  /// refusé à la publication sur les stores et ouvre la porte à
  /// l'interception.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.a2connect.example/v1',
  );

  /// Le paiement attend la réponse d'un opérateur de mobile money : la
  /// latence normale se compte en dizaines de secondes, pas en millisecondes.
  static const paymentTimeout = Duration(seconds: 90);

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 30);
}
