import '../../core/format/formatters.dart';
import '../../core/theme/app_dimens.dart';
import '../models/models.dart';
import 'a2_api.dart';
import 'api_exception.dart';

/// Quel client on simule. Les deux cas changent l'accueil du tout au tout,
/// et ce sont les deux qu'il faut pouvoir montrer au client.
enum MockScenario {
  /// Abonné à jour : « 0 MRU (À jour) », aucune facture impayée.
  upToDate,

  /// Abonné avec des impayés : c'est le cas des maquettes 05 et 07.
  hasUnpaid,
}

/// Implémentation factice de [A2Api].
///
/// Les données reproduisent celles des maquettes du dossier `Archive/`
/// (montants, références, opérateurs, statuts), avec des dates calculées
/// relativement à aujourd'hui pour que l'app reste crédible quelle que soit la
/// date d'exécution.
///
/// Elle sert à développer et à démontrer toute l'interface sans dépendre du
/// backend. Elle disparaît le jour où [RemoteA2Api] est branchée — aucun écran
/// n'a besoin d'être modifié.
class MockA2Api implements A2Api {
  MockA2Api({this.scenario = MockScenario.hasUnpaid});

  final MockScenario scenario;

  bool _loggedIn = false;

  /// État mutable en mémoire : c'est ce qui rend la démo interactive
  /// (bloquer TikTok, payer une facture, supprimer une notification).
  late final List<Invoice> _invoices = _seedInvoices();
  late final List<Payment> _payments = _seedPayments();
  late final List<BlockablePlatform> _platforms = _seedPlatforms();
  late final List<AppNotification> _notifications = _seedNotifications();

  Future<T> _delay<T>(T value) =>
      Future.delayed(AppDurations.mockLatency, () => value);

  void _requireSession() {
    if (!_loggedIn) {
      throw const ApiException(
        'Votre session a expiré. Reconnectez-vous.',
        kind: ApiErrorKind.unauthorized,
      );
    }
  }

  // ── Authentification ─────────────────────────────────────────────────────

  @override
  Future<Session> login({required String phone, required String clientId}) async {
    await Future.delayed(AppDurations.mockLatency);
    // Jeu d'essai : n'importe quel numéro à 8 chiffres passe, sauf le code
    // « 0000 » qui sert à démontrer l'écran d'erreur de connexion.
    if (clientId.trim() == '0000') {
      throw const ApiException(
        'Numéro de téléphone ou identifiant client incorrect.',
        kind: ApiErrorKind.invalidCredentials,
      );
    }
    _loggedIn = true;
    return Session(
      token: 'mock-token',
      clientId: clientId.trim().isEmpty ? '87654321' : clientId.trim(),
      firstName: 'Ahmed',
    );
  }

  @override
  Future<void> logout() async {
    _loggedIn = false;
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // ── Accueil ──────────────────────────────────────────────────────────────

  @override
  Future<Subscription> fetchSubscription() {
    _requireSession();
    final now = DateTime.now();
    return _delay(Subscription(
      planName: 'Fibre Pro 500M',
      monthlyPrice: 1500,
      renewalDate: DateTime(now.year, now.month + 1, 28),
      speedLabel: '500 Mbps',
      quotaLabel: 'Illimité',
      status: SubscriptionStatus.active,
    ));
  }

  @override
  Future<Balance> fetchBalance() {
    _requireSession();
    final due = _invoices
        .where((i) => i.status != InvoiceStatus.paid)
        .fold<double>(0, (sum, i) => sum + i.amount);
    return _delay(Balance(amountDue: due, isUpToDate: due == 0));
  }

  @override
  Future<NetworkStatus> fetchNetworkStatus() {
    _requireSession();
    return _delay(const NetworkStatus(
      client: LinkState.up,
      modem: LinkState.up,
      internet: LinkState.up,
      label: 'Connexion établie',
    ));
  }

  // ── Factures ─────────────────────────────────────────────────────────────

  @override
  Future<List<Invoice>> fetchInvoices({int page = 1}) {
    _requireSession();
    // Le mock ne pagine pas : tout tient sur la première page.
    return _delay(page == 1 ? List<Invoice>.from(_invoices) : <Invoice>[]);
  }

  @override
  Future<Invoice> fetchInvoice(String invoiceId) {
    _requireSession();
    final found = _invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (found == null) {
      throw const ApiException('Facture introuvable.', kind: ApiErrorKind.notFound);
    }
    return _delay(found);
  }

  // ── Paiements ────────────────────────────────────────────────────────────

  @override
  Future<List<Payment>> fetchPayments({int page = 1}) {
    _requireSession();
    return _delay(page == 1 ? List<Payment>.from(_payments) : <Payment>[]);
  }

  @override
  Future<Payment> fetchPayment(String paymentId) {
    _requireSession();
    final found = _payments.where((p) => p.id == paymentId).firstOrNull;
    if (found == null) {
      throw const ApiException('Paiement introuvable.', kind: ApiErrorKind.notFound);
    }
    return _delay(found);
  }

  @override
  Future<List<PaymentMethod>> fetchPaymentMethods() {
    _requireSession();
    return _delay(const [
      PaymentMethod(code: 'bankily', label: 'Bankily'),
      PaymentMethod(code: 'masrivi', label: 'Masrivi'),
      PaymentMethod(code: 'sedad', label: 'Sedad'),
    ]);
  }

  /// Les clés d'idempotence déjà vues, pour démontrer la protection contre le
  /// double débit : rejouer la même clé renvoie le paiement d'origine.
  final Map<String, Payment> _byIdempotencyKey = {};

  @override
  Future<Payment> createPayment({
    required double amount,
    required String methodCode,
    required String idempotencyKey,
    String? invoiceId,
  }) async {
    _requireSession();
    await Future.delayed(const Duration(milliseconds: 1400));

    final existing = _byIdempotencyKey[idempotencyKey];
    if (existing != null) return existing;

    final invoice = _invoices.where((i) => i.id == invoiceId).firstOrNull;
    final method = (await fetchPaymentMethods())
            .where((m) => m.code == methodCode)
            .firstOrNull
            ?.label ??
        methodCode;

    // Le mock confirme immédiatement. Le jour où l'API réelle répondra
    // « en attente », l'écran de suivi est déjà prévu pour ce cas.
    final payment = Payment(
      id: 'p-${DateTime.now().millisecondsSinceEpoch}',
      reference: 'PAY-${99300 + _payments.length}',
      date: DateTime.now(),
      amount: amount,
      status: PaymentStatus.confirmed,
      method: method,
      invoiceId: invoiceId,
      invoicePeriodLabel: invoice?.periodLabel,
    );

    _byIdempotencyKey[idempotencyKey] = payment;
    _payments.insert(0, payment);

    // La facture réglée bascule en « payée » : c'est ce qui fait bouger le
    // solde de l'accueil au retour de l'écran de paiement.
    if (invoice != null) {
      final index = _invoices.indexOf(invoice);
      _invoices[index] = Invoice(
        id: invoice.id,
        reference: invoice.reference,
        periodLabel: invoice.periodLabel,
        issueDate: invoice.issueDate,
        dueDate: invoice.dueDate,
        amount: invoice.amount,
        status: InvoiceStatus.paid,
        paidAt: DateTime.now(),
        pdfUrl: invoice.pdfUrl,
      );
    }

    _notifications.insert(
      0,
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        kind: NotificationKind.paymentSuccess,
        title: 'Paiement validé',
        body: 'Votre paiement de ${Fmt.money(amount)} a été traité avec succès.',
        date: DateTime.now(),
        read: false,
        relatedType: 'payment',
        relatedId: payment.id,
      ),
    );

    return payment;
  }

  // ── Blocage des plateformes ──────────────────────────────────────────────

  @override
  Future<List<BlockablePlatform>> fetchPlatforms() {
    _requireSession();
    return _delay(List<BlockablePlatform>.from(_platforms));
  }

  @override
  Future<BlockablePlatform> setPlatformBlocked({
    required String key,
    required bool blocked,
  }) async {
    _requireSession();
    await Future.delayed(const Duration(milliseconds: 900));
    final index = _platforms.indexWhere((p) => p.key == key);
    if (index < 0) {
      throw const ApiException('Plateforme inconnue.', kind: ApiErrorKind.notFound);
    }
    final updated = _platforms[index].copyWith(
      state: blocked ? BlockState.blocked : BlockState.allowed,
    );
    _platforms[index] = updated;
    return updated;
  }

  // ── Notifications ────────────────────────────────────────────────────────

  @override
  Future<List<AppNotification>> fetchNotifications() {
    _requireSession();
    return _delay(List<AppNotification>.from(_notifications));
  }

  @override
  Future<void> markNotificationRead(String id) async {
    _requireSession();
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0) _notifications[index] = _notifications[index].copyWith(read: true);
  }

  @override
  Future<void> deleteNotification(String id) async {
    _requireSession();
    await Future.delayed(const Duration(milliseconds: 250));
    _notifications.removeWhere((n) => n.id == id);
  }

  // ── Jeux de données ──────────────────────────────────────────────────────

  /// Une facture datée de [monthsAgo] mois, référencée comme sur les maquettes.
  Invoice _invoice({
    required int monthsAgo,
    required double amount,
    required InvoiceStatus status,
    required int ref,
  }) {
    final now = DateTime.now();
    final period = DateTime(now.year, now.month - monthsAgo, 1);
    return Invoice(
      id: 'inv-$ref',
      reference: 'INV-$ref',
      periodLabel: Fmt.monthYear(period),
      issueDate: period,
      dueDate: DateTime(period.year, period.month, 5),
      amount: amount,
      status: status,
      paidAt: status == InvoiceStatus.paid
          ? DateTime(period.year, period.month, 2)
          : null,
      pdfUrl: 'https://example.invalid/factures/INV-$ref.pdf',
    );
  }

  List<Invoice> _seedInvoices() {
    if (scenario == MockScenario.upToDate) {
      return [
        _invoice(monthsAgo: 0, amount: 2500, status: InvoiceStatus.paid, ref: 876543),
        _invoice(monthsAgo: 1, amount: 2500, status: InvoiceStatus.paid, ref: 876420),
        _invoice(monthsAgo: 2, amount: 2500, status: InvoiceStatus.paid, ref: 876311),
      ];
    }
    // Total impayé = 2 500 + 4 900 + 5 000 = 12 400 MRU, comme l'écran 05.
    return [
      _invoice(monthsAgo: 0, amount: 2500, status: InvoiceStatus.pending, ref: 876543),
      _invoice(monthsAgo: 1, amount: 2500, status: InvoiceStatus.paid, ref: 876420),
      _invoice(monthsAgo: 2, amount: 4900, status: InvoiceStatus.overdue, ref: 876311),
      _invoice(monthsAgo: 3, amount: 2500, status: InvoiceStatus.paid, ref: 876190),
      _invoice(monthsAgo: 4, amount: 5000, status: InvoiceStatus.overdue, ref: 876042),
    ];
  }

  List<Payment> _seedPayments() {
    final now = DateTime.now();
    return [
      Payment(
        id: 'p-99283',
        reference: 'PAY-99283',
        date: now.subtract(const Duration(days: 3)),
        amount: 2500,
        status: PaymentStatus.confirmed,
        method: 'Bankily',
      ),
      Payment(
        id: 'p-99150',
        reference: 'PAY-99150',
        date: now.subtract(const Duration(days: 16)),
        amount: 4950,
        status: PaymentStatus.pending,
        method: 'Masrivi',
      ),
      Payment(
        id: 'p-98990',
        reference: 'PAY-98990',
        date: now.subtract(const Duration(days: 34)),
        amount: 4950,
        status: PaymentStatus.refused,
        method: 'Sedad',
      ),
      Payment(
        id: 'p-98744',
        reference: 'PAY-98744',
        date: now.subtract(const Duration(days: 48)),
        amount: 2500,
        status: PaymentStatus.confirmed,
        method: 'Bankily',
      ),
    ];
  }

  List<BlockablePlatform> _seedPlatforms() => [
        const BlockablePlatform(
          key: 'tiktok',
          label: 'TikTok',
          category: 'Réseaux sociaux',
          subtitle: 'Bloquer tiktok.com',
          state: BlockState.allowed,
        ),
        const BlockablePlatform(
          key: 'facebook',
          label: 'Facebook',
          category: 'Réseaux sociaux',
          subtitle: 'Bloquer facebook.com',
          state: BlockState.blocked,
        ),
        const BlockablePlatform(
          key: 'instagram',
          label: 'Instagram',
          category: 'Réseaux sociaux',
          subtitle: 'Bloquer instagram.com',
          state: BlockState.allowed,
        ),
        const BlockablePlatform(
          key: 'snapchat',
          label: 'Snapchat',
          category: 'Réseaux sociaux',
          subtitle: 'Bloquer snapchat.com',
          state: BlockState.blocked,
        ),
        const BlockablePlatform(
          key: 'youtube',
          label: 'YouTube',
          category: 'Streaming',
          subtitle: 'Bloquer youtube.com',
          state: BlockState.blocked,
        ),
        const BlockablePlatform(
          key: 'netflix',
          label: 'Netflix',
          category: 'Streaming',
          subtitle: 'Bloquer netflix.com',
          state: BlockState.allowed,
        ),
        // Pas un site précis mais une catégorie : la détection s'appuie sur le
        // mécanisme de filtrage déjà en place côté A2 Connect, pas sur une
        // liste de domaines tenue par l'app. Le blocage effectif sera branché
        // avec le reste de l'API — cette entrée n'est, pour l'instant, que le
        // choix proposé à l'abonné.
        const BlockablePlatform(
          key: 'adult_content',
          label: 'Contenu pour adultes (+18)',
          category: 'Contrôle parental',
          subtitle: 'Bloquer les sites détectés comme réservés aux adultes.',
          state: BlockState.allowed,
        ),
      ];

  List<AppNotification> _seedNotifications() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'n-1',
        kind: NotificationKind.paymentSuccess,
        title: 'Paiement validé',
        body: 'Votre paiement pour la facture #FA-2026-089 a été traité avec succès.',
        date: now.subtract(const Duration(hours: 2)),
        read: false,
        relatedType: 'payment',
        relatedId: 'p-99283',
      ),
      AppNotification(
        id: 'n-2',
        kind: NotificationKind.newInvoice,
        title: 'Nouvelle facture',
        body: 'Votre facture est maintenant disponible dans votre espace client.',
        date: DateTime(now.year, now.month, now.day, 8, 30),
        read: false,
        relatedType: 'invoice',
        relatedId: 'inv-876543',
      ),
      AppNotification(
        id: 'n-3',
        kind: NotificationKind.maintenance,
        title: 'Maintenance programmée',
        body: 'Une intervention est prévue sur le réseau de 02:00 à 04:00.',
        date: now.subtract(const Duration(days: 1)),
        read: true,
      ),
      AppNotification(
        id: 'n-4',
        kind: NotificationKind.accessRestricted,
        title: 'Accès restreint',
        body: 'Suite à plusieurs tentatives de connexion, votre accès a été '
            'temporairement bloqué.',
        date: now.subtract(const Duration(days: 5)),
        read: true,
      ),
      AppNotification(
        id: 'n-5',
        kind: NotificationKind.info,
        title: 'Mise à jour des CGU',
        body: 'Nous avons mis à jour nos conditions générales d\'utilisation.',
        date: now.subtract(const Duration(days: 7)),
        read: true,
      ),
      AppNotification(
        id: 'n-6',
        kind: NotificationKind.paymentFailed,
        title: 'Paiement échoué',
        body: 'Le prélèvement pour votre abonnement n\'a pas pu être effectué.',
        date: now.subtract(const Duration(days: 9)),
        read: true,
        relatedType: 'payment',
        relatedId: 'p-98990',
      ),
    ];
  }
}
