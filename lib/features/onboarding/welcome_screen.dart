import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/common.dart';

/// Écran 02 : la porte d'entrée. Un logo, une promesse, un bouton.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const A2Logo(height: 72),
              const SizedBox(height: AppSpacing.xl + AppSpacing.md),
              Text(
                'Votre espace client\nA2Connect',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 34,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Consultez vos factures, vos paiements et gérez vos services '
                'A2Connect.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SizedBox(
                width: 70,
                child: Divider(color: AppColors.border),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: () => context.go(Routes.login),
                child: const Text('SE CONNECTER'),
              ),
              const Spacer(flex: 4),
            ],
          ),
        ),
      ),
    );
  }
}
