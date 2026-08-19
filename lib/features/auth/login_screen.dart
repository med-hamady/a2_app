import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../data/providers/providers.dart';

/// Écran 03 : connexion par numéro de téléphone + identifiant client.
///
/// Note de conception à porter au client : deux informations qui figurent
/// toutes deux sur la facture ne constituent pas un secret. Tant qu'aucun code
/// personnel ni OTP n'est en place, l'écran ne peut pas être considéré comme
/// une authentification forte — voir l'analyse du cahier des charges.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _clientId = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _clientId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(sessionProvider.notifier)
        .login(phone: _phone.text.trim(), clientId: _clientId.text.trim());
    // En cas de succès, c'est le routeur qui redirige vers l'accueil : cet
    // écran n'a pas à connaître la suite du parcours.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final busy = session.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          // Centré comme sur la maquette (écran 03) tant que le contenu
          // tient dans la hauteur disponible ; devient défilable dès que le
          // clavier ou un message d'erreur reprend de la place.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen,
                vertical: AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: A2Logo(height: 102)),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Connexion',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Connectez-vous pour gérer votre abonnement A2Connect.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    TextFormField(
                      controller: _phone,
                      enabled: !busy,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Numéro de téléphone',
                      ),
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.isEmpty)
                          return 'Saisissez votre numéro de téléphone.';
                        // Le format exact est à confirmer avec A2 Connect (indicatif
                        // +222 accepté ou non). On reste large pour ne bloquer personne.
                        if (digits.length < 8)
                          return 'Ce numéro semble incomplet.';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md - 4),

                    TextFormField(
                      controller: _clientId,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => busy ? null : _submit(),
                      decoration: const InputDecoration(
                        hintText: 'Identifiant client',
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Saisissez votre identifiant client.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm + 4),

                    Text(
                      'Votre identifiant client figure sur vos factures A2Connect.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    if (session.hasError) ...[
                      const SizedBox(height: AppSpacing.md),
                      ErrorView(error: session.error!, compact: true),
                    ],

                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('SE CONNECTER'),
                                SizedBox(width: AppSpacing.sm + 4),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: busy ? null : () => _showHelp(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          textStyle: theme.textTheme.labelLarge,
                        ),
                        child: const Text("Besoin d'aide ?"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Le parcours « identifiant oublié » n'est pas spécifié par le cahier des
  /// charges. En attendant l'arbitrage d'A2 Connect, on renvoie vers le
  /// service client plutôt que d'inventer une procédure.
  void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
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
              'Besoin d\'aide ?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            const InfoBanner(
              text:
                  'Votre identifiant client figure en haut de chacune de vos '
                  'factures. Si vous ne le retrouvez pas, contactez le service '
                  'client A2 Connect.',
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}
