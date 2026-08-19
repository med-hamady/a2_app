import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';

/// Écran 01 des maquettes : le logo seul, animé, le temps que la session
/// soit connue. Le routeur ne quitte cet écran qu'une fois la session
/// résolue ET la durée minimale de présentation écoulée
/// ([AppDurations.splashMinDisplay]) — l'animation ci-dessous a donc toujours
/// le temps de se jouer en entier avant le passage à l'écran de bienvenue.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _breathe;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _breatheScale;

  @override
  void initState() {
    super.initState();

    // Le logo s'installe avec un léger dépassement — une entrée qui a du
    // poids plutôt qu'un simple fondu, sans verser dans l'effet gadget.
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack),
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0, 0.65, curve: Curves.easeOut),
      ),
    );

    // Une fois posé, une respiration discrète signale que l'app travaille
    // encore en arrière-plan — repris du préchargeur du site a2connect.mr,
    // en beaucoup plus subtil.
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _breatheScale = Tween(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _breathe, curve: Curves.easeInOut),
    );

    _entrance.forward().whenComplete(() {
      if (mounted) _breathe.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_entrance, _breathe]),
          builder: (context, child) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value * _breatheScale.value,
              child: child,
            ),
          ),
          child: const A2Logo(height: 78),
        ),
      ),
    );
  }
}
