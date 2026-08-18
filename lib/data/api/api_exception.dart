/// Erreur normalisée présentée à l'interface.
///
/// Tout ce qui sort de la couche réseau — timeout, 401, 500, JSON illisible —
/// arrive aux écrans sous cette forme unique, avec un message déjà rédigé en
/// français pour l'abonné. Les écrans n'ont donc jamais à connaître Dio ni les
/// codes HTTP.
class ApiException implements Exception {
  const ApiException(this.message, {this.kind = ApiErrorKind.unknown, this.statusCode});

  final String message;
  final ApiErrorKind kind;
  final int? statusCode;

  /// Une session expirée doit déconnecter, pas afficher une erreur rouge.
  bool get isAuthError => kind == ApiErrorKind.unauthorized;

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}

enum ApiErrorKind {
  /// Pas de réseau, ou serveur injoignable.
  network,

  /// Le serveur a mis trop de temps.
  timeout,

  /// Jeton absent, invalide ou expiré → retour à l'écran de connexion.
  unauthorized,

  /// Identifiants refusés à la connexion.
  invalidCredentials,

  /// Ressource introuvable.
  notFound,

  /// Erreur côté serveur.
  server,

  unknown,
}
