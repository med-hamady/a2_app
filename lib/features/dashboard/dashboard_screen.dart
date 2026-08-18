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

/// Écran 04 : le tableau de bord.
///
/// Trois blocs indépendants, alimentés par trois appels distincts. Ils se
/// chargent et échouent séparément : une API réseau indisponible ne doit pas
/// vider l'écran de l'abonnement ni celui de la facture.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(subscriptionProvider);
    ref.invalidate(balanceProvider);
    ref.invalidate(networkStatusProvider);
    ref.invalidate(invoicesProvider);
    await Future.wait([
      ref.read(subscriptionProvider.future),
      ref.read(balanceProvider.future),
      ref.read(networkStatusProvider.future),
      ref.read(invoicesProvider.future),
    ]).catchError((_) => <Object>[]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              AppSpacing.xl,
            ),
            children: const [
              _Header(),
              SizedBox(height: AppSpacing.lg),
              _SubscriptionCard(),
              SizedBox(height: AppSpacing.md),
              _NetworkCard(),
              SizedBox(height: AppSpacing.md),
              _LastInvoiceCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Bonjour Ahmed / Votre service est actif », la cloche et le support.
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firstName = ref.watch(sessionProvider).value?.firstName ?? '';
    final subscription = ref.watch(subscriptionProvider).value;
    final unread = ref.watch(unreadCountProvider);

    return Row(
      children: [
        const A2Logo(height: 30),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName.isEmpty ? 'Bonjour' : 'Bonjour $firstName',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                switch (subscription?.status) {
                  SubscriptionStatus.active => 'Votre service est actif',
                  SubscriptionStatus.suspended => 'Votre service est suspendu',
                  SubscriptionStatus.terminated => 'Votre abonnement est résilié',
                  _ => ' ',
                },
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _IconBadge(
          icon: Icons.notifications_none,
          badge: unread > 0,
          onTap: () => context.push(Routes.notifications),
        ),
        _IconBadge(
          icon: Icons.headset_mic_outlined,
          onTap: () => _showSupport(context),
        ),
      ],
    );
  }

  /// Le canal de contact n'est pas défini par le cahier des charges (numéro,
  /// WhatsApp, formulaire ?). En attendant, on affiche un pense-bête.
  void _showSupport(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: InfoBanner(
          text: 'Le canal de contact du service client reste à définir avec '
              'A2 Connect (téléphone, WhatsApp, formulaire).',
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.badge = false, this.onTap});

  final IconData icon;
  final bool badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 26, color: AppColors.textPrimary),
          if (badge)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le solde et les détails de l'abonnement.
class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subscription = ref.watch(subscriptionProvider);
    final balance = ref.watch(balanceProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _BalanceChip(balance: balance)),
              const SizedBox(width: AppSpacing.sm),
              subscription.when(
                data: (s) => StatusPill.subscription(s.status),
                loading: () => const SkeletonBox(height: 34, width: 84),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionLabel("Détails de l'abonnement"),
          const SizedBox(height: AppSpacing.sm + 4),
          AsyncView(
            value: subscription,
            skeletonHeight: 140,
            onRetry: () => ref.invalidate(subscriptionProvider),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.planName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _KeyValueLine(label: 'Prix', value: '${Fmt.money(s.monthlyPrice)} / mois'),
                const SizedBox(height: 6),
                _KeyValueLine(
                  label: 'Prochain renouvellement',
                  value: Fmt.dateLong(s.renewalDate),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    _Chip(icon: Icons.speed, label: s.speedLabel),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Flexible(
                      child: _Chip(icon: Icons.devices, label: s.quotaLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La pastille blanche « 0 MRU (À jour) » / « 12 400 MRU dus ».
class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.balance});

  final AsyncValue<Balance> balance;

  @override
  Widget build(BuildContext context) {
    return balance.when(
      loading: () => const SkeletonBox(height: 52, width: 190),
      error: (_, __) => const SizedBox(height: 52),
      data: (b) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          b.isUpToDate
              ? '${Fmt.money(0)} (À jour)'
              : '${Fmt.money(b.amountDue)} dus',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: b.isUpToDate ? AppColors.textPrimary : AppColors.danger,
              ),
        ),
      ),
    );
  }
}

class _KeyValueLine extends StatelessWidget {
  const _KeyValueLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16.5);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label : ', style: style),
          TextSpan(
            text: value,
            style: style?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: AppColors.textPrimary),
          const SizedBox(width: AppSpacing.sm + 2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// La chaîne CLIENT — MODEM — INTERNET.
class _NetworkCard extends ConsumerWidget {
  const _NetworkCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(networkStatusProvider);

    return AppCard(
      color: AppColors.background,
      child: Column(
        children: [
          const SectionLabel('Statut du réseau'),
          const SizedBox(height: AppSpacing.lg),
          AsyncView(
            value: status,
            skeletonHeight: 120,
            onRetry: () => ref.invalidate(networkStatusProvider),
            data: (s) => Column(
              children: [
                Row(
                  children: [
                    _Node(state: s.client, icon: Icons.smartphone, label: 'Client'),
                    _Connector(
                      state: _worst(s.client, s.modem),
                    ),
                    _Node(state: s.modem, icon: Icons.router_outlined, label: 'Modem'),
                    _Connector(state: _worst(s.modem, s.internet)),
                    _Node(state: s.internet, icon: Icons.wifi, label: 'Internet'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: s.isFullyUp ? AppColors.successBg : AppColors.warningBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 9,
                        color: s.isFullyUp ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        s.label.isEmpty
                            ? (s.isFullyUp ? 'Connexion établie' : 'Connexion perturbée')
                            : s.label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                              color: s.isFullyUp
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Le trait entre deux noeuds prend l'état le plus dégradé des deux.
  static LinkState _worst(LinkState a, LinkState b) {
    const order = [LinkState.down, LinkState.unknown, LinkState.degraded, LinkState.up];
    return order.indexOf(a) <= order.indexOf(b) ? a : b;
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.state, required this.icon, required this.label});

  final LinkState state;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (state) {
      LinkState.up => (AppColors.success, AppColors.successBg),
      LinkState.degraded => (AppColors.warning, AppColors.warningBg),
      LinkState.down => (AppColors.danger, AppColors.dangerBg),
      LinkState.unknown => (AppColors.textSecondary, AppColors.neutralBg),
    };

    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 28, color: fg),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.state});

  final LinkState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      LinkState.up => AppColors.success,
      LinkState.degraded => AppColors.warning,
      LinkState.down => AppColors.danger,
      LinkState.unknown => AppColors.border,
    };
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
        child: Container(height: 3, color: color),
      ),
    );
  }
}

/// « DERNIÈRE FACTURE » — raccourci vers le détail.
class _LastInvoiceCard extends ConsumerWidget {
  const _LastInvoiceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final invoices = ref.watch(invoicesProvider);

    return AppCard(
      color: AppColors.background,
      child: AsyncView(
        value: invoices,
        skeletonHeight: 110,
        onRetry: () => ref.invalidate(invoicesProvider),
        data: (list) {
          final last = list.firstOrNull;
          if (last == null) {
            return const InfoBanner(
              text: 'Aucune facture pour le moment.',
              icon: Icons.description_outlined,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionLabel('Dernière facture')),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                    child: Text(
                      last.reference,
                      style: theme.textTheme.labelMedium?.copyWith(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          last.periodLabel,
                          style: theme.textTheme.titleLarge?.copyWith(fontSize: 19),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Fmt.money(last.amount),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusPill.invoice(last.status, uppercase: false),
                      const SizedBox(height: AppSpacing.md),
                      InkWell(
                        onTap: () => context.push(Routes.invoice(last.id)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Voir le détail',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 15.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.open_in_new, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
