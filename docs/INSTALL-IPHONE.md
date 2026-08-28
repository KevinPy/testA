# Installer Barbouille sur un iPhone

Trois chemins, du plus court au plus complet. **Le mode développeur que vous
avez déjà activé est nécessaire dans les trois cas** : il autorise iOS à lancer
une application qui ne vient pas de l'App Store.

---

## Pourquoi le binaire n'est pas construit dans cette session

La chaîne de compilation iOS — SDK, `clang` pour `arm64-ios`, `codesign`,
`xcodebuild` — n'existe que sur macOS et n'est pas redistribuable. Cette session
tourne sous Linux, où `flutter build` ne propose même pas de cible `ios` :

```
$ flutter build --help
  apk    Build an Android APK file from your app.
  web    Build a web application bundle.
```

Le `.ipa` est donc construit par **GitHub Actions sur un exécuteur macOS**
(`.github/workflows/ios.yml`), ce qui revient au même résultat sans exiger que
vous possédiez un Mac.

---

## A. Vous avez un Mac — le chemin le plus direct

Rien à télécharger, Xcode signe tout seul avec votre identifiant Apple.

```bash
git clone https://github.com/KevinPy/testA.git
cd testA/app
git checkout claude/kids-coloring-app-tszz3d

flutter pub get
open ios/Runner.xcworkspace     # Xcode : Runner ▸ Signing & Capabilities
                                # → cocher « Automatically manage signing »
                                # → choisir votre équipe (votre identifiant Apple suffit)
```

iPhone branché en USB, déverrouillé :

```bash
flutter devices                 # vérifie que l'iPhone est vu
flutter run --release           # compile, signe, installe et lance
```

Au premier lancement, iOS refusera l'application tant que vous n'aurez pas
approuvé le certificat : **Réglages ▸ Général ▸ VPN et gestion de l'appareil ▸
[votre identifiant] ▸ Se fier**.

---

## B. Pas de Mac — le `.ipa` par GitHub Actions, puis sideload

### 1. Récupérer le `.ipa`

Le workflow se déclenche à chaque poussée sur la branche, et peut aussi être
lancé à la main : **Actions ▸ « iOS — .ipa non signé » ▸ Run workflow**.

Une fois le travail terminé, l'archive `Barbouille-ipa-non-signe` se télécharge
en bas de la page du run.

### 2. Le signer avec votre identifiant Apple

Le `.ipa` est **non signé** : signer exigerait votre certificat Apple, qui est
personnel et n'a rien à faire dans un système d'intégration continue. La
signature se fait donc sur votre machine, au moment de l'installation.

| Outil | Système | Remarque |
|---|---|---|
| **[Sideloadly](https://sideloadly.io)** | Windows, macOS | Le plus simple : glisser le `.ipa`, saisir son identifiant Apple, brancher l'iPhone |
| **[AltStore](https://altstore.io)** | Windows, macOS | Renouvelle la signature tout seul tant que l'ordinateur est sur le même réseau |
| **[SideStore](https://sidestore.io)** | iPhone seul | Renouvellement depuis l'iPhone, sans ordinateur, après une installation initiale |

Dans les trois cas : identifiant Apple gratuit, aucun compte développeur payant.

### 3. Approuver le certificat sur l'iPhone

**Réglages ▸ Général ▸ VPN et gestion de l'appareil ▸ [votre identifiant] ▸
Se fier.**

### Ce qu'impose un identifiant Apple gratuit

| | Identifiant gratuit | Compte développeur (99 €/an) |
|---|---|---|
| Validité de l'application | **7 jours**, à renouveler | 1 an |
| Applications installées | 3 au maximum | 100 appareils |
| Renouvellement | Rebrancher l'iPhone, ou automatique via AltStore / SideStore | Sans objet |

Les 7 jours sont une limite d'Apple, pas de l'application : au terme, Barbouille
refuse de s'ouvrir jusqu'à ce qu'on la re-signe. Les coloriages en cours, eux,
sont conservés.

---

## C. Tout de suite, sans rien installer — la version web

L'application est compilée pour le web dans la même base de code. Servie en
HTTPS, elle s'ouvre dans Safari et s'ajoute à l'écran d'accueil
(**Partager ▸ Sur l'écran d'accueil**), où elle se lance en plein écran, sans
barre de navigateur.

C'est le moyen le plus rapide de la montrer à un enfant ce soir. Ses limites,
qui sont exactement celles qui justifient le binaire natif :

- le dessin passe par WebKit et non par Impeller — le tracé est un peu moins
  fluide sur les gros aplats ;
- pas de stylet Apple Pencil avec la pression ;
- Safari peut vider le stockage local d'un site peu visité, donc les coloriages
  en cours ne sont pas garantis dans la durée.

```bash
cd app
flutter build web --release --no-web-resources-cdn
# puis servir build/web/ derrière du HTTPS — iOS refuse l'ajout à l'écran
# d'accueil depuis une origine non sécurisée.
```

---

## Dépannage

| Symptôme | Cause | Correctif |
|---|---|---|
| « Impossible de vérifier l'app » | Certificat non approuvé | Réglages ▸ Général ▸ VPN et gestion de l'appareil ▸ Se fier |
| L'application se ferme aussitôt | Mode développeur inactif | Réglages ▸ Confidentialité et sécurité ▸ Mode développeur |
| Après 7 jours, refus d'ouverture | Signature expirée (identifiant gratuit) | Re-signer avec Sideloadly ou AltStore |
| Sideloadly : « Unable to install » | Les 3 applications gratuites sont atteintes | Désinstaller une application sideloadée |
| Le workflow échoue sur `pod install` | Cache CocoaPods de l'exécuteur | Relancer le run ; l'exécuteur repart d'un état propre |
