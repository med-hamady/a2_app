import 'package:a2connect/data/api/a2_api.dart';
import 'package:a2connect/data/api/api_exception.dart';
import 'package:a2connect/data/api/mock_api.dart';
import 'package:a2connect/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Tests de la couche de données factice.
///
/// Ils vérifient les règles que l'interface tient pour acquises — notamment la
/// protection contre le double paiement, qui est le seul endroit de l'app où
/// une erreur coûte de l'argent à l'abonné.
void main() {
  // Les libellés de période sont formatés en français, comme dans main().
  setUpAll(() => initializeDateFormatting('fr_FR'));

  late A2Api api;

  Future<Session> connect() =>
      api.login(phone: '22345678', clientId: '87654321');

  setUp(() => api = MockA2Api());

  group('Connexion', () {
    test('un identifiant valide ouvre une session', () async {
      final session = await connect();
      expect(session.clientId, '87654321');
      expect(session.firstName, isNotEmpty);
    });

    test('l\'identifiant de test 0000 est refusé', () async {
      expect(
        () => api.login(phone: '22345678', clientId: '0000'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.invalidCredentials,
          ),
        ),
      );
    });

    test('les données sont inaccessibles sans session', () async {
      expect(
        () => api.fetchInvoices(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized),
        ),
      );
    });
  });

  group('Solde', () {
    test('le montant dû est la somme des factures non réglées', () async {
      await connect();
      final invoices = await api.fetchInvoices();
      final expected = invoices
          .where((i) => i.status != InvoiceStatus.paid)
          .fold<double>(0, (sum, i) => sum + i.amount);

      final balance = await api.fetchBalance();
      expect(balance.amountDue, expected);
      expect(balance.isUpToDate, expected == 0);
    });
  });

  group('Paiement', () {
    test('rejouer la même clé d\'idempotence ne débite qu\'une fois', () async {
      await connect();
      final before = (await api.fetchPayments()).length;

      final first = await api.createPayment(
        amount: 2500,
        methodCode: 'bankily',
        idempotencyKey: 'cle-unique',
      );
      final second = await api.createPayment(
        amount: 2500,
        methodCode: 'bankily',
        idempotencyKey: 'cle-unique',
      );

      expect(second.id, first.id);
      expect((await api.fetchPayments()).length, before + 1);
    });

    test('régler une facture la fait passer en « payée »', () async {
      await connect();
      final target = (await api.fetchInvoices())
          .firstWhere((i) => i.status == InvoiceStatus.overdue);

      await api.createPayment(
        amount: target.amount,
        methodCode: 'bankily',
        idempotencyKey: 'cle-facture',
        invoiceId: target.id,
      );

      final after = await api.fetchInvoice(target.id);
      expect(after.status, InvoiceStatus.paid);
    });
  });

  group('Blocage des plateformes', () {
    test('la bascule est persistée', () async {
      await connect();
      final updated =
          await api.setPlatformBlocked(key: 'tiktok', blocked: true);
      expect(updated.state, BlockState.blocked);

      final list = await api.fetchPlatforms();
      expect(list.firstWhere((p) => p.key == 'tiktok').isOn, isTrue);
    });

    test('une plateforme inconnue est refusée', () async {
      await connect();
      expect(
        () => api.setPlatformBlocked(key: 'inexistante', blocked: true),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
