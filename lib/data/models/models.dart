import 'enums.dart';

export 'enums.dart';

/// Petits utilitaires de lecture tolérante : le JSON réel n'est pas encore
/// connu, on ne veut pas d'un crash sur un champ absent ou d'un type
/// inattendu (montant renvoyé en String, date en timestamp, etc.).
double _toDouble(Object? v) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s.replaceAll(' ', '').replaceAll(',', '.')) ?? 0,
      _ => 0,
    };

DateTime? _toDate(Object? v) => switch (v) {
      String s => DateTime.tryParse(s),
      int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      _ => null,
    };

// ─────────────────────────────────────────────────────────────────────────────

/// Ce que renvoie l'API d'authentification et qu'on garde pour la session.
class Session {
  const Session({
    required this.token,
    required this.clientId,
    required this.firstName,
  });

  final String token;

  /// L'identifiant client affiché sur les factures (écran 06).
  final String clientId;

  /// Prénom affiché dans « Bonjour Ahmed » (écran 04).
  final String firstName;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        token: json['token'] as String? ?? '',
        clientId: json['client_id']?.toString() ?? '',
        firstName: json['first_name'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'client_id': clientId,
        'first_name': firstName,
      };
}

/// Bloc « détails de l'abonnement » de l'accueil.
class Subscription {
  const Subscription({
    required this.planName,
    required this.monthlyPrice,
    required this.renewalDate,
    required this.speedLabel,
    required this.quotaLabel,
    required this.status,
  });

  final String planName;
  final double monthlyPrice;
  final DateTime? renewalDate;

  /// « 500 Mbps » — libellé prêt à afficher, pas un débit à recalculer.
  final String speedLabel;

  /// « Illimité ».
  final String quotaLabel;

  final SubscriptionStatus status;

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        planName: json['plan_name'] as String? ?? '',
        monthlyPrice: _toDouble(json['monthly_price']),
        renewalDate: _toDate(json['renewal_date']),
        speedLabel: json['speed_label'] as String? ?? '',
        quotaLabel: json['quota_label'] as String? ?? '',
        status: SubscriptionStatus.fromApi(json['status'] as String?),
      );
}

/// Le solde. Deux informations distinctes, à ne pas confondre : `amountDue`
/// est ce que le client doit maintenant, `isUpToDate` pilote la pastille
/// « À jour » de l'accueil.
class Balance {
  const Balance({required this.amountDue, required this.isUpToDate});

  final double amountDue;
  final bool isUpToDate;

  factory Balance.fromJson(Map<String, dynamic> json) {
    final due = _toDouble(json['amount_due']);
    return Balance(
      amountDue: due,
      isUpToDate: json['is_up_to_date'] as bool? ?? due == 0,
    );
  }
}

/// Les trois maillons de la chaîne réseau affichée sur l'accueil.
class NetworkStatus {
  const NetworkStatus({
    required this.client,
    required this.modem,
    required this.internet,
    required this.label,
  });

  final LinkState client;
  final LinkState modem;
  final LinkState internet;

  /// Phrase de synthèse affichée sous le schéma (« Connexion établie »).
  final String label;

  factory NetworkStatus.fromJson(Map<String, dynamic> json) => NetworkStatus(
        client: LinkState.fromApi(json['client'] as String?),
        modem: LinkState.fromApi(json['modem'] as String?),
        internet: LinkState.fromApi(json['internet'] as String?),
        label: json['label'] as String? ?? '',
      );

  bool get isFullyUp =>
      client == LinkState.up && modem == LinkState.up && internet == LinkState.up;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.reference,
    required this.periodLabel,
    required this.issueDate,
    required this.dueDate,
    required this.amount,
    required this.status,
    this.paidAt,
    this.pdfUrl,
  });

  final String id;
  final String reference;

  /// « Mars 2026 » — libellé de période fourni par l'API, pas recalculé côté
  /// app (le découpage de facturation appartient au backend).
  final String periodLabel;

  final DateTime? issueDate;
  final DateTime? dueDate;
  final double amount;
  final InvoiceStatus status;
  final DateTime? paidAt;
  final String? pdfUrl;

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id']?.toString() ?? '',
        reference: json['reference'] as String? ?? '',
        periodLabel: json['period_label'] as String? ?? '',
        issueDate: _toDate(json['issue_date']),
        dueDate: _toDate(json['due_date']),
        amount: _toDouble(json['amount']),
        status: InvoiceStatus.fromApi(json['status'] as String?),
        paidAt: _toDate(json['paid_at']),
        pdfUrl: json['pdf_url'] as String?,
      );

  /// Nombre de jours de retard, pour le « Retard de 15 jours » en rouge.
  int? get daysLate {
    if (status != InvoiceStatus.overdue || dueDate == null) return null;
    final days = DateTime.now().difference(dueDate!).inDays;
    return days > 0 ? days : null;
  }
}

class Payment {
  const Payment({
    required this.id,
    required this.reference,
    required this.date,
    required this.amount,
    required this.status,
    required this.method,
    this.invoiceId,
    this.invoicePeriodLabel,
  });

  final String id;
  final String reference;
  final DateTime? date;
  final double amount;
  final PaymentStatus status;

  /// « Bankily », « Masrivi », « Sedad » — tel que renvoyé par l'API.
  final String method;

  final String? invoiceId;
  final String? invoicePeriodLabel;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id']?.toString() ?? '',
        reference: json['reference'] as String? ?? '',
        date: _toDate(json['date']),
        amount: _toDouble(json['amount']),
        status: PaymentStatus.fromApi(json['status'] as String?),
        method: json['method'] as String? ?? '',
        invoiceId: json['invoice_id']?.toString(),
        invoicePeriodLabel: json['invoice_period_label'] as String?,
      );
}

/// Un moyen de paiement proposé au client au moment de régler.
class PaymentMethod {
  const PaymentMethod({
    required this.code,
    required this.label,
    this.available = true,
  });

  final String code;
  final String label;
  final bool available;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        code: json['code'] as String? ?? '',
        label: json['label'] as String? ?? '',
        available: json['available'] as bool? ?? true,
      );
}

/// Une plateforme blocable (écran 09).
class BlockablePlatform {
  const BlockablePlatform({
    required this.key,
    required this.label,
    required this.category,
    required this.subtitle,
    required this.state,
  });

  final String key;
  final String label;

  /// « Réseaux sociaux », « Streaming », « Jeux » — sert au regroupement.
  final String category;

  /// « Bloquer tiktok.com ».
  final String subtitle;

  final BlockState state;

  factory BlockablePlatform.fromJson(Map<String, dynamic> json) =>
      BlockablePlatform(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        category: json['category'] as String? ?? 'Autres',
        subtitle: json['subtitle'] as String? ?? '',
        state: BlockState.fromApi(json['state'] as String?),
      );

  BlockablePlatform copyWith({BlockState? state}) => BlockablePlatform(
        key: key,
        label: label,
        category: category,
        subtitle: subtitle,
        state: state ?? this.state,
      );

  /// L'interrupteur est visuellement « allumé » dès que le blocage est
  /// demandé, même si l'équipement ne l'a pas encore appliqué.
  bool get isOn => state == BlockState.blocked || state == BlockState.pending;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.date,
    required this.read,
    this.relatedType,
    this.relatedId,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime? date;
  final bool read;

  /// « payment » ou « invoice » — vers quoi taper la notification navigue.
  /// `null` pour les notifications purement informatives (maintenance, CGU).
  final String? relatedType;
  final String? relatedId;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id']?.toString() ?? '',
        kind: NotificationKind.fromApi(json['kind'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        date: _toDate(json['date']),
        read: json['read'] as bool? ?? false,
        relatedType: json['related_type'] as String?,
        relatedId: json['related_id']?.toString(),
      );

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        date: date,
        read: read ?? this.read,
        relatedType: relatedType,
        relatedId: relatedId,
      );
}
