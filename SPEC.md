# Barbouille — Spécification fonctionnelle

**Application de coloriage pour enfants — iOS, Android, téléphones et tablettes**

| | |
|---|---|
| Version du document | 1.0 |
| Date | 28 août 2026 |
| Statut | Décisions arrêtées — prototype fonctionnel livré |
| Cible | Enfants de 3 à 8 ans, en autonomie ou accompagnés |

---

## 1. Ce qui a été décidé pour vous

Vous m'avez demandé de trancher. Voici les six décisions structurantes, avec
leur justification ; le détail suit dans le corps du document.

| # | Question | Décision | Pourquoi |
|---|---|---|---|
| 1 | Natif ou multiplateforme ? | **Flutter**, un seul code source pour iOS et Android | L'application est à 90 % une surface de dessin sur mesure : les composants natifs n'apporteraient presque rien, alors que deux bases de code coûtent environ le double. Flutter compile en code machine ARM — ce n'est pas une WebView. |
| 2 | Empêcher de déborder, ou colorier sous le trait ? | **Les deux — mais pas au même niveau.** Colorier *sous* le trait noir est le fonctionnement permanent, jamais une option. Le confinement aux zones (« Zones magiques ») est un interrupteur, **activé par défaut**. | Ce sont deux réponses à deux besoins différents (§ 5.5). Les opposer aurait obligé l'enfant à choisir entre « mon trait est propre » et « je fais ce que je veux ». |
| 3 | Format des dessins | **Vectoriel**, pas des images | Zones exactes, aucune « fuite » de pot de peinture, netteté parfaite sur un iPad 12,9", et une bibliothèque qui pèse quelques kilo-octets par dessin au lieu de plusieurs méga-octets. |
| 4 | Compte utilisateur | **Aucun.** Tout est local, hors ligne, sans collecte | Contrainte réglementaire forte sur les applications enfants (§ 10), et un enfant de 4 ans ne crée pas de compte. |
| 5 | Partage (phase 2) | **Feuille de partage du système** (Messages, AirDrop, e-mail). **Pas de galerie publique.** | Une galerie publique impose une modération humaine 24 h/24 et un régime juridique lourd. Repoussé en phase 3, et seulement si l'usage le justifie. |
| 6 | Modèle économique | **Gratuit avec 14 dessins, achat unique pour tout débloquer. Ni publicité, ni abonnement.** | La publicité est proscrite ou très encadrée dans les catégories « Enfants » des deux magasins, et les parents rejettent massivement l'abonnement sur ce segment. |

**Nom retenu : Barbouille.** Court, prononçable par un enfant, disponible, et il
dit ce que fait l'application.

**Langues : français et anglais**, avec un réglage dans l'espace parents
(§ 5.9). Par défaut, l'application suit la langue de l'appareil.

---

## 2. Le produit en une phrase

Une feuille de coloriage qui ne peut pas être ratée : l'enfant barbouille aussi
franchement qu'il le veut, le dessin reste beau.

### 2.1 Utilisateurs

| | Enfant (3–5 ans) | Enfant (6–8 ans) | Parent |
|---|---|---|---|
| Sait lire | Non | En partie | Oui |
| Motricité fine | Faible, gestes amples | Correcte | — |
| Attente | Voir de la couleur apparaître, tout de suite | Réussir un beau dessin, choisir ses couleurs | Que ça s'installe et fonctionne sans lui |
| Conséquence sur l'interface | Zones magiques, grosses cibles, aucun texte indispensable | Mode libre, palette RVB, outils différenciés | Aucun réglage obligatoire, aucun achat accidentel |

### 2.2 Contexte d'usage

Sur le canapé, en voiture, dans une salle d'attente. **L'application doit
fonctionner intégralement hors ligne** et supporter d'être fermée brutalement à
tout instant : la sauvegarde est automatique et permanente (§ 5.7).

---

## 3. Choix technique : Flutter

### 3.1 La décision

Un seul code source Dart, compilé en binaire natif ARM pour iOS et Android.

### 3.2 Pourquoi pas du natif pur (SwiftUI + Jetpack Compose)

Le natif pur se justifie quand l'application vit de composants système :
navigation, listes, formulaires, widgets, intégrations profondes. Barbouille est
l'inverse — **l'écran principal est un canevas dessiné pixel par pixel par nous**.
Les seuls éléments « système » sont la grille de la galerie et une modale.

| Critère | Natif ×2 | **Flutter** | React Native |
|---|---|---|---|
| Charge de développement v1 | 100 % (référence) | **≈ 55 %** | ≈ 65 % |
| Maintenance annuelle | 100 % | **≈ 50 %** | ≈ 60 % |
| Performance du canevas | Excellente | **Excellente** (moteur Impeller, GPU, 60–120 im/s) | Nécessite une passerelle (Skia) — pile plus fragile |
| Risque de divergence iOS/Android | Élevé | **Nul** | Faible |
| Adaptation tablette | 2 × le travail | **1 × le travail** | 1 × le travail |

Flutter l'emporte sur React Native pour ce cas précis : le dessin sur mesure y
est une API de première classe (`CustomPainter`), pas une greffe.

### 3.3 Ce que cela coûte

Deux limites, assumées :

* Les animations d'interface ne sont pas *exactement* celles d'iOS. Sur une
  application au style graphique affirmé comme celle-ci, personne ne le remarque.
* Le binaire pèse environ 8 à 12 Mo de plus qu'un équivalent natif. Sans
  incidence sur le téléchargement perçu.

### 3.4 Socle technique

| | |
|---|---|
| Langage / SDK | Dart, Flutter 3.47 (canal stable) |
| Cibles | iOS 15+ (iPhone 6s et iPad de 2017 et plus récents), Android 8.0+ / API 26 |
| Dépendances externes | `path_drawing` (chemins vectoriels), `shared_preferences` (stockage local), `share_plus` + `path_provider` (enregistrer une image sur téléphone), `web` (téléchargement sur navigateur). `flutter_localizations` fait partie du SDK. |
| Police | Nunito, embarquée dans l'application (licence SIL OFL) — aucun appel réseau |
| Rendu | Impeller (défaut iOS et Android) |

Deux dépendances seulement : chaque bibliothèque tierce est une dette de
maintenance et un risque de conformité sur une application enfants.

---

## 4. Parcours

```
Lancement ─▶ GALERIE ─▶ COLORIAGE ─▶ (retour) ─▶ GALERIE
              │           │
              │           ├─ modale « Je crée ma couleur » (RVB)
              │           └─ modale « Tout effacer ? »
              │
              ├─ 🔒 ESPACE PARENTS ─▶ Langue
              │
              └─ ATELIER (phase 2) ─▶ CRÉATION ─▶ PARTAGE
```

Deux écrans en v1. **Aucun écran d'accueil, aucun tutoriel, aucun réglage
obligatoire** : l'application s'ouvre sur les dessins. L'espace parents (🔒) est
derrière le contrôle parental et ne concerne jamais l'enfant.

---

## 5. Spécification détaillée

### 5.1 Galerie — écran d'accueil

*Capture : `docs/screenshots/01-galerie-tablette.png`*

| Élément | Comportement |
|---|---|
| En-tête | Logo, nom, sous-titre « Choisis ton dessin ! », bouton **Atelier** (phase 2) |
| Filtres | Puces horizontales : `🎨 Tout`, `🐾 Animaux`, `🚗 Véhicules`, `🌳 Nature`, `🍰 Gourmandises`, `⭐ Mes coloriages` |
| Grille | Vignettes d'environ 260 dp. Le nombre de colonnes s'adapte seul : 2 sur téléphone, 4 sur tablette, jusqu'à 6 |
| Vignette | **Rendu en direct de l'œuvre en cours** — pas une image figée. L'enfant retrouve son dessin tel qu'il l'a laissé |
| Badge | `⭐ Commencé` sur tout dessin déjà touché |

Chaque puce porte un émoji : la navigation reste utilisable par un enfant qui ne
lit pas encore.

**Bibliothèque livrée — 14 dessins**

| Animaux | Véhicules | Nature | Gourmandises |
|---|---|---|---|
| Le chat câlin | La voiture rapide | La grande fleur | La glace géante |
| Le poisson rigolo | La fusée de l'espace | Le grand arbre | Le cupcake sucré |
| Le papillon | Le bateau à voile | Ma jolie maison | |
| Le petit dino | Le train qui siffle | | |
| Le hibou de nuit | | | |

Objectif au lancement public : **60 dessins**, soit 5 lots thématiques
(§ 11).

### 5.2 Écran de coloriage

*Captures : `03-coloriage-en-cours.png` (tablette), `09-coloriage-telephone.png`*

**La feuille occupe tout ce que l'écran peut lui donner.** Il n'y a plus de
rails permanents : outils, taille et couleurs vivent dans un **tiroir**, ouvert
par un seul bouton qui porte l'outil et la couleur du moment — l'enfant sait
avec quoi il dessine sans rien ouvrir.

Les commandes restantes flottent **dans les bandes que laisse une feuille carrée
sur un écran qui ne l'est pas**. Elles ne coûtent donc pas un point de surface de
dessin. Une seule règle décide de leur place :

| Marge latérale disponible | Disposition |
|---|---|
| ≥ 92 dp (paysage, tablette) | Deux colonnes dans les bandes gauche et droite |
| < 92 dp (portrait) | Rangée au-dessus de la feuille, bouton d'outils en dessous |

En portrait, les commandes se collent à la feuille plutôt qu'aux bords de
l'écran : des boutons plaqués aux extrémités donneraient une page qui flotte.

**Ce que cela a corrigé.** Sur un iPhone en paysage (852 × 393), les anciennes
barres laissaient au dessin **environ 12 % de l'écran** — il tenait dans un
timbre. La feuille en occupe désormais la plus grande part qu'un carré puisse
prendre dans ce cadre, soit 46 %.

### 5.3 Le tiroir et les quatre outils

Un bouton **« Mes outils »** ouvre un tiroir qui regroupe tout ce qui se choisit :
les quatre outils, les trois épaisseurs, le nuancier et la création de couleur.
Le tiroir défile — en paysage sur téléphone, la hauteur utile descend sous
400 points et le nuancier n'y tiendrait pas d'un bloc.

**L'ouverture par glissement depuis le bord est désactivée** : un trait commencé
au bord gauche de la feuille doit colorier, pas ouvrir le tiroir.


| Outil | Rendu | Rôle |
|---|---|---|
| **Crayon** | Translucide (45 %) et granuleux — trois passes décalées de façon déterministe. Se superpose à lui-même : repasser fonce | Le geste d'atelier, celui qui laisse une matière |
| **Feutre** | Opaque, épaisseur constante, extrémités rondes | Remplir vite et franchement. **Outil par défaut** |
| **Pot de peinture** | Remplit la zone touchée d'un coup | La récompense immédiate. Aucun temps de calcul, aucune fuite (§ 6.2) |
| **Gomme** | Efface la couleur | **Ne peut jamais entamer le trait noir** : le dessin de départ est indestructible |

Trois épaisseurs : **Petit** (18), **Moyen** (46, défaut), **Grand** (96), en
unités de la page (1000 × 1000). Elles suivent donc le zoom et restent
proportionnées sur tous les écrans.

Toutes les cibles tactiles font **72 dp** en rail, **52 dp** minimum en mode
compact — bien au-delà des 44 dp habituels, parce qu'un doigt de 4 ans vise mal.

**Détail d'usage :** choisir une couleur alors que la gomme est active bascule
automatiquement sur le feutre. Un enfant qui touche une couleur veut colorier.

### 5.4 Couleurs

*Capture : `06-modale-rvb.png`*

**24 couleurs d'origine**, choisies pour être nommables par un enfant (« le
rouge », « le vert sapin ») et distinguables deux à deux, y compris en cas de
dyschromatopsie. Trois neutres et un blanc complètent la série.

La pastille sélectionnée **grossit et prend une bague sombre** : l'état
sélectionné ne repose pas uniquement sur la couleur.

**Modale « Je crée ma couleur »** — bouton `+` arc-en-ciel, en tête du nuancier.

* Trois curseurs **Rouge / Vert / Bleu**, de 0 à 255.
* **Chaque rail affiche le dégradé du canal, recalculé en direct** : l'enfant
  voit la couleur que donnera chaque position du curseur. Le rail *est*
  l'explication — aucune notion de « canal » n'est requise.
* Pastille de 132 dp en aperçu, valeur hexadécimale en petit (pour le parent).
* Rails de 26 dp de haut, boutons de 40 dp : préhensibles au doigt.
* `Ajouter à ma palette` enregistre la couleur **définitivement** et la
  sélectionne. Les couleurs créées apparaissent en tête du nuancier, limitées aux
  24 dernières.

Les curseurs sont dessinés sur mesure plutôt que repris de Material : il fallait
un rail épais et coloré, ce que le composant standard ne permet pas.

### 5.5 La décision centrale : déborder ou pas

Vous posiez la question comme une alternative. C'est en réalité **deux
mécanismes distincts**, et il faut les deux.

#### a) Colorier sous le trait noir — permanent, jamais une option

Le rendu se fait en trois couches, dans cet ordre invariable :

```
  3. COUCHE ENCRE     le trait noir du dessin          ← toujours au-dessus
  2. COUCHE COULEUR   tout ce que l'enfant a posé
  1. LE PAPIER        blanc
```

Le trait noir étant redessiné **par-dessus la couleur à chaque image**, l'enfant
colorie en permanence « sous » lui. Quoi qu'il barbouille, le contour reste net.

Ce n'est pas un réglage : c'en faire un aurait signifié proposer un mode où
l'enfant peut saloper le dessin. Personne ne le choisirait volontairement.

*Voir `05-mode-libre.png` : un grand trait bleu traverse tout le chat, et pas un
millimètre de trait noir n'est abîmé — moustaches comprises.*

#### b) Zones magiques — un interrupteur, activé par défaut

Au **poser du doigt**, l'application identifie la zone touchée et **y confine le
trait jusqu'au relâcher**. L'enfant peut gribouiller aussi vite et aussi loin
qu'il veut : seule cette zone se colore.

*Voir `04-zones-magiques.png` : le même gribouillage sauvage, qui ne remplit que
la tête du chat.*

Le point clé est le **verrouillage au poser** — et non un recalcul continu de la
zone sous le doigt. Un enfant qui sort de la tête ne se met pas soudain à
colorier le corps.

| | Zones magiques (défaut) | Mode libre |
|---|---|---|
| Bouton | Vert, `Zones magiques` | Blanc, `Libre` |
| Le trait | Reste dans la zone touchée | Va partout |
| Sous le trait noir | Oui | Oui |
| Pour qui | 3–6 ans, et tout enfant qui veut un résultat net | 6–8 ans, dessin libre, fonds, décors |

Le fond de page compte comme une zone à part entière : on peut colorier *à côté*
du personnage sans déborder *sur* lui.

Le réglage est propre à la séance et **n'est pas mémorisé entre deux dessins** :
il redémarre toujours sur « Zones magiques ». Un parent ne doit jamais trouver
l'application dans un état qu'il n'a pas choisi.

### 5.6 Annuler, refaire, effacer

* `↩︎` / `↪︎` : historique **illimité** sur la séance.
* `🗑️` **Tout effacer** demande confirmation (« Ton dessin redeviendra tout
  blanc »)…
* …et **reste annulable d'un seul appui**. C'est un choix important : un enfant
  qui efface par mégarde son quart d'heure de travail le récupère d'un geste, et
  n'a pas à annuler trait par trait. Techniquement, l'effacement est une
  opération de la pile comme une autre, pas un vidage (§ 6.3).

### 5.7 Sauvegarde

**Automatique, après chaque trait terminé.** Aucun bouton « Enregistrer » :
un enfant ne le chercherait jamais, et fermer l'application ne doit rien coûter.

Le stockage est local (`shared_preferences`), au format JSON compact décrit en
§ 6.3. Un coloriage complexe pèse quelques dizaines de kilo-octets.

### 5.8 Garder son dessin — **livré**

Un bouton 📷 dans la barre supérieure ouvre le **mode capture** : le dessin
seul, en grand, tel qu'il sera enregistré.

**Ce n'est volontairement pas une capture d'écran.** Une vraie capture
embarquerait les barres d'outils, à la résolution de l'écran. L'image est
rendue depuis la liste des opérations, donc à la résolution qu'on veut :
**2048 × 2048**, de quoi imprimer en A4 à 180 points par pouce. Une marge
blanche entoure le dessin — sans elle, un trait qui touche le bord se
retrouverait coupé net contre le cadre.

L'aperçu affiche **l'image réellement encodée**, pas un second rendu à
l'écran : ce que l'enfant voit est exactement le fichier qu'il obtiendra.

| | Où va l'image | Pourquoi |
|---|---|---|
| **Web** | Téléchargement du navigateur | Le geste que le navigateur connaît |
| **iOS / Android** | Feuille de partage du système, qui propose « Enregistrer l'image » | Évite de réclamer la permission « Photos », qu'une application de coloriage n'a aucune autre raison de demander — et qu'Apple scrute dans la catégorie Enfants |

Le nom du fichier est tiré du titre : `barbouille-le-chat-calin.png`. Un parent
qui trie sa galerie doit reconnaître le fichier sans l'ouvrir.

**Décision : regarder est libre, enregistrer passe par le contrôle parental.**
L'écran de capture est la récompense — voir son œuvre encadrée — et reste
accessible à l'enfant. Seul l'enregistrement fait sortir un fichier de
l'application, et suit donc la règle posée en § 10.2. Le bouton reste éteint
sur une page vierge : il n'y a rien à garder.

L'impression (AirPrint / Android Print) reste à faire ; elle repartira du même
PNG.

### 5.9 Langue

**Français et anglais, réglables — automatique par défaut.**

| État | Comportement |
|---|---|
| **Automatique** (défaut) | Suit la langue de l'appareil. Une langue non gérée retombe sur l'**anglais**, convention internationale — le français n'est le bon défaut que sur un appareil français |
| **Français** | Force le français, quel que soit l'appareil |
| **English** | Force l'anglais |

Le réglage vit dans l'**espace parents**, derrière le contrôle parental
(§ 10.2), pour deux raisons : c'est la règle posée pour tous les réglages, et
une application qui bascule en anglais parce qu'un enfant de 4 ans a tapoté un
bouton est un appel au support.

Chaque langue est écrite **dans sa propre langue** — « Français », « English » —
et non traduite. C'est ainsi qu'on la reconnaît quand l'application est
affichée dans une langue qu'on ne lit pas.

**Ce qui est traduit.** L'interface, mais aussi les **titres des dessins** et
les **noms de catégories** : « Le chat câlin » devient « The cuddly cat »,
« Gourmandises » devient « Treats ». Une bibliothèque restée française dans une
application anglaise n'aurait été qu'à moitié traduite. Les titres sont donc
stockés dans les deux langues dans les données générées, et les catégories sont
désormais des **identifiants** (`animaux`, `vehicules`…) dont le libellé est
résolu à l'affichage.

Les trois délégués `flutter_localizations` du SDK sont également installés :
ils traduisent ce que l'application ne rédige pas elle-même — intitulés
d'accessibilité des boîtes de dialogue, indications d'appui long, sens de
lecture.

**Ajouter une langue** coûte une valeur d'énumération, un paramètre nommé
obligatoire de plus dans la fonction de traduction, puis la traduction de
chaque chaîne — que **l'analyseur signale une par une**. C'est délibéré : mieux
vaut une erreur de compilation qu'une chaîne oubliée qui s'affiche en français
dans une application allemande. Environ soixante-dix chaînes, soit une à deux
journées par langue, titres des dessins compris.

---

## 6. Architecture

### 6.1 Organisation

```
app/lib/
├── l10n/          app_strings.dart      ← toutes les chaînes, FR et EN
├── models/        coloring_page.dart · paint_op.dart · tool.dart
├── data/          pages.g.dart          ← généré, ne pas éditer
├── state/         artwork_controller.dart · palette_store.dart
│                  settings_store.dart
├── widgets/       artwork_painter.dart · coloring_canvas.dart
│                  tool_rail.dart · color_tray.dart · rgb_dialog.dart
│                  parental_gate.dart
├── screens/       gallery_screen.dart · coloring_screen.dart
│                  settings_sheet.dart
└── theme/         app_theme.dart
tools/
├── shapes.py      primitives géométriques
├── build_pages.py générateur de la bibliothèque   → data/pages.g.dart
├── seed.mjs       jeux de données pour les captures
└── screenshots.mjs captures automatisées de l'application réelle
```

### 6.2 Format des dessins — et pourquoi il change tout

**Un dessin est un ensemble de formes vectorielles fermées, pas une image.**

```dart
ColoringPage(
  id: 'chat', title: 'Le chat câlin', category: 'Animaux', emoji: '🐱',
  size: Size(1000, 1000),
  regions: [ RegionData('corps', 'M 500 470 C …', hint: 0xFFF6A93B), … ],
  details: [ DetailData('M 250 430 L 90 396'), … ],   // moustaches : encre seule
)
```

L'approche habituelle — une image PNG au trait, plus un remplissage par
propagation au moment du clic — pose quatre problèmes que le vectoriel supprime :

| Problème du raster | Avec le vectoriel |
|---|---|
| Un trait ouvert d'un pixel fait « fuir » la peinture dans tout le dessin | La zone est un contour fermé par construction. Fuite impossible |
| Le remplissage coûte des dizaines de millisecondes sur une grande image | `drawPath` : instantané |
| Il faut plusieurs résolutions pour couvrir téléphone et tablette 12,9" | Un seul fichier, net partout |
| Chaque dessin pèse 1 à 3 Mo | Quelques kilo-octets |

**Profondeur.** L'ordre des zones est l'ordre de profondeur. Deux traitements en
découlent, calculés une fois au chargement :

* **la surface coloriable** d'une zone est son contour *moins* les zones posées
  par-dessus — sans quoi peindre le corps du chat ferait apparaître de la couleur
  derrière sa tête restée blanche ;
* **le trait d'encre** d'une zone est masqué par les zones posées par-dessus — le
  trait d'une oreille s'arrête net au bord de la tête au lieu de la traverser,
  exactement comme dans un album de coloriage.

Le coût est d'une opération booléenne par zone (unions suffixes), au chargement
de la page, mis en cache ensuite.

**Production.** Les dessins sont composés en Python à partir de primitives
(`ellipse`, `smooth`, `petal`, `star`…) et compilés en Dart :

```bash
python3 tools/build_pages.py     # 14 dessins, 155 zones
```

Un illustrateur travaillant sous Illustrator ou Figma exporte en SVG ; un
convertisseur SVG → `pages.g.dart` est à écrire (une demi-journée) pour
industrialiser les lots suivants.

### 6.3 Modèle de l'œuvre

Une œuvre **est la liste ordonnée de ses opérations** — jamais une image.

```dart
sealed class PaintOp
  ├── StrokeOp  outil, couleur, épaisseur, points, zone de confinement, graine
  ├── FillOp    zone, couleur
  └── ClearOp   marqueur « tout effacer »
```

Ce choix donne gratuitement :

* **annuler / refaire** — déplacer un curseur dans la liste ;
* **un effacement annulable** — `ClearOp` est une opération, pas un vidage ;
* **une sauvegarde minuscule** — du JSON, coordonnées arrondies au dixième ;
* **un export à n'importe quelle résolution** — 2048 px pour le partage,
  300 dpi pour l'impression, à partir des mêmes données ;
* **un rejeu identique** — la graine du grain du crayon est stockée avec le
  trait, donc un dessin rouvert est au pixel près celui qui a été fermé.

### 6.4 Rendu

`ArtworkPainter` compose : papier → calque isolé (opérations validées + trait en
cours) → encre. Le calque isolé est ce qui permet à la gomme d'utiliser
`BlendMode.clear` sans jamais atteindre le papier ni le trait noir.

**Points d'attention pour la suite**

* Les opérations sont actuellement rejouées à chaque image. Au-delà d'environ
  1 500 traits, il faudra figer les opérations anciennes dans une `ui.Picture`
  mise en cache. Le point de mesure est prévu (§ 13).
* Un seul pointeur est suivi à la fois : sur tablette, la main posée sur l'écran
  ne doit pas produire un second trait à l'autre bout du dessin.
* Les micro-déplacements (< 2,5 unités) sont filtrés : moins de points, tracé
  plus doux, fichier plus léger.

---

## 7. Adaptation aux écrans

Deux calculs, pas de liste d'appareils : la place de la feuille (le plus grand
carré centré qui tient dans le cadre) et, selon la marge qu'elle laisse, celle
des commandes. La galerie garde sa règle de colonnes.

| | Téléphone portrait | Téléphone paysage | Tablette |
|---|---|---|---|
| Galerie | 2 colonnes | 3–4 | 4–6 |
| Feuille | Ajustée à la largeur | **Toute la hauteur** | Toute la hauteur |
| Outils, taille, couleurs | Tiroir | Tiroir | Tiroir |
| Commandes | Au-dessus et sous la feuille | Colonnes latérales | Colonnes latérales |

**Toutes les orientations sont autorisées** : portrait, paysage gauche et droit
partout, plus le portrait inversé sur tablette — une tablette posée sur une table
tourne dans tous les sens. Le portrait inversé reste désactivé sur iPhone, par
convention de la plateforme.

---

## 8. Accessibilité

* Tous les contrôles portent un libellé VoiceOver / TalkBack (« Zones magiques
  activées », « Couleur », « Rouge 86 sur 255 »).
* Aucune information portée par la seule couleur : la sélection ajoute taille,
  bague et graisse.
* Cibles tactiles de 52 à 72 dp.
* Aucune dépendance à la lecture pour naviguer : émojis et icônes partout.
* Aucun contenu clignotant, aucune animation rapide (risque photosensible).

---

## 9. Sons

**Non implémentés en v1, spécifiés pour la v1.1.** Un enfant de 3 ans a besoin du
retour sonore, mais le son est aussi la première cause de désinstallation par les
parents.

* Sons courts (< 200 ms), doux : dépôt de couleur, pot de peinture, gomme.
* **Coupés par défaut si le téléphone est en mode silencieux.**
* Interrupteur global dans le contrôle parental.
* Aucune musique de fond.

---

## 10. Conformité et vie privée

### 10.1 Position

**Barbouille ne collecte rien.** Pas de compte, pas d'identifiant publicitaire,
pas de télémétrie, pas de service tiers. L'application fonctionne intégralement
hors ligne.

C'est la seule position qui rend triviale la conformité **RGPD**, **COPPA**,
**Apple Kids Category** et **Google Play Families**, et c'est aussi un argument
commercial vis-à-vis des parents.

Conséquence assumée : **aucune mesure d'audience**. Les décisions produit
s'appuieront sur des tests utilisateurs et les avis des magasins.

### 10.2 Contrôle parental

Une porte unique, devant tout ce qui sort de l'application ou coûte de l'argent :
partage, achat, liens externes, réglages.

**Mécanisme** : maintenir un bouton appuyé pendant 2 secondes tout en suivant une
consigne écrite en toutes lettres. Pas de calcul mental : un enfant de 7 ans
résout « 7 × 3 », mais aucun enfant de 4 ans ne tient un appui long en lisant une
consigne. Une barre de progression remplit le bouton pendant l'appui, pour que
le parent voie qu'il se passe quelque chose.

**Déjà implémenté** — il protège le réglage de langue (§ 5.9), et c'est le
composant que réutiliseront le partage et l'achat intégré.

### 10.3 Classification

Apple 4+ · Google « Tout public » · PEGI 3. Aucun contenu généré par des tiers en
v1 et v2 — c'est ce qui permet cette classification.

---

## 11. Modèle économique

| | |
|---|---|
| Téléchargement | Gratuit |
| Inclus | 14 dessins, tous les outils, toutes les couleurs, la palette RVB |
| Achat unique | **« Tout Barbouille » — 4,99 €**, débloque les 60 dessins et les lots à venir |
| Publicité | **Aucune** |
| Abonnement | **Aucun** |

Tout ce qui touche à l'achat passe par le contrôle parental. Aucun élément
verrouillé n'est affiché comme un appât dans le fil de la galerie : les lots
payants sont regroupés dans une section identifiée.

Restauration d'achat obligatoire (exigence Apple) et partage familial activé.

---

## 12. L'Atelier — **livré**

L'objectif : *« créer ses propres dessins et les partager »*. La création est
en place ; le partage reste à faire (§ 12.2).

### 12.1 Créer

Un mode « je dessine le contour » : feutre noir, trois épaisseurs, gomme, fond
blanc. Puis **« Transformer en coloriage »**.

**Le point technique.** Un dessin fait à la main n'est pas vectoriel : il faut
en déduire les zones. Le traitement se fait **sur l'appareil**, à
l'enregistrement, en quatre temps :

1. rendu de l'encre seule dans une image de travail de 512 × 512, fond
   transparent — c'est l'alpha qui distingue le trait du vide ;
2. propagation par zones (*flood fill*) sur les surfaces libres ;
3. **dilatation des étiquettes sous le trait**, pour que deux zones voisines se
   rejoignent au milieu de l'encre. Sans elle, colorier laisserait un liseré
   blanc le long de chaque trait ;
4. **fusion des miettes** — toute zone de moins de 200 pixels ramenés à
   l'échelle rejoint sa voisine la plus partagée. Sans quoi le moindre trait
   tremblant crée des dizaines de zones que le doigt n'atteint pas.

Puis les contours sont suivis **le long des arêtes entre pixels**, simplifiés
(Ramer–Douglas–Peucker), et émis en données de chemin SVG — exactement le format
de la bibliothèque livrée.

**Décision : l'Atelier ne produit donc PAS une carte matricielle**, contrairement
à ce que prévoyait la version 1.0 de ce document. Les zones déduites sont
converties en vecteur, si bien qu'une création se colorie avec le code existant,
sans une ligne de rendu en plus : mêmes outils, mêmes zones magiques, même pot
de peinture. Les **traits**, eux, n'ont jamais quitté le vectoriel : seules les
ZONES passent par l'image.

Deux pièges rencontrés, qui valent d'être notés parce qu'ils ne se voyaient
qu'à l'écran :

* le suivi de contour de Moore, qui saute de centre de pixel en centre de
  pixel, revient sur son point de départ dès le deuxième pas sur une forme
  convexe : toutes les zones rondes se réduisaient à un triangle. Longer les
  arêtes règle le cas sans exception ;
* les trous d'une zone sont tracés explicitement, plutôt que creusés par
  soustraction booléenne. `Path.combine` ne rend pas le même résultat sur le
  moteur web que sur la machine virtuelle Dart, et le fond couvrait alors tout
  le dessin — un test unitaire au vert, un écran faux.

Durée mesurée : moins d'une seconde sur un dessin ordinaire. Le web n'ayant pas
d'isolat, un voile « Je prépare ton coloriage… » couvre le calcul.

### 12.1.1 Ce que voit l'enfant

Feutre noir en trois épaisseurs, gomme, annuler / refaire / tout effacer, puis
un seul bouton : **« En faire un coloriage »**. La création s'ouvre directement
en coloriage — c'est la récompense du travail qui vient d'être fait — et se
range dans **✏️ Mes dessins**.

Le titre est numéroté (« Mon dessin 3 ») plutôt que saisi : à 4 ans on ne tape
pas au clavier, et l'enfant reconnaît son dessin à la vignette. Un appui
maintenu sur une création propose de la supprimer, avec confirmation.

Limite assumée : **40 créations**, stockées localement. Au-delà, le stockage
local n'est plus le bon endroit — l'export de fichiers, prévu avec le partage,
prendra le relais.

### 12.2 Partager

**Décision : la feuille de partage du système, et rien d'autre.**

* **Un coloriage terminé** → PNG, via Messages, e-mail, AirDrop.
* **Un dessin à colorier** → fichier `.barbouille` (le contour + sa carte de
  zones, quelques kilo-octets). Le destinataire qui a l'application l'ouvre et le
  colorie ; les autres voient un PNG.

Pas de galerie publique, pas de compte, pas de serveur. Une galerie publique
d'images produites par des enfants impose une modération humaine permanente, une
procédure de signalement, une conservation de preuves et un régime juridique
lourd — sans rapport avec la valeur apportée en phase 2.

L'accès au partage passe par le contrôle parental.

---

## 13. État du prototype livré

Le dépôt contient une **application Flutter qui fonctionne**, pas une maquette.
Toutes les captures de `docs/screenshots/` sont prises dans l'application réelle,
pilotée automatiquement (`tools/screenshots.mjs`).

### Implémenté et testé

- [x] Galerie, catégories, vignettes rendues en direct, badge « Commencé »
- [x] 14 dessins vectoriels, 155 zones
- [x] Coloriage : crayon, feutre, pot de peinture, gomme × 3 épaisseurs
- [x] **Colorier sous le trait noir** (modèle de rendu permanent)
- [x] **Zones magiques** et **mode libre**, avec verrouillage au poser du doigt
- [x] Fond de page traité comme une zone
- [x] 24 couleurs + modale RVB + palette personnelle persistante
- [x] Annuler / refaire illimités, effacement annulable
- [x] Sauvegarde automatique, reprise à l'identique
- [x] **Mode capture** : export PNG 2048², téléchargement sur web, feuille de partage sur mobile
- [x] **Tiroir d'outils** ; la feuille occupe tout l'écran disponible
- [x] Dispositions téléphone et tablette, toutes orientations, paysage compris
- [x] Libellés d'accessibilité
- [x] **Français et anglais**, interface et titres des dessins, réglable ou automatique
- [x] **Contrôle parental** par appui maintenu, devant les réglages
- [x] 56 tests automatisés (zones, détourage, historique, sérialisation, traductions, disposition, export, Atelier, planche de contrôle des dessins)

### À faire pour la v1 publiable

| # | Chantier | Charge |
|---|---|---|
| 1 | 46 dessins supplémentaires + convertisseur SVG → `pages.g.dart` | 12 j |
| 2 | ~~Export PNG~~ — **livré**. Reste l'impression et le partage | 1 j |
| 3 | ~~Contrôle parental~~ — **livré** | — |
| 4 | Sons | 3 j |
| 5 | Achat intégré + restauration | 4 j |
| 6 | Icône, écran de lancement, fiches des magasins | 3 j |
| 7 | Cache de rendu au-delà de 1 500 traits + mesures sur appareil ancien | 3 j |
| 8 | Tests sur appareils réels (4 iOS, 4 Android) | 4 j |
| 9 | Soumission, allers-retours de validation | 3 j |
| | **Total v1** | **≈ 35 jours · homme** |
| | **Phase 2 — Atelier** | **≈ 25 jours · homme** |

### Lancer le projet

```bash
cd app
flutter pub get
flutter run                     # appareil ou simulateur
flutter test                    # 13 tests
python3 ../tools/build_pages.py # régénérer la bibliothèque de dessins
```

---

## 14. Risques

| Risque | Probabilité | Parade |
|---|---|---|
| Les zones magiques frustrent les 7–8 ans | Moyenne | La bascule est visible en permanence dans la barre supérieure, pas enfouie dans un réglage |
| La détection de zones de l'Atelier produit des résultats sales sur un tracé tremblant | **Élevée** | Fusion des petites régions (§ 12.1) ; à valider par un test utilisateur *avant* de développer le reste de la phase 2 |
| Sans mesure d'audience, on pilote à l'aveugle | Certaine | Assumé (§ 10.1). Tests utilisateurs trimestriels sur 6 à 8 enfants |
| Refus « Kids Category » d'Apple | Faible | Aucune collecte, aucun lien externe hors contrôle parental : les deux causes principales de refus sont écartées d'emblée |
| 60 dessins de qualité constante à produire | Moyenne | Le pipeline vectoriel est en place ; le convertisseur SVG (chantier 1) permet de sous-traiter l'illustration |

---

## 15. Ce que je vous recommande de trancher

Trois points m'appartenaient moins qu'à vous. J'ai pris une décision par défaut
pour ne pas vous bloquer ; chacune se change en une journée.

1. **Le nom.** « Barbouille » est mon choix. À vérifier auprès de l'INPI et sur
   les deux magasins.
2. **Le prix.** 4,99 € en achat unique. La fourchette du marché est 3,99–7,99 €.
3. **Les langues suivantes.** Le français et l'anglais sont livrés (§ 5.9).
   L'espagnol et l'allemand coûteraient une à deux journées chacun, titres des
   dessins compris. À arbitrer selon les marchés visés.
