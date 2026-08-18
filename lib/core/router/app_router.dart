import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/providers.dart';
import '../../features/auth/login_screen.dart';
import '../../features/blocking/blocking_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/invoices/invoice_detail_screen.dart';
import '../../features/invoices/invoices_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/payments/pay_screen.dart';
import '../../features/payments/payment_detail_screen.dart';
import '../../features/payments/payments_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';

abstract final class Routes {
  static const splash = '/';
  static const welcome = '/bienvenue';
  static const login = '/connexion';
  static const home = '/accueil';
  static const invoices = '/factures';
  static const payments = '/paiements';
  static const blocking = '/blocage';
  static const notifications = '/notifications';

  static String invoice(String id) => '$invoices/$id';
  static String payment(String id) => '$payments/$id';

  /// Écran de règlement. Sans facture, c'est un paiement libre.
  static String pay({String? invoiceId}) =>
      invoiceId == null ? '/regler' : '/regler?facture=$invoiceId';
}

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,

    /// Garde d'accès : tant que la session n'est pas connue on reste sur le
    /// splash, et une fois connue on ne peut ni voir les écrans internes sans
    /// être connecté, ni revenir à la connexion en l'étant.
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.matchedLocation;

      if (session.isLoading) {
        return path == Routes.splash ? null : Routes.splash;
      }

      final loggedIn = session.value != null;
      final onAuthFlow = path == Routes.splash ||
          path == Routes.welcome ||
          path == Routes.login;

      if (!loggedIn) return onAuthFlow ? null : Routes.welcome;
      if (onAuthFlow) return Routes.home;
      return null;
    },

    // Le routeur se réévalue dès que l'état de session change (connexion,
    // déconnexion, expiration détectée par un appel).
    refreshListenable: _SessionListenable(ref),

    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/regler',
        builder: (_, state) => PayScreen(
          invoiceId: state.uri.queryParameters['facture'],
        ),
      ),

      // Les quatre onglets. Chacun garde sa propre pile de navigation :
      // ouvrir une facture puis changer d'onglet et revenir doit rendre
      // l'écran tel qu'on l'avait laissé.
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.home,
              builder: (_, __) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.invoices,
              builder: (_, __) => const InvoicesScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) =>
                      InvoiceDetailScreen(invoiceId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.payments,
              builder: (_, __) => const PaymentsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) =>
                      PaymentDetailScreen(paymentId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.blocking,
              builder: (_, __) => const BlockingScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

/// Pont entre Riverpod et go_router : notifie le routeur à chaque changement
/// d'état de session.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
  }
}
