import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// Rend un [AsyncValue] avec les trois états exigés par le cahier des charges
/// (§3 : « chargements, confirmations et messages d'erreur »).
///
/// Un seul endroit décide de la tête que font le chargement et l'erreur dans
/// toute l'application. Les écrans ne s'en occupent plus.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
    this.skeletonHeight = 160,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Rappelé par le bouton « Réessayer ». Sans lui, le bouton n'apparaît pas.
  final VoidCallback? onRetry;

  /// Remplace le squelette par défaut quand un écran a besoin d'une autre
  /// silhouette de chargement.
  final Widget? loading;

  final double skeletonHeight;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () => loading ?? _Skeleton(height: skeletonHeight),
      error: (error, _) => ErrorView(error: error, onRetry: onRetry),
    );
  }
}

/// Le message d'erreur montré à l'abonné.
///
/// On n'affiche jamais une trace technique : soit le message rédigé par
/// [ApiException], soit une phrase générique.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  static String messageOf(Object error) => error is ApiException
      ? error.message
      : 'Une erreur est survenue. Réessayez dans un instant.';

  @override
  Widget build(BuildContext context) {
    final text = messageOf(error);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 22),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.danger,
                        height: 1.4,
                      ),
                ),
              ),
            ],
          ),
          if (onRetry != null && !compact) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// L'écran « il n'y a rien ici », repris de l'écran 12 (aucune notification).
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Bloc gris animé affiché pendant un chargement, à la place du contenu.
///
/// Préféré à un rond qui tourne : la page garde sa forme, donc elle ne saute
/// pas au moment où les données arrivent.
class _Skeleton extends StatefulWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.9).animate(_controller),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
    );
  }
}

/// Version publique du squelette, pour les écrans qui composent leur propre
/// silhouette de chargement (liste de factures, par exemple).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 100, this.width = double.infinity});

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: _Skeleton(height: height),
      );
}
