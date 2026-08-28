import 'package:flutter/material.dart';

import '../atelier/creation_store.dart';
import '../data/pages.g.dart';
import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../models/paint_op.dart';
import '../state/artwork_controller.dart';
import '../state/palette_store.dart';
import '../state/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork_painter.dart';
import 'atelier_screen.dart';
import 'coloring_screen.dart';
import 'settings_sheet.dart';

/// La galerie : première chose que voit l'enfant. Grandes vignettes, filtres
/// par catégorie avec émojis, aucun texte indispensable à la navigation.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    required this.store,
    required this.settings,
    required this.creations,
  });

  final PaletteStore store;
  final SettingsStore settings;
  final CreationStore creations;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  /// Le filtre courant : `null` = tout, [_kMine] = les coloriages commencés,
  /// sinon l'identifiant d'une catégorie. On stocke l'identifiant et non le
  /// libellé, sinon changer de langue perdrait la sélection.
  String? _filter;

  static const String _kMine = '__mine__';

  static const Map<String, String> _emoji = <String, String>{
    'animaux': '🐾',
    'vehicules': '🚗',
    'nature': '🌳',
    'gourmandises': '🍰',
    kAtelierCategory: '✏️',
  };

  /// Les créations d'abord : ce que l'enfant vient de dessiner passe avant la
  /// bibliothèque livrée.
  List<ColoringPage> get _allPages =>
      <ColoringPage>[...widget.creations.pages, ...kColoringPages];

  List<String> get _categoryIds {
    final List<String> ids = <String>[];
    for (final ColoringPage p in _allPages) {
      if (!ids.contains(p.category)) ids.add(p.category);
    }
    return ids;
  }

  List<ColoringPage> get _visible => switch (_filter) {
        null => _allPages,
        _kMine => _allPages
            .where((ColoringPage p) => widget.store.hasArtwork(p.id))
            .toList(),
        final String id =>
          _allPages.where((ColoringPage p) => p.category == id).toList(),
      };

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[widget.store, widget.creations]),
          builder: (BuildContext context, _) {
            final List<ColoringPage> pages = _visible;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Header(
                  settings: widget.settings,
                  onAtelier: _openAtelier,
                ),
                SizedBox(
                  height: 68,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: <Widget>[
                      _CategoryChip(
                        label: s.categoryAll,
                        emoji: '🎨',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      for (final String id in _categoryIds)
                        _CategoryChip(
                          label: id == kAtelierCategory
                              ? s.categoryAtelier
                              : s.category(id),
                          emoji: _emoji[id] ?? '🎨',
                          selected: _filter == id,
                          onTap: () => setState(() => _filter = id),
                        ),
                      _CategoryChip(
                        label: s.categoryMine,
                        emoji: '⭐',
                        selected: _filter == _kMine,
                        onTap: () => setState(() => _filter = _kMine),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: pages.isEmpty
                      ? _EmptyMine(message: s.emptyMine)
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
                                onDelete: pages[i].category == kAtelierCategory
                                    ? () => _confirmDelete(pages[i])
                                    : null,
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

  Future<void> _openAtelier() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AtelierScreen(
          store: widget.store,
          creations: widget.creations,
        ),
      ),
    );
    if (mounted) setState(() => _filter = kAtelierCategory);
  }

  /// Supprimer passe par une confirmation : un dessin d'enfant ne disparaît pas
  /// sur un appui long involontaire.
  Future<void> _confirmDelete(ColoringPage page) async {
    final AppStrings s = AppStrings.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(s.deleteDrawingTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(s.deleteDrawingBody,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.keep,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.delete,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok ?? false) await widget.creations.delete(page.id);
  }

  Future<void> _open(ColoringPage page) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ColoringScreen(
          page: page,
          store: widget.store,
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.settings, required this.onAtelier});

  final SettingsStore settings;
  final VoidCallback onAtelier;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool compact = c.maxWidth < 620;
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
                      s.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: compact ? 28 : 38,
                            color: AppColors.primary,
                          ),
                    ),
                    Text(
                      s.galleryTagline,
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
              _AtelierButton(compact: compact, onTap: onAtelier),
              const SizedBox(width: 8),
              _SettingsButton(settings: settings),
            ],
          ),
        );
      },
    );
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.page,
    required this.store,
    required this.onOpen,
    this.onDelete,
  });

  final ColoringPage page;
  final PaletteStore store;
  final VoidCallback onOpen;

  /// Renseigné uniquement pour les créations : la bibliothèque livrée ne se
  /// supprime pas.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final String title = page.title.resolve(s.locale);
    final String? saved = store.artworkFor(page.id);
    final List<PaintOp> ops =
        saved == null ? const <PaintOp>[] : ArtworkController.decodeOps(saved);

    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onOpen,
        onLongPress: onDelete,
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
                          child: Text(
                            '⭐ ${s.badgeStarted}',
                            style: const TextStyle(
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
                        title,
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

/// L'espace parents. Discret, à côté de l'Atelier, et derrière la porte
/// d'appui maintenu : c'est la règle posée pour tous les réglages.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Semantics(
      button: true,
      label: s.settings,
      child: Tooltip(
        message: s.settings,
        child: GestureDetector(
          onTap: () => SettingsSheet.open(context, settings),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: kSoftShadow,
            ),
            child: const Icon(Icons.tune_rounded, size: 24, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

/// L'entrée de l'Atelier.
class _AtelierButton extends StatelessWidget {
  const _AtelierButton({required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Tooltip(
      message: s.studio,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accent, width: 3),
          boxShadow: kSoftShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 22),
            if (!compact) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                s.studio,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMine extends StatelessWidget {
  const _EmptyMine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('🎨', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
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
