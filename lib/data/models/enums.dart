// Statuts métier de l'application.
//
// Chaque enum expose `fromApi` : c'est le SEUL endroit à toucher quand on
// branchera la vraie API et qu'on connaîtra ses libellés exacts. Une valeur
// inconnue ne fait jamais planter l'écran — elle retombe sur un cas neutre.

enum SubscriptionStatus {
  active,
  suspended,
  terminated,
  unknown;

  static SubscriptionStatus fromApi(String? value) => switch (value) {
        'active' || 'actif' => SubscriptionStatus.active,
        'suspended' || 'suspendu' => SubscriptionStatus.suspended,
        'terminated' || 'resilie' => SubscriptionStatus.terminated,
        _ => SubscriptionStatus.unknown,
      };

  String get label => switch (this) {
        SubscriptionStatus.active => 'Actif',
        SubscriptionStatus.suspended => 'Suspendu',
        SubscriptionStatus.terminated => 'Résilié',
        SubscriptionStatus.unknown => 'Inconnu',
      };
}

enum InvoiceStatus {
  paid,
  pending,
  overdue,
  unknown;

  static InvoiceStatus fromApi(String? value) => switch (value) {
        'paid' || 'payee' => InvoiceStatus.paid,
        'pending' || 'en_attente' => InvoiceStatus.pending,
        'overdue' || 'impayee' => InvoiceStatus.overdue,
        _ => InvoiceStatus.unknown,
      };

  String get label => switch (this) {
        InvoiceStatus.paid => 'Payée',
        InvoiceStatus.pending => 'En attente',
        InvoiceStatus.overdue => 'Impayée',
        InvoiceStatus.unknown => 'Inconnu',
      };
}

enum PaymentStatus {
  confirmed,
  pending,
  refused,
  unknown;

  static PaymentStatus fromApi(String? value) => switch (value) {
        'confirmed' || 'confirme' || 'success' => PaymentStatus.confirmed,
        'pending' || 'en_attente' => PaymentStatus.pending,
        'refused' || 'refuse' || 'failed' => PaymentStatus.refused,
        _ => PaymentStatus.unknown,
      };

  String get label => switch (this) {
        PaymentStatus.confirmed => 'Confirmé',
        PaymentStatus.pending => 'En attente',
        PaymentStatus.refused => 'Refusé',
        PaymentStatus.unknown => 'Inconnu',
      };

  /// Un paiement en attente est le SEUL cas où l'app doit continuer à
  /// interroger le backend après avoir quitté l'écran de confirmation.
  bool get isFinal => this != PaymentStatus.pending;
}

/// État d'un maillon de la chaîne « CLIENT — MODEM — INTERNET » (écran 04).
enum LinkState {
  up,
  degraded,
  down,
  unknown;

  static LinkState fromApi(String? value) => switch (value) {
        'up' || 'ok' => LinkState.up,
        'degraded' => LinkState.degraded,
        'down' || 'ko' => LinkState.down,
        _ => LinkState.unknown,
      };
}

/// Où en est l'ordre de blocage d'une plateforme.
///
/// `pending` existe parce que le blocage est appliqué sur l'équipement du
/// client : il n'est ni instantané ni garanti si la box est éteinte.
enum BlockState {
  blocked,
  allowed,
  pending,
  failed;

  static BlockState fromApi(String? value) => switch (value) {
        'blocked' => BlockState.blocked,
        'pending' => BlockState.pending,
        'failed' => BlockState.failed,
        _ => BlockState.allowed,
      };
}

enum NotificationKind {
  paymentSuccess,
  paymentFailed,
  newInvoice,
  maintenance,
  accessRestricted,
  info;

  static NotificationKind fromApi(String? value) => switch (value) {
        'payment_success' => NotificationKind.paymentSuccess,
        'payment_failed' => NotificationKind.paymentFailed,
        'new_invoice' => NotificationKind.newInvoice,
        'maintenance' => NotificationKind.maintenance,
        'access_restricted' => NotificationKind.accessRestricted,
        _ => NotificationKind.info,
      };
}
