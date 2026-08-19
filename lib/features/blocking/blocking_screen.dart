import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';

/// Écrans 09 et 10 : le blocage des plateformes.
///
/// Deux points de conception assumés ici, tous deux issus de l'analyse du
/// cahier des charges :
///
///  1. la portée réelle du blocage (**tout le foyer**, **le Wi-Fi seulement**,
///     **contournable**) est écrite dans l'écran, pas cachée — sinon l'abonné
///     appelle le support en croyant à une panne ;
///  2. l'état **« en cours d'application »** existe, parce que l'ordre part
///     vers l'équipement installé chez l'abonné et n'est pas instantané.
class BlockingScreen extends ConsumerWidget {
  const BlockingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platforms = ref.watch(platformsProvider);
    final blocked = ref.watch(blockedCountProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Blocage des plateformes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push(Routes.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showScope(context),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(platformsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.md,
              AppSpacing.screen,
              AppSpacing.xl,
            ),
            children: [
              _HeaderCard(blockedCount: blocked),
              const SizedBox(height: AppSpacing.lg),
              AsyncView(
                value: platforms,
                onRetry: () => ref.invalidate(platformsProvider),
                loading: const Column(
                  children: [
                    SkeletonBox(height: 80),
                    SizedBox(height: AppSpacing.sm + 4),
                    SkeletonBox(height: 80),
                    SizedBox(height: AppSpacing.sm + 4),
                    SkeletonBox(height: 80),
                  ],
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyView(
                      icon: Icons.block,
                      title: 'Aucune plateforme',
                      message: 'Aucune plateforme n\'est proposée au blocage '
                          'pour le moment.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final category in _categories(list)) ...[
                        SectionLabel(
                          category,
                          icon: _iconFor(category),
                        ),
                        const SizedBox(height: AppSpacing.sm + 4),
                        for (final p in list.where((p) => p.category == category)) ...[
                          _PlatformTile(platform: p),
                          const SizedBox(height: AppSpacing.sm + 4),
                        ],
                        const SizedBox(height: AppSpacing.md),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      const InfoBanner(
                        icon: Icons.info_outline,
                        text: 'Le blocage s\'applique à tous les appareils '
                            'connectés à votre Wi-Fi A2Connect. Il ne suit pas '
                            'un appareil qui utilise les données mobiles ou un '
                            'autre réseau.',
                      ),
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

  static List<String> _categories(List<BlockablePlatform> list) {
    final seen = <String>[];
    for (final p in list) {
      if (!seen.contains(p.category)) seen.add(p.category);
    }
    return seen;
  }

  static IconData _iconFor(String category) => switch (category.toLowerCase()) {
        'réseaux sociaux' => Icons.share_outlined,
        'streaming' => Icons.movie_outlined,
        'jeux' => Icons.sports_esports_outlined,
        _ => Icons.apps,
      };

  /// La portée exacte du blocage, en clair. Ce texte est à faire valider par
  /// A2 Connect : c'est un engagement vis-à-vis de l'abonné.
  static void _showScope(BuildContext context) {
    showAppBottomSheet<void>(
      context,
      builder: (_) => Padding(
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
            Text(
              'Comment fonctionne le blocage',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            const InfoBanner(
              icon: Icons.wifi,
              text: 'Le blocage agit sur votre connexion A2Connect. Tous les '
                  'appareils du foyer sont concernés, sans distinction.',
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            const InfoBanner(
              icon: Icons.signal_cellular_alt,
              text: 'Un appareil qui passe par les données mobiles ou par un '
                  'autre Wi-Fi n\'est pas concerné.',
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            const InfoBanner(
              icon: Icons.schedule,
              text: 'La prise en compte peut demander quelques minutes, et '
                  'nécessite que votre équipement soit allumé.',
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('J\'ai compris'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.blockedCount});

  final int blockedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      borderColor: AppColors.primary,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(AppSpacing.lg + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contrôle du réseau',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 27,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Gérez les plateformes accessibles depuis votre connexion A2Connect.',
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16.5, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_list, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$blockedCount plateforme${blockedCount > 1 ? 's' : ''} '
                  'bloquée${blockedCount > 1 ? 's' : ''}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Couleur de marque officielle pour les plateformes connues du mock
/// (écran 09). Repli neutre pour toute clé future non reconnue : le vrai
/// backend pourra ajouter des plateformes sans que l'écran ne casse.
Color _platformColor(String key) => switch (key) {
      'tiktok' => Colors.black,
      'facebook' => const Color(0xFF1877F2),
      'instagram' => const Color(0xFFE1306C),
      'snapchat' => const Color(0xFFFFC800),
      'youtube' => const Color(0xFFFF0000),
      'netflix' => const Color(0xFFE50914),
      'roblox' => Colors.black,
      'freefire' => const Color(0xFFFF6B00),
      _ => AppColors.brand,
    };

/// Vrais logos de marque (SVG officiels, source Simple Icons — CC0, redessin
/// libre de droits des marques déposées, usage standard pour ce genre
/// d'écran « autoriser / bloquer telle app »). `assets/icons/platforms/`.
///
/// Free Fire n'a pas d'équivalent dans un jeu d'icônes libre de droits : pas
/// de logo officiel disponible sans risque de licence, d'où l'icône
/// générique en repli — un choix assumé, pas un oubli.
const _svgLogos = {'tiktok', 'facebook', 'instagram', 'snapchat', 'youtube', 'netflix', 'roblox'};

Widget _platformLogo(String key) {
  if (_svgLogos.contains(key)) {
    return SvgPicture.asset(
      'assets/icons/platforms/$key.svg',
      width: 24,
      height: 24,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }
  final icon = key == 'freefire' ? Icons.local_fire_department : Icons.public;
  return Icon(icon, size: 24, color: Colors.white);
}

class _PlatformTile extends ConsumerWidget {
  const _PlatformTile({required this.platform});

  final BlockablePlatform platform;

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    // Bloquer se confirme (écran 10) ; débloquer non — lever une restriction
    // est un geste anodin, le confirmer n'apporterait rien.
    if (value) {
      final ok = await _confirmBlock(context);
      if (ok != true) return;
    }

    try {
      await ref.read(platformsProvider.notifier).toggle(platform.key, value);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(ErrorView.messageOf(e)),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<bool?> _confirmBlock(BuildContext context) {
    return showAppBottomSheet<bool>(
      context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.block, size: 40),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Bloquer ${platform.label} ?',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Les appareils connectés à votre réseau ne pourront plus '
                'accéder à ${platform.label}.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 16.5,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('Confirmer'),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pending = platform.state == BlockState.pending;
    final failed = platform.state == BlockState.failed;

    return AppCard(
      color: platform.isOn ? AppColors.surface : AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md - 2,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _platformColor(platform.key),
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: _platformLogo(platform.key),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  switch (platform.state) {
                    BlockState.pending => 'Application en cours…',
                    BlockState.failed => 'Non appliqué — équipement injoignable',
                    _ => platform.subtitle,
                  },
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14.5,
                    color: failed
                        ? AppColors.danger
                        : pending
                            ? AppColors.warning
                            : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (pending)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else
            Switch(
              value: platform.isOn,
              onChanged: (v) => _toggle(context, ref, v),
            ),
        ],
      ),
    );
  }
}
