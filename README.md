# Barbouille 🖍️

Application de coloriage pour enfants de 3 à 8 ans — **iOS et Android**,
téléphones et tablettes. Écrite en Flutter, un seul code source.

> **La spécification fonctionnelle complète est dans [`SPEC.md`](SPEC.md)** :
> décisions produit, architecture, conformité, feuille de route et chiffrage.

![Galerie](docs/screenshots/01-galerie-tablette.png)

## Le principe

Une feuille de coloriage qui ne peut pas être ratée.

**1. On colorie toujours *sous* le trait noir.** Le contour est redessiné
par-dessus la couleur à chaque image : quoi que l'enfant barbouille, le dessin
reste net. Ce n'est pas une option, c'est le fonctionnement.

**2. Les « Zones magiques » empêchent de déborder.** Au poser du doigt, le trait
est confiné à la zone touchée jusqu'au relâcher. Activé par défaut, débrayable
d'un bouton.

![Zones magiques et mode libre](docs/screenshots/10-comparaison-zones.png)

## Fonctionnalités

- Galerie de **14 dessins** vectoriels classés par thème, avec reprise en cours
- **Crayon** (grain de cire), **feutre**, **pot de peinture**, **gomme** × 3 tailles
- **24 couleurs** + création de couleurs en **RVB**, mémorisées
- Annuler / refaire illimités ; « tout effacer » annulable d'un seul appui
- Sauvegarde automatique après chaque trait, reprise à l'identique
- Disposition adaptée au téléphone et à la tablette, dans toutes les orientations
- **Aucun compte, aucune publicité, aucune collecte, fonctionne hors ligne**

![Coloriage en cours](docs/screenshots/03-coloriage-en-cours.png)

## Démarrer

```bash
cd app
flutter pub get
flutter run            # appareil ou simulateur
flutter test           # 13 tests
```

## Organisation du dépôt

```
app/lib/
├── models/     description d'un dessin, opérations de coloriage, outils
├── data/       pages.g.dart — bibliothèque générée, ne pas éditer
├── state/      contrôleur d'œuvre, palette et sauvegarde
├── widgets/    peintre du canevas, barre d'outils, nuancier, modale RVB
├── screens/    galerie, coloriage
└── theme/      couleurs et typographie
tools/
├── shapes.py         primitives géométriques
├── build_pages.py    génère la bibliothèque de dessins
├── seed.mjs          jeux de données pour les captures
└── screenshots.mjs   captures automatisées de l'application réelle
docs/screenshots/     toutes prises dans l'application, jamais des maquettes
```

## Bibliothèque de dessins

Les dessins sont **vectoriels** : chaque zone coloriable est un contour fermé.
Le pot de peinture ne peut pas fuir, le rendu reste net sur une tablette 12,9",
et un dessin pèse quelques kilo-octets.

```bash
python3 tools/build_pages.py     # 14 dessins, 155 zones → app/lib/data/pages.g.dart
```

![Bibliothèque](docs/screenshots/11-bibliotheque.png)

## Regénérer les captures d'écran

Les captures sont prises dans l'application réelle, compilée pour le web et
pilotée par Playwright.

```bash
cd app && flutter build web --release --no-web-resources-cdn
(cd app/build/web && python3 -m http.server 8099 &)
node tools/screenshots.mjs
```

## Licence des ressources

Police **Nunito** — SIL Open Font License 1.1 (`app/assets/fonts/OFL.txt`).
Tous les dessins sont originaux, générés par `tools/build_pages.py`.
