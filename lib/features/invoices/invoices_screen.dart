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

/// Écran 05 : la liste des factures, précédée du total impayé.
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final invoices = ref.watch(invoicesProvider);
    final unpaid = ref.watch(unpaidTotalProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(invoicesProvider);
            await ref.read(invoicesProvider.future).catchError((_) => <Invoice>[]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.lg,
              AppSpacing.screen,
              AppSpacing.xl,
            ),
            children: [
              const SectionLabel('Total impayé'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                Fmt.money(unpaid),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(width: 92, height: 4, color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),

              AsyncView(
                value: invoices,
                onRetry: () => ref.invalidate(invoicesProvider),
                loading: const Column(
                  children: [
                    SkeletonBox(height: 150),
                    SizedBox(height: AppSpacing.md),
                    SkeletonBox(height: 150),
                    SizedBox(height: AppSpacing.md),
                    SkeletonBox(height: 150),
                  ],
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyView(
                      icon: Icons.description_outlined,
                      title: 'Aucune facture',
                      message: 'Vos factures apparaîtront ici dès leur émission.',
                    );
                  }
                  return Column(
                    children: [
                      for (final invoice in list) ...[
                        _InvoiceCard(invoice: invoice),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une facture. Trois habillages selon le statut, comme sur la maquette :
/// impayée en rouge avec un bouton « Régler », en attente mise en avant en
/// blanc, payée en gris discret.
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = invoice.status == InvoiceStatus.overdue;
    final pending = invoice.status == InvoiceStatus.pending;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.periodLabel,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 21),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ref: ${invoice.reference}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 15.5,
                    ),
                  ),
                ],
              ),
            ),
            StatusPill.invoice(invoice.status),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _leftFooter(theme)),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Fmt.money(invoice.amount),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                if (overdue)
                  ElevatedButton(
                    onPressed: () =>
                        context.push(Routes.pay(invoiceId: invoice.id)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(112, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                    ),
                    child: const Text('Régler'),
                  )
                else
                  _DetailLink(invoice: invoice, pending: pending),
              ],
            ),
          ],
        ),
      ],
    );

    if (overdue) return AppCard.danger(child: content);
    if (pending) return AppCard.highlighted(child: content);
    return AppCard(child: content);
  }

  /// Sous le trait, à gauche : l'échéance, la date de règlement, ou le retard.
  Widget _leftFooter(ThemeData theme) {
    final late = invoice.daysLate;
    if (late != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Retard de $late jour${late > 1 ? 's' : ''}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          Text(
            Fmt.date(invoice.dueDate),
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
          ),
        ],
      );
    }

    final (label, value) = invoice.status == InvoiceStatus.paid
        ? ('Payée le', Fmt.date(invoice.paidAt))
        : ('Échéance', Fmt.date(invoice.dueDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
        ),
      ],
    );
  }
}

class _DetailLink extends StatelessWidget {
  const _DetailLink({required this.invoice, required this.pending});

  final Invoice invoice;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(Routes.invoice(invoice.id)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            pending ? 'Voir le détail' : 'Détails',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17),
          ),
          const SizedBox(width: 6),
          Icon(
            pending ? Icons.arrow_forward : Icons.receipt_long_outlined,
            size: 19,
          ),
        ],
      ),
    );
  }
}
