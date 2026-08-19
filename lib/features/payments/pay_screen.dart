import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
/// **Le règlement se fait hors de l'application** : le client paie
/// directement auprès de son opérateur de mobile money (Bankily, Masrivi,
/// Sedad…), puis transmet ici la capture d'écran de la confirmation. C'est
/// le système de paiement déjà en place côté A2 Connect — via son webhook —
/// qui vérifie et confirme le paiement, pas cet écran. L'app ne débite donc
/// jamais rien elle-même ; son rôle se limite à collecter le justificatif.
///
/// **Il n'existe pas dans les maquettes** : le parcours n'a pas été dessiné.
/// Ce qui suit est construit avec la même charte, et avec les garde-fous
/// qu'impose ce genre de soumission :
///
///  - une **clé d'idempotence** générée une seule fois à l'ouverture de
///    l'écran, envoyée à chaque tentative → deux appuis n'envoient qu'un
///    justificatif ;
///  - un **récapitulatif** validé avant l'appel, comme demandé par le cahier ;
///  - un statut **« en attente »** par défaut : la confirmation vient du
///    webhook du système de paiement, jamais de cette soumission.
///
/// À revoir avec A2 Connect une fois le numéro marchand et le format de
/// justificatif attendus par le webhook arrêtés.
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
  XFile? _receipt;
  bool _submitting = false;
  Object? _error;

  Future<void> _pickReceipt() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (file != null) setState(() => _receipt = file);
  }

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

  String _methodLabel({required List<PaymentMethod>? list, required String code}) =>
      (list ?? const []).where((m) => m.code == code).firstOrNull?.label ?? code;

  double? get _typedAmount {
    final raw = _amountController.text.replaceAll(RegExp(r'[^0-9.,]'), '')
        .replaceAll(',', '.');
    final value = double.tryParse(raw);
    return (value == null || value <= 0) ? null : value;
  }

  Future<void> _confirm(double amount, Invoice? invoice) async {
    final method = _methodCode;
    final receipt = _receipt;
    if (method == null || receipt == null) return;

    final ok = await _showRecap(amount, method, invoice);
    if (ok != true || !mounted) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final receiptBytes = await receipt.readAsBytes();
      final payment = await ref.read(apiProvider).createPayment(
            amount: amount,
            methodCode: method,
            idempotencyKey: _idempotencyKey,
            receiptImage: receiptBytes,
            receiptFileName: receipt.name,
            invoiceId: invoice?.id,
          );

      // Le justificatif ne confirme rien par lui-même — c'est le webhook du
      // système de paiement qui le fera — mais on recharge quand même les
      // listes : le nouveau paiement « en attente » doit apparaître tout de
      // suite dans l'historique.
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
    final methodLabel = _methodLabel(
      list: ref.read(paymentMethodsProvider).value,
      code: methodCode,
    );

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
              Text('Envoyer le justificatif ?', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              _RecapLine(label: 'Montant réglé', value: Fmt.money(amount), strong: true),
              if (invoice != null)
                _RecapLine(label: 'Facture', value: invoice.reference),
              _RecapLine(label: 'Moyen de paiement', value: methodLabel),
              const SizedBox(height: AppSpacing.lg),
              const InfoBanner(
                text: 'Nous transmettons votre justificatif au système de '
                    'paiement A2 Connect pour vérification. Vous serez notifié '
                    'dès que le paiement sera confirmé.',
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('ENVOYER'),
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
    final canSubmit =
        !_submitting && amount != null && _methodCode != null && _receipt != null;

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
                const SectionLabel('Moyen de paiement utilisé'),
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

                if (_methodCode != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  InfoBanner(
                    icon: Icons.info_outline,
                    text: 'Envoyez le montant depuis l\'application '
                        '${_methodLabel(list: methods.value, code: _methodCode!)}, '
                        'puis ajoutez ci-dessous la capture d\'écran de la '
                        'confirmation. Le numéro marchand A2 Connect reste à '
                        'confirmer.',
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Justificatif de paiement'),
                const SizedBox(height: AppSpacing.sm + 4),
                _ReceiptPicker(
                  receipt: _receipt,
                  enabled: !_submitting,
                  onPick: _pickReceipt,
                  onRemove: () => setState(() => _receipt = null),
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
                    : const Text('ENVOYER LE JUSTIFICATIF'),
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

/// La preuve du paiement fait hors de l'application : une capture d'écran de
/// la confirmation de l'opérateur, seule pièce dont A2 Connect dispose tant
/// que le webhook du système de paiement n'a pas confirmé.
class _ReceiptPicker extends StatelessWidget {
  const _ReceiptPicker({
    required this.receipt,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? receipt;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = receipt;

    if (file == null) {
      return AppCard(
        onTap: enabled ? onPick : null,
        color: AppColors.surfaceMuted,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_photo_alternate_outlined,
              size: 32,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Text(
              'Ajouter une capture d\'écran',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'La confirmation reçue de votre opérateur (JPG, PNG).',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return AppCard.highlighted(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.field),
            child: Image.file(
              File(file.path),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Justificatif ajouté',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: enabled ? onRemove : null,
            tooltip: 'Retirer',
          ),
        ],
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
