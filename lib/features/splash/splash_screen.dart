import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';

/// Écran 01 des maquettes : le logo seul, le temps de savoir si une session
/// est déjà ouverte. Le routeur quitte cet écran dès que la réponse est connue.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: A2Logo(height: 78)),
    );
  }
}
