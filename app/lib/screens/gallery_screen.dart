import 'package:flutter/material.dart';

import '../data/pages.g.dart';
import '../models/coloring_page.dart';
import '../models/paint_op.dart';
import '../state/artwork_controller.dart';
import '../state/palette_store.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork_painter.dart';
import 'coloring_screen.dart';

/// La galerie : première chose que voit l'enfant. Grandes vignettes, filtres
/// par catégorie avec émojis, aucun texte indispensable à la navigation.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.store});

  final PaletteStore store;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const String _kAll = 'Tout';
  static const String _kMine = 'Mes coloriages';

  String _category = _kAll;

  List<String> get _categories {
    final List<String> cats = <String>[_kAll];
    for (final ColoringPage p in kColoringPages) {
      if (!cats.contains(p.category)) cats.add(p.category);
    }
    cats.add(_kMine);
    return cats;
  }

  static const Map<String, String> _catEmoji = <String, String>{
    _kAll: '🎨',
    'Animaux': '🐾',
    'Véhicules': '🚗',
    'Nature': '🌳',
    'Gourmandises': '🍰',
    _kMine: '⭐',
  };

  List<ColoringPage> get _visible {
    if (_category == _kAll) return kColoringPages;
    if (_category == _kMine) {
      return kColoringPages
          .where((ColoringPage p) => widget.store.hasArtwork(p.id))
          .toList();
    }
    return kColoringPages
        .where((ColoringPage p) => p.category == _category)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (BuildContext context, _) {
            final List<ColoringPage> pages = _visible;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final bool compact = c.maxWidth < 560;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 16, compact ? 16 : 24, 8),
                      child: Row(
                        children: <Widget>[
                          Text('🖍️', style: TextStyle(fontSize: compact ? 30 : 40)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Barbouille',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        fontSize: compact ? 28 : 38,
                                        color: AppColors.primary,
                                      ),
                                ),
                                Text(
                                  'Choisis ton dessin !',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: compact ? 14 : 17,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF8A857F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CreateSoonButton(compact: compact),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(
                  height: 68,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: <Widget>[
                      for (final String c in _categories)
                        _CategoryChip(
                          label: c,
                          emoji: _catEmoji[c] ?? '🎨',
                          selected: _category == c,
                          onTap: () => setState(() => _category = c),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: pages.isEmpty
                      ? const _EmptyMine()
                      : LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints c) {
                            // Une seule règle d'adaptation : des vignettes
                            // d'environ 260 dp, quel que soit l'appareil.
                            final int columns =
                                (c.maxWidth / 260).floor().clamp(2, 6);
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 18,
                                crossAxisSpacing: 18,
                                childAspectRatio: 0.92,
                              ),
                              itemCount: pages.length,
                              itemBuilder: (BuildContext context, int i) =>
                                  _PageCard(
                                page: pages[i],
                                store: widget.store,
                                onOpen: () => _open(pages[i]),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _open(ColoringPage page) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ColoringScreen(page: page, store: widget.store),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.page,
    required this.store,
    required this.onOpen,
  });

  final ColoringPage page;
  final PaletteStore store;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final String? saved = store.artworkFor(page.id);
    final List<PaintOp> ops =
        saved == null ? const <PaintOp>[] : ArtworkController.decodeOps(saved);

    return Semantics(
      button: true,
      label: page.title,
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: kSoftShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: CustomPaint(
                          painter: ArtworkPainter(
                            page: CompiledPage.of(page),
                            ops: ops,
                            live: null,
                            inkScale: 1.6,
                          ),
                        ),
                      ),
                    ),
                    if (ops.isNotEmpty)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.mint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            '⭐ Commencé',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                color: AppColors.surface,
                child: Row(
                  children: <Widget>[
                    Text(page.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        page.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: kSoftShadow,
          ),
          child: Row(
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Emplacement de l'Atelier (phase 2). Présent dès la v1 pour réserver la place
/// dans la navigation, et derrière un contrôle parental.
class _CreateSoonButton extends StatelessWidget {
  const _CreateSoonButton({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Atelier — bientôt disponible',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent, width: 3),
          boxShadow: kSoftShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 22),
            if (!compact) ...<Widget>[
              const SizedBox(width: 8),
              const Text(
                'Atelier',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyMine extends StatelessWidget {
  const _EmptyMine();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('🎨', style: TextStyle(fontSize: 64)),
          SizedBox(height: 12),
          Text(
            'Aucun coloriage commencé.\nChoisis un dessin pour démarrer !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A857F),
            ),
          ),
        ],
      ),
    );
  }
}
