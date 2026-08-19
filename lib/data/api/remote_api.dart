import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/config.dart';
import '../models/models.dart';
import 'a2_api.dart';
import 'api_exception.dart';

/// Implémentation réelle de [A2Api] : les appels HTTP vers le backend A2 Connect.
///
/// ⚠️ **À CALER SUR LA DOCUMENTATION DE L'API.** Les chemins et les noms de
/// champs ci-dessous sont des hypothèses de travail, choisies pour que le
/// projet compile et que le branchement soit mécanique. Ce qu'il faudra
/// ajuster à réception de la doc :
///
///  1. les chemins (`_Paths`) ;
///  2. la façon dont le jeton est transmis (en-tête `Authorization` ? cookie ?
///     autre en-tête maison ?) ;
///  3. le nom des champs JSON, dans `fromJson` des modèles — un seul fichier ;
///  4. la forme des listes : tableau nu, ou objet `{ "data": [...] }` ?
///     (géré par [_asList] ci-dessous.)
///  5. le nom du champ multipart du justificatif de paiement (`receipt` dans
///     [createPayment]) et le format attendu par le webhook du système de
///     paiement existant.
///
/// Aucun écran n'a à être modifié pour ce branchement.
class RemoteA2Api implements A2Api {
  RemoteA2Api({Dio? dio, this.onUnauthorized}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  /// Appelé quand le backend répond 401 : c'est au niveau applicatif de
  /// décider (vider la session, retourner à l'écran de connexion).
  final void Function()? onUnauthorized;

  String? _token;

  static Dio _buildDio() => Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          headers: {'Accept': 'application/json'},
          // On lit nous-mêmes les codes d'erreur pour produire un message
          // en français plutôt qu'une exception Dio brute.
          validateStatus: (code) => code != null && code < 500,
        ),
      );

  /// Le jeton est posé après la connexion et retiré à la déconnexion.
  void setToken(String? token) {
    _token = token;
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  bool get hasToken => _token != null;

  // ── Plomberie ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? query}) async {
    final res = await _send(() => _dio.get<dynamic>(path, queryParameters: query));
    return _asMap(res.data);
  }

  Future<List<Map<String, dynamic>>> _getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _send(() => _dio.get<dynamic>(path, queryParameters: query));
    return _asList(res.data);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Object? body,
    Options? options,
  }) async {
    final res = await _send(
      () => _dio.post<dynamic>(path, data: body, options: options),
    );
    return _asMap(res.data);
  }

  /// Exécute l'appel et traduit tout échec en [ApiException].
  Future<Response<dynamic>> _send(Future<Response<dynamic>> Function() call) async {
    late final Response<dynamic> res;
    try {
      res = await call();
    } on DioException catch (e) {
      throw _fromDio(e);
    }

    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) return res;

    final message = _messageFrom(res.data);
    if (code == 401 || code == 403) onUnauthorized?.call();
    throw switch (code) {
      401 || 403 => ApiException(
          message ?? 'Votre session a expiré. Reconnectez-vous.',
          kind: ApiErrorKind.unauthorized,
          statusCode: code,
        ),
      404 => ApiException(
          message ?? 'Information introuvable.',
          kind: ApiErrorKind.notFound,
          statusCode: code,
        ),
      _ => ApiException(
          message ?? 'La demande n\'a pas pu être traitée.',
          statusCode: code,
        ),
    };
  }

  ApiException _fromDio(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          const ApiException(
            'Le serveur met trop de temps à répondre. Réessayez.',
            kind: ApiErrorKind.timeout,
          ),
        DioExceptionType.connectionError || DioExceptionType.unknown =>
          const ApiException(
            'Impossible de joindre A2 Connect. Vérifiez votre connexion.',
            kind: ApiErrorKind.network,
          ),
        DioExceptionType.badCertificate => const ApiException(
            'La connexion sécurisée au serveur a échoué.',
            kind: ApiErrorKind.network,
          ),
        _ => ApiException(
            e.message ?? 'Une erreur inattendue est survenue.',
          ),
      };

  /// Le message d'erreur du backend, s'il en fournit un exploitable.
  String? _messageFrom(Object? data) {
    if (data is Map) {
      for (final key in ['message', 'detail', 'error']) {
        final v = data[key];
        if (v is String && v.trim().isNotEmpty) return v;
      }
    }
    return null;
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) {
      // Certaines API enveloppent la ressource dans « data ».
      final inner = data['data'];
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    throw const ApiException('Réponse inattendue du serveur.');
  }

  /// Accepte les deux formes courantes : `[...]` ou `{ "data": [...] }`.
  List<Map<String, dynamic>> _asList(Object? data) {
    final raw = switch (data) {
      List l => l,
      Map m when m['data'] is List => m['data'] as List,
      Map m when m['items'] is List => m['items'] as List,
      _ => throw const ApiException('Réponse inattendue du serveur.'),
    };
    return raw.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  // ── Authentification ─────────────────────────────────────────────────────

  @override
  Future<Session> login({required String phone, required String clientId}) async {
    final json = await _post(
      _Paths.login,
      body: {'phone': phone, 'client_id': clientId},
    );
    final session = Session.fromJson(json);
    setToken(session.token);
    return session;
  }

  @override
  Future<void> logout() async {
    try {
      await _post(_Paths.logout);
    } on ApiException {
      // Une déconnexion ne doit jamais échouer côté app : on vide le jeton
      // local quoi qu'il arrive.
    } finally {
      setToken(null);
    }
  }

  // ── Accueil ──────────────────────────────────────────────────────────────

  @override
  Future<Subscription> fetchSubscription() async =>
      Subscription.fromJson(await _get(_Paths.subscription));

  @override
  Future<Balance> fetchBalance() async =>
      Balance.fromJson(await _get(_Paths.balance));

  @override
  Future<NetworkStatus> fetchNetworkStatus() async =>
      NetworkStatus.fromJson(await _get(_Paths.networkStatus));

  // ── Factures ─────────────────────────────────────────────────────────────

  @override
  Future<List<Invoice>> fetchInvoices({int page = 1}) async {
    final rows = await _getList(_Paths.invoices, query: {'page': page});
    return rows.map(Invoice.fromJson).toList(growable: false);
  }

  @override
  Future<Invoice> fetchInvoice(String invoiceId) async =>
      Invoice.fromJson(await _get('${_Paths.invoices}/$invoiceId'));

  // ── Paiements ────────────────────────────────────────────────────────────

  @override
  Future<List<Payment>> fetchPayments({int page = 1}) async {
    final rows = await _getList(_Paths.payments, query: {'page': page});
    return rows.map(Payment.fromJson).toList(growable: false);
  }

  @override
  Future<Payment> fetchPayment(String paymentId) async =>
      Payment.fromJson(await _get('${_Paths.payments}/$paymentId'));

  @override
  Future<List<PaymentMethod>> fetchPaymentMethods() async {
    final rows = await _getList(_Paths.paymentMethods);
    return rows.map(PaymentMethod.fromJson).toList(growable: false);
  }

  @override
  Future<Payment> createPayment({
    required double amount,
    required String methodCode,
    required String idempotencyKey,
    required Uint8List receiptImage,
    required String receiptFileName,
    String? invoiceId,
  }) async {
    // Envoi multipart : le justificatif (capture d'écran de la confirmation
    // de l'opérateur) voyage avec la demande, pas d'appel séparé.
    final body = FormData.fromMap({
      'amount': amount,
      'method': methodCode,
      if (invoiceId != null) 'invoice_id': invoiceId,
      'receipt': MultipartFile.fromBytes(receiptImage, filename: receiptFileName),
    });
    final json = await _post(
      _Paths.payments,
      body: body,
      options: Options(
        // La clé voyage aussi en en-tête : c'est la convention la plus
        // répandue côté passerelles de paiement. À confirmer avec A2 Connect.
        headers: {'Idempotency-Key': idempotencyKey},
        sendTimeout: AppConfig.paymentTimeout,
        receiveTimeout: AppConfig.paymentTimeout,
      ),
    );
    return Payment.fromJson(json);
  }

  // ── Blocage des plateformes ──────────────────────────────────────────────

  @override
  Future<List<BlockablePlatform>> fetchPlatforms() async {
    final rows = await _getList(_Paths.platforms);
    return rows.map(BlockablePlatform.fromJson).toList(growable: false);
  }

  @override
  Future<BlockablePlatform> setPlatformBlocked({
    required String key,
    required bool blocked,
  }) async {
    final json = await _post(
      '${_Paths.platforms}/$key',
      body: {'blocked': blocked},
    );
    return BlockablePlatform.fromJson(json);
  }

  // ── Notifications ────────────────────────────────────────────────────────

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    final rows = await _getList(_Paths.notifications);
    return rows.map(AppNotification.fromJson).toList(growable: false);
  }

  @override
  Future<void> markNotificationRead(String id) =>
      _post('${_Paths.notifications}/$id/read');

  @override
  Future<void> deleteNotification(String id) async {
    await _send(() => _dio.delete<dynamic>('${_Paths.notifications}/$id'));
  }
}

/// Les chemins de l'API, rassemblés ici pour être corrigés d'un seul endroit.
abstract final class _Paths {
  static const login = '/auth/login';
  static const logout = '/auth/logout';
  static const subscription = '/me/subscription';
  static const balance = '/me/balance';
  static const networkStatus = '/me/network-status';
  static const invoices = '/me/invoices';
  static const payments = '/me/payments';
  static const paymentMethods = '/payment-methods';
  static const platforms = '/me/platforms';
  static const notifications = '/me/notifications';
}
