import '../models/models.dart';

/// Le contrat que l'application attend du backend — et rien d'autre.
///
/// C'est la pièce centrale du montage : toute l'app (écrans, providers, tests)
/// ne parle QUE de cette interface. Il existe deux implémentations,
/// interchangeables sans toucher une ligne d'interface :
///
///  - [MockA2Api]   : données factices, utilisée tant que la doc de l'API
///                    réelle n'est pas disponible.
///  - [RemoteA2Api] : les vrais appels HTTP.
///
/// Chaque méthode correspond à une des sept API annoncées par A2 Connect.
/// Quand la documentation arrivera, seul `RemoteA2Api` changera ; les écrans
/// resteront tels quels.
abstract interface class A2Api {
  // ── Authentification ─────────────────────────────────────────────────────

  /// Connexion par numéro de téléphone + identifiant client (écran 03).
  ///
  /// Lève une [ApiException] de type `invalidCredentials` si le couple est
  /// refusé.
  Future<Session> login({
    required String phone,
    required String clientId,
  });

  Future<void> logout();

  // ── Accueil ──────────────────────────────────────────────────────────────

  Future<Subscription> fetchSubscription();

  /// Le solde / montant dû.
  Future<Balance> fetchBalance();

  /// L'état du réseau : chaîne client — modem — internet.
  Future<NetworkStatus> fetchNetworkStatus();

  // ── Factures ─────────────────────────────────────────────────────────────

  /// Liste des factures, la plus récente en premier.
  ///
  /// [page] commence à 1. Si l'API réelle ne pagine pas, l'implémentation
  /// ignore simplement le paramètre.
  Future<List<Invoice>> fetchInvoices({int page = 1});

  Future<Invoice> fetchInvoice(String invoiceId);

  // ── Paiements ────────────────────────────────────────────────────────────

  Future<List<Payment>> fetchPayments({int page = 1});

  Future<Payment> fetchPayment(String paymentId);

  /// Les moyens de paiement proposés au client (Bankily, Masrivi, Sedad…).
  ///
  /// Servi par l'API et non codé en dur : ajouter un opérateur ne doit pas
  /// imposer une mise à jour de l'app sur les stores.
  Future<List<PaymentMethod>> fetchPaymentMethods();

  /// Déclenche un paiement.
  ///
  /// [idempotencyKey] est généré par l'app AVANT l'appel et rejoué à
  /// l'identique en cas de reprise : c'est ce qui empêche un double débit
  /// quand le client tape deux fois ou perd le réseau après avoir confirmé.
  ///
  /// La réponse peut être `PaymentStatus.pending` : le paiement n'est alors
  /// pas terminé, il faut suivre son évolution avec [fetchPayment].
  Future<Payment> createPayment({
    required double amount,
    required String methodCode,
    required String idempotencyKey,
    String? invoiceId,
  });

  // ── Blocage des plateformes ──────────────────────────────────────────────

  /// Le catalogue des plateformes blocables ET leur état actuel.
  Future<List<BlockablePlatform>> fetchPlatforms();

  /// Bloque ou débloque une plateforme.
  ///
  /// Le retour peut être `BlockState.pending` : l'ordre est enregistré mais
  /// pas encore appliqué sur l'équipement du client (box éteinte, hors ligne).
  Future<BlockablePlatform> setPlatformBlocked({
    required String key,
    required bool blocked,
  });

  // ── Notifications ────────────────────────────────────────────────────────

  Future<List<AppNotification>> fetchNotifications();

  Future<void> markNotificationRead(String id);

  Future<void> deleteNotification(String id);
}
