import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';

/// Écrans 11 et 12 : la liste des notifications, et son état vide.
///
/// ⚠️ Il s'agit ici du **journal dans l'application**, alimenté par l'API. Les
/// notifications **push** (bannière hors application) ne sont pas au périmètre
/// du cahier des charges et demandent un service dédié côté backend — à
/// arbitrer avec A2 Connect.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Tout marquer comme lu',
            icon: const Icon(Icons.done_all),
            onPressed: unread == 0
                ? null
                : () => ref.read(notificationsProvider.notifier).markAllRead(),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: AsyncView(
          value: notifications,
          onRetry: () => ref.invalidate(notificationsProvider),
          loading: const Padding(
            padding: EdgeInsets.all(AppSpacing.screen),
            child: Column(
              children: [
                SkeletonBox(height: 92),
                SizedBox(height: AppSpacing.sm + 4),
                SkeletonBox(height: 92),
                SizedBox(height: AppSpacing.sm + 4),
                SkeletonBox(height: 92),
              ],
            ),
          ),
          data: (list) {
            if (list.isEmpty) return const _EmptyState();

            // « RÉCENTS » = les sept derniers jours, « PLUS TÔT » = le reste.
            final cutoff = DateTime.now().subtract(const Duration(days: 7));
            final recent =
                list.where((n) => n.date != null && n.date!.isAfter(cutoff)).toList();
            final earlier = list.where((n) => !recent.contains(n)).toList();
            final unreadCount = list.where((n) => !n.read).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              children: [
                if (recent.isNotEmpty) ...[
                  Row(
                    children: [
                      const Expanded(child: SectionLabel('Récents')),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '$unreadCount NOUVEAU${unreadCount > 1 ? 'X' : ''}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  for (final n in recent) _NotificationTile(notification: n),
                ],
                if (earlier.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const SectionLabel('Plus tôt'),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  for (final n in earlier) _NotificationTile(notification: n),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final n = notification;
    final (icon, tint, bg) = switch (n.kind) {
      NotificationKind.paymentSuccess => (
          Icons.check_circle,
          AppColors.primary,
          AppColors.surfaceMuted,
        ),
      NotificationKind.paymentFailed => (
          Icons.error_outline,
          AppColors.danger,
          AppColors.dangerBg,
        ),
      NotificationKind.accessRestricted => (
          Icons.block,
          AppColors.danger,
          AppColors.dangerBg,
        ),
      NotificationKind.newInvoice => (
          Icons.description_outlined,
          AppColors.primary,
          AppColors.surfaceMuted,
        ),
      NotificationKind.maintenance => (
          Icons.build_outlined,
          AppColors.primary,
          AppColors.surfaceMuted,
        ),
      NotificationKind.info => (
          Icons.info_outline,
          AppColors.primary,
          AppColors.surfaceMuted,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: Dismissible(
        key: ValueKey(n.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 26),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
        ),
        onDismissed: (_) =>
            ref.read(notificationsProvider.notifier).delete(n.id),
        child: Material(
          color: n.read ? Colors.white : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: n.read
                ? null
                : () => ref.read(notificationsProvider.notifier).markRead(n.id),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    child: Icon(icon, size: 22, color: tint),
                  ),
                  const SizedBox(width: AppSpacing.md - 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              Fmt.relative(n.date),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (!n.read) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: const BoxDecoration(
                                  color: AppColors.textSecondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          n.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            height: 1.45,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Écran 12 : l'état vide.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.xl),
        EmptyView(
          icon: Icons.notifications_off_outlined,
          title: 'Aucune notification',
          message: 'Vous êtes à jour ! Nous vous préviendrons dès qu\'il y aura '
              'du nouveau.',
          action: SizedBox(
            width: 260,
            child: ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Les préférences de notification restent à définir avec '
                      'A2 Connect.',
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
              child: const Text('Gérer les préférences'),
            ),
          ),
        ),
      ],
    );
  }
}
