import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/formatters.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';

/// Écran de règlement (§4.5 du cahier des charges).
///
/// **Il n'existe pas dans les maquettes** : le parcours de paiement n'a pas été
/// dessiné. Ce qui suit est une proposition construite avec la même charte, et
/// avec les garde-fous que tout paiement réel impose :
///
///  - une **clé d'idempotence** générée une seule fois à l'ouverture de
///    l'écran, envoyée à chaque tentative → deux appuis ne font qu'un débit ;
///  - un **récapitulatif** validé avant l'appel, comme demandé par le cahier ;
///  - la prise en charge d'une réponse **« en attente »**, l'opérateur de
///    mobile money ne confirmant pas toujours dans la seconde.
///
/// À revoir avec A2 Connect une fois le canal de paiement arrêté.
class PayScreen extends ConsumerStatefulWidget {
  const PayScreen({super.key, this.invoiceId});

  /// Facture à régler. `null` = paiement d'un montant libre.
  final String? invoiceId;

  @override
  ConsumerState<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends ConsumerState<PayScreen> {
  /// Générée UNE fois pour la durée de l'écran : c'est tout l'intérêt. Elle
  /// est rejouée telle quelle si l'abonné réessaie après un échec réseau, ce
  /// qui permet au backend de reconnaître la tentative au lieu de débiter deux
  /// fois.
  late final String _idempotencyKey = _newKey();

  final _amountController = TextEditingController();
  String? _methodCode;
  bool _submitting = false;
  Object? _error;

  static String _newKey() {
    final random = Random.secure();
    final bytes = List.generate(8, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().millisecondsSinceEpoch}-$hex';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? get _typedAmount {
    final raw = _amountController.text.replaceAll(RegExp(r'[^0-9.,]'), '')
        .replaceAll(',', '.');
    final value = double.tryParse(raw);
    return (value == null || value <= 0) ? null : value;
  }

  Future<void> _confirm(double amount, Invoice? invoice) async {
    final method = _methodCode;
    if (method == null) return;

    final ok = await _showRecap(amount, method, invoice);
    if (ok != true || !mounted) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final payment = await ref.read(apiProvider).createPayment(
            amount: amount,
            methodCode: method,
            idempotencyKey: _idempotencyKey,
            invoiceId: invoice?.id,
          );

      // Le paiement a bougé le solde et la liste des factures : on les
      // recharge avant de montrer le résultat, sinon l'abonné revient sur un
      // accueil qui affiche encore l'ancien montant.
      ref.invalidate(paymentsProvider);
      ref.invalidate(invoicesProvider);
      ref.invalidate(balanceProvider);

      if (!mounted) return;
      // On remplace l'écran de paiement : revenir en arrière depuis le reçu ne
      // doit pas ramener sur le formulaire.
      context.pushReplacement(Routes.payment(payment.id));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _submitting = false;
      });
    }
  }

  /// Le récapitulatif exigé par le §4.5 avant confirmation.
  Future<bool?> _showRecap(double amount, String methodCode, Invoice? invoice) {
    final methodLabel = (ref.read(paymentMethodsProvider).value ?? const [])
            .where((m) => m.code == methodCode)
            .firstOrNull
            ?.label ??
        methodCode;

    return showAppBottomSheet<bool>(
      context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Confirmer le paiement', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              _RecapLine(label: 'Montant', value: Fmt.money(amount), strong: true),
              if (invoice != null)
                _RecapLine(label: 'Facture', value: invoice.reference),
              _RecapLine(label: 'Moyen de paiement', value: methodLabel),
              const SizedBox(height: AppSpacing.lg),
              const InfoBanner(
                text: 'La confirmation peut demander une validation sur votre '
                    'téléphone. Ne fermez pas l\'application avant le résultat.',
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('CONFIRMER'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: const Text('Annuler'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final methods = ref.watch(paymentMethodsProvider);
    final invoiceAsync = widget.invoiceId == null
        ? null
        : ref.watch(invoiceProvider(widget.invoiceId!));
    final invoice = invoiceAsync?.value;

    // Facture réglée : le montant est imposé. Paiement libre : il est saisi.
    final amount = invoice?.amount ?? _typedAmount;
    final canSubmit = !_submitting && amount != null && _methodCode != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Effectuer un paiement'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _submitting ? null : () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                120,
              ),
              children: [
                if (invoice != null) ...[
                  AppCard.highlighted(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('Facture à régler'),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          invoice.periodLabel,
                          style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                        ),
                        Text(
                          'Ref: ${invoice.reference}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          Fmt.money(invoice.amount),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SectionLabel('Montant à payer'),
                  const SizedBox(height: AppSpacing.sm + 4),
                  TextField(
                    controller: _amountController,
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: theme.textTheme.headlineSmall?.copyWith(fontSize: 26),
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: Fmt.currency,
                      suffixStyle: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),
                  const InfoBanner(
                    text: 'Le paiement partiel et le montant minimum restent à '
                        'confirmer avec A2 Connect : ce sont des règles métier, '
                        'elles seront appliquées par le backend.',
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Moyen de paiement'),
                const SizedBox(height: AppSpacing.sm + 4),

                AsyncView(
                  value: methods,
                  skeletonHeight: 180,
                  onRetry: () => ref.invalidate(paymentMethodsProvider),
                  data: (list) => Column(
                    children: [
                      for (final method in list) ...[
                        _MethodTile(
                          method: method,
                          selected: _methodCode == method.code,
                          enabled: !_submitting,
                          onTap: () => setState(() => _methodCode = method.code),
                        ),
                        const SizedBox(height: AppSpacing.sm + 4),
                      ],
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ErrorView(error: _error!, compact: true),
                ],
              ],
            ),

            // Le bouton reste accessible sans faire défiler jusqu'en bas.
            Positioned(
              left: AppSpacing.screen,
              right: AppSpacing.screen,
              bottom: AppSpacing.md,
              child: ElevatedButton(
                onPressed: canSubmit ? () => _confirm(amount, invoice) : null,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        amount == null
                            ? 'PAYER'
                            : 'PAYER ${Fmt.money(amount)}',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = method.available && enabled;
    return Opacity(
      opacity: available ? 1 : 0.5,
      child: AppCard(
        color: selected ? AppColors.surface : AppColors.surfaceMuted,
        borderColor: selected ? AppColors.primary : AppColors.border,
        borderWidth: selected ? 1.5 : 1,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        onTap: available ? onTap : null,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                method.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                    ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecapLine extends StatelessWidget {
  const _RecapLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: SectionLabel(label)),
          Text(
            value,
            style: (strong ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)
                ?.copyWith(fontSize: strong ? 22 : 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
