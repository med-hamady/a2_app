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
import '../../core/widgets/status_pill.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';

/// Écran 06 : le détail d'une facture.
class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceProvider(invoiceId));
    final clientId = ref.watch(sessionProvider).value?.clientId ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de la facture'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push(Routes.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined),
            onPressed: () => showSupportSheet(context),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: AsyncView(
          value: invoice,
          onRetry: () => ref.invalidate(invoiceProvider(invoiceId)),
          data: (inv) => _Body(invoice: inv, clientId: clientId),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.invoice, required this.clientId});

  final Invoice invoice;
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subscription = ref.watch(subscriptionProvider).value;
    final unpaid = invoice.status != InvoiceStatus.paid;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      children: [
        AppCard.highlighted(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            children: [
              const SectionLabel('Détail'),
              const SizedBox(height: AppSpacing.lg),
              Text(
                invoice.periodLabel,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
              ),
              Text(
                'Ref: ${invoice.reference}',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionLabel('Total'),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                child: Text(
                  Fmt.money(invoice.amount),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              StatusPill.invoice(invoice.status),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        DetailRow(label: 'Période', value: invoice.periodLabel),
        DetailRow(label: "Date d'émission", value: Fmt.date(invoice.issueDate)),
        DetailRow(label: "Date d'échéance", value: Fmt.date(invoice.dueDate)),
        if (invoice.paidAt != null)
          DetailRow(label: 'Payée le', value: Fmt.date(invoice.paidAt)),
        DetailRow(
          label: 'Abonnement',
          value: subscription?.planName ?? '—',
        ),
        DetailRow(label: 'Identifiant client', value: clientId),

        const SizedBox(height: AppSpacing.lg),

        if (unpaid) ...[
          ElevatedButton(
            onPressed: () => context.push(Routes.pay(invoiceId: invoice.id)),
            child: Text('RÉGLER ${Fmt.money(invoice.amount)}'),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          OutlinedButton.icon(
            onPressed: () => _download(context),
            icon: const Icon(Icons.download, size: 20),
            label: const Text('Télécharger la facture'),
          ),
        ] else
          ElevatedButton.icon(
            onPressed: () => _download(context),
            icon: const Icon(Icons.download, size: 20),
            label: const Text('Télécharger la facture'),
          ),
      ],
    );
  }

  /// Le téléchargement du PDF suppose que l'API expose une URL de facture.
  /// Tant que ce n'est pas confirmé, l'action explique ce qui manque plutôt
  /// que d'échouer silencieusement.
  void _download(BuildContext context) {
    final message = invoice.pdfUrl == null
        ? "Le téléchargement sera disponible dès qu'A2 Connect fournira "
            "l'adresse du PDF dans la réponse de l'API."
        : 'Téléchargement du PDF à brancher (URL fournie par l\'API).';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
