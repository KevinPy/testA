import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../export/artwork_export.dart';
import '../export/save_image.dart';
import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../models/paint_op.dart';
import '../theme/app_theme.dart';
import '../widgets/parental_gate.dart';

/// Le mode capture : le dessin seul, en grand, tel qu'il sera enregistré.
///
/// Regarder son œuvre encadrée est la récompense — cet écran est donc libre
/// d'accès. Seul l'enregistrement, qui fait sortir un fichier de
/// l'application, passe par le contrôle parental.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.page,
    required this.ops,
    required this.title,
  });

  final CompiledPage page;
  final List<PaintOp> ops;
  final String title;

  /// Côté de l'image produite : de quoi imprimer en A4 à 180 points par pouce.
  static const int pixels = 2048;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  Uint8List? _png;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    try {
      final Uint8List bytes = await encodeArtworkPng(
        widget.page,
        widget.ops,
        pixels: CaptureScreen.pixels,
      );
      if (mounted) setState(() => _png = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save() async {
    final Uint8List? bytes = _png;
    if (bytes == null || _saving) return;
    final AppStrings s = AppStrings.of(context);

    if (!await ParentalGate.open(context)) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      await saveArtworkImage(bytes, artworkFileName(widget.title));
      if (mounted) _tell(s.captureDone, AppColors.mint);
    } catch (_) {
      if (mounted) _tell(s.captureFailed, AppColors.accent);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _tell(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: <Widget>[
                  Semantics(
                    button: true,
                    label: s.close,
                    child: Tooltip(
                      message: s.close,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: kSoftShadow,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 28, color: AppColors.ink),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          s.captureSize(CaptureScreen.pixels),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A857F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: Center(child: _Preview(png: _png, error: _error))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: SizedBox(
                height: 68,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                  ),
                  onPressed: _png == null || _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Colors.white),
                        )
                      : const Icon(Icons.download_rounded, size: 30),
                  label: Text(
                    _png == null ? s.captureWorking : s.captureSave,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.png, required this.error});

  final Uint8List? png;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Text(
        AppStrings.of(context).captureFailed,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      );
    }
    if (png == null) {
      return const CircularProgressIndicator(color: AppColors.primary);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: kSoftShadow,
          ),
          clipBehavior: Clip.antiAlias,
          // C'est l'image RÉELLEMENT encodée qui est affichée, pas un second
          // rendu à l'écran : ce que l'enfant voit est exactement le fichier
          // qui sera enregistré.
          child: Image.memory(png!, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
        ),
      ),
    );
  }
}
