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

/// Écran 07 : l'historique des paiements.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  /// Filtre local sur le statut. `null` = tout afficher.
  PaymentStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payments = ref.watch(paymentsProvider);
    final total = ref.watch(paidThisMonthProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Historique des paiements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push(Routes.notifications),
          ),
          PopupMenuButton<PaymentStatus?>(
            icon: Icon(
              Icons.filter_list,
              color: _filter == null ? AppColors.textPrimary : AppColors.primary,
            ),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Tous')),
              for (final s in [
                PaymentStatus.confirmed,
                PaymentStatus.pending,
                PaymentStatus.refused,
              ])
                PopupMenuItem(value: s, child: Text(s.label)),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(paymentsProvider);
            await ref.read(paymentsProvider.future).catchError((_) => <Payment>[]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.md,
              AppSpacing.screen,
              AppSpacing.xl,
            ),
            children: [
              AppCard.highlighted(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Total payé ce mois'),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: FittedBox(
                            child: Text(
                              Fmt.amount(total),
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontSize: 42,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          Fmt.currency,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transactions récentes',
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(Routes.pay()),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Nouveau paiement'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              AsyncView(
                value: payments,
                onRetry: () => ref.invalidate(paymentsProvider),
                loading: const Column(
                  children: [
                    SkeletonBox(height: 92),
                    SizedBox(height: AppSpacing.sm + 4),
                    SkeletonBox(height: 92),
                    SizedBox(height: AppSpacing.sm + 4),
                    SkeletonBox(height: 92),
                  ],
                ),
                data: (all) {
                  final list = _filter == null
                      ? all
                      : all.where((p) => p.status == _filter).toList();

                  if (list.isEmpty) {
                    return EmptyView(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Aucun paiement',
                      message: _filter == null
                          ? 'Vos règlements apparaîtront ici.'
                          : 'Aucun paiement « ${_filter!.label} » sur la période.',
                    );
                  }

                  return Column(
                    children: [
                      for (final payment in list) ...[
                        _PaymentTile(payment: payment),
                        const SizedBox(height: AppSpacing.sm + 4),
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

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.push(Routes.payment(payment.id)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: const Icon(Icons.payments_outlined, color: Colors.white, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Fmt.dateLong(payment.date),
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 16.5),
                ),
                Text(
                  'Réf: ${payment.reference}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14.5,
                  ),
                ),
                Text(
                  payment.method,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.money(payment.amount),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              StatusPill.payment(payment.status),
            ],
          ),
        ],
      ),
    );
  }
}
