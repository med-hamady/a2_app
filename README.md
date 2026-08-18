# A2 Connect — application client (Flutter)

Espace client mobile d'A2 Connect : abonnement, état du réseau, factures,
paiements et blocage des plateformes.

L'application est un **client d'API pur** : aucune logique métier n'est
implémentée ici, tout vient du backend. C'est le périmètre fixé par le §3 du
cahier des charges.

---

## État actuel

Toute l'interface est développée et fonctionne **contre une API factice**
(`MockA2Api`), en attendant la documentation de l'API réelle. Les écrans sont
calés sur les maquettes du dossier [`Archive/`](Archive/).

| Écran | Maquette | Fichier |
|---|---|---|
| Démarrage | 01 | `lib/features/splash/` |
| Bienvenue | 02 | `lib/features/onboarding/` |
| Connexion | 03 | `lib/features/auth/` |
| Tableau de bord | 04 | `lib/features/dashboard/` |
| Liste des factures | 05 | `lib/features/invoices/invoices_screen.dart` |
| Détail d'une facture | 06 | `lib/features/invoices/invoice_detail_screen.dart` |
| Historique des paiements | 07 | `lib/features/payments/payments_screen.dart` |
| Détail d'un paiement | 08 | `lib/features/payments/payment_detail_screen.dart` |
| Blocage des plateformes | 09 / 10 | `lib/features/blocking/` |
| Notifications (liste + vide) | 11 / 12 | `lib/features/notifications/` |
| **Effectuer un paiement** | *aucune* | `lib/features/payments/pay_screen.dart` |

Le parcours de paiement n'était pas dessiné : il a été composé avec la même
charte, et reste à valider avec A2 Connect une fois le canal de paiement arrêté.

---

## Démarrer

```bash
flutter pub get
flutter run                 # données factices
flutter test                # tests de la couche de données
flutter analyze
```

### Basculer sur le vrai backend

Un seul interrupteur, aucune modification d'écran :

```bash
flutter run \
  --dart-define=USE_MOCK=false \
  --dart-define=API_BASE_URL=https://api.a2connect.mr/v1
```

### Compte de démonstration

N'importe quel numéro à 8 chiffres et n'importe quel identifiant client
ouvrent une session. L'identifiant **`0000`** déclenche volontairement l'erreur
de connexion, pour montrer cet état.

---

## Architecture

```
lib/
  core/          thème, routeur, formats, widgets partagés
  data/
    models/      modèles + conversion JSON tolérante
    api/
      a2_api.dart      LE CONTRAT — ce que l'app attend du backend
      mock_api.dart    données factices
      remote_api.dart  vrais appels HTTP (à caler sur la doc)
    providers/   état applicatif (Riverpod)
  features/      un dossier par écran
```

Le point central est [`lib/data/api/a2_api.dart`](lib/data/api/a2_api.dart) :
l'interface que toute l'application consomme. Deux implémentations
interchangeables derrière, choisies par `AppConfig.useMock`. **Aucun écran ne
sait laquelle tourne** — c'est ce qui rend le branchement de l'API réelle
mécanique.

Stack : Riverpod (état), go_router (navigation), Dio (HTTP),
flutter_secure_storage (jeton), google_fonts, intl.

---

## À faire quand la documentation de l'API arrivera

Le travail se limite à quatre points, tous dans `lib/data/`.

1. **Les chemins** — classe `_Paths` en bas de `remote_api.dart`.
2. **Les noms de champs JSON** — les `fromJson` de `lib/data/models/models.dart`.
3. **Les libellés de statut** — les `fromApi` de `lib/data/models/enums.dart`
   (une valeur inconnue retombe sur un cas neutre, jamais un crash).
4. **Le transport du jeton** — `RemoteA2Api.setToken` suppose
   `Authorization: Bearer`. À confirmer.

---

## Points ouverts côté A2 Connect

Repris de l'analyse du cahier des charges, ce sont les décisions qui manquent
encore et qui touchent le code :

- **Paiement** : quel canal, et la réponse est-elle immédiate ou différée ?
  L'app gère déjà le cas « en attente » et envoie une clé d'idempotence
  (`Idempotency-Key`) — le backend doit l'honorer, sinon un double appui
  débite deux fois.
- **Connexion** : téléphone + identifiant client figurent tous deux sur la
  facture. Sans code personnel ni OTP, ce n'est pas une authentification forte.
  Le parcours « identifiant oublié » n'existe pas non plus.
- **Abonné coupé pour impayé** : il doit pouvoir atteindre l'app pour payer.
  Le domaine de l'API doit rester joignable depuis une connexion bloquée.
- **Certificat TLS** : l'API doit être servie sur un nom de domaine avec un
  certificat reconnu. Un certificat auto-signé est rejeté à la publication sur
  les stores.
- **Polices** : `google_fonts` les télécharge au premier lancement. À
  embarquer dans `assets/fonts/` avant la mise en production.
- **Logo** : l'asset officiel est en place (récupéré sur a2connect.mr,
  `assets/images/`), mais c'est un **PNG de 3768 px**. Demander le vectoriel
  (SVG/AI) à A2 Connect pour un rendu net sans image lourde.
- **Notifications push** : hors cahier des charges. Seul le journal
  in-app est implémenté.
- **iOS** : la plateforme est générée, mais rien n'a été testé dessus.
