import 'package:flutter/material.dart';
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

/// Écran 08 : le détail d'un paiement.
///
/// Trois habillages selon le statut. Le cas `pending` est celui que le cahier
/// des charges n'avait pas prévu : le paiement est parti, l'opérateur n'a pas
/// encore confirmé — l'écran le dit au lieu d'annoncer un succès.
class PaymentDetailScreen extends ConsumerWidget {
  const PaymentDetailScreen({
    super.key,
    required this.paymentId,
    this.notificationId,
  });

  final String paymentId;

  /// Présent quand l'écran est ouvert depuis une notification (paramètre
  /// `depuis_notification` de l'URL) : affiche alors le lien « Supprimer la
  /// notification » de l'écran 08.
  final String? notificationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = ref.watch(paymentProvider(paymentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showNotificationPreferencesStub(context),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: AsyncView(
          value: payment,
          onRetry: () => ref.invalidate(paymentProvider(paymentId)),
          data: (p) => _Body(payment: p, notificationId: notificationId),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.payment, this.notificationId});

  final Payment payment;
  final String? notificationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final (icon, tint, headline, message, statusLabel) = switch (payment.status) {
      PaymentStatus.confirmed => (
          Icons.check,
          AppColors.success,
          'confirmé',
          'Votre paiement${_forInvoice()} a été vérifié et confirmé. Votre '
              'connexion reste active et aucun frais supplémentaire n\'a été '
              'appliqué.',
          'Succès',
        ),
      PaymentStatus.pending => (
          Icons.schedule,
          AppColors.warning,
          'en cours de vérification',
          'Votre justificatif${_forInvoice()} a bien été transmis à A2 Connect. '
              'La vérification par ${payment.method} peut prendre quelques '
              'minutes — vous recevrez une notification dès qu\'elle arrive.',
          'En cours',
        ),
      PaymentStatus.refused => (
          Icons.close,
          AppColors.danger,
          'refusé',
          'Le justificatif transmis${_forInvoice()} n\'a pas pu être validé. '
              'Vérifiez le montant et la capture d\'écran, puis envoyez un '
              'nouveau justificatif.',
          'Échec',
        ),
      PaymentStatus.unknown => (
          Icons.help_outline,
          AppColors.textSecondary,
          'à vérifier',
          'Le statut de ce paiement n\'a pas pu être déterminé. Contactez le '
              'service client si le montant a été débité.',
          'Inconnu',
        ),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.xl,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      children: [
        Center(
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Paiement de ${Fmt.money(payment.amount)}',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 27,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              Fmt.dateTimeLong(payment.date),
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        AppCard(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('Référence'),
                        const SizedBox(height: 6),
                        Text(
                          payment.reference,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SectionLabel('Statut'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 9, color: tint),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                              color: tint,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Expanded(child: SectionLabel('Moyen de paiement')),
                  Text(
                    payment.method,
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (payment.invoiceId != null)
          ElevatedButton.icon(
            onPressed: () => context.push(Routes.invoice(payment.invoiceId!)),
            icon: const Icon(Icons.open_in_new, size: 19),
            label: const Text('Voir la facture'),
          ),

        if (payment.status == PaymentStatus.pending) ...[
          const SizedBox(height: AppSpacing.sm + 4),
          OutlinedButton.icon(
            onPressed: () {
              ref.invalidate(paymentProvider(payment.id));
              ref.invalidate(paymentsProvider);
            },
            icon: const Icon(Icons.refresh, size: 19),
            label: const Text('Actualiser le statut'),
          ),
        ],

        if (payment.status == PaymentStatus.refused) ...[
          const SizedBox(height: AppSpacing.sm + 4),
          OutlinedButton.icon(
            onPressed: () =>
                context.push(Routes.pay(invoiceId: payment.invoiceId)),
            icon: const Icon(Icons.replay, size: 19),
            label: const Text('Envoyer un nouveau justificatif'),
          ),
        ],

        if (notificationId != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                await ref
                    .read(notificationsProvider.notifier)
                    .delete(notificationId!);
                if (context.mounted) context.pop();
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Supprimer la notification'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }

  String _forInvoice() => payment.invoicePeriodLabel == null
      ? ''
      : ' pour la facture de ${payment.invoicePeriodLabel}';
}
