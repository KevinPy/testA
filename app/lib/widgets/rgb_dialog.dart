import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Modale « Je crée ma couleur ».
///
/// Trois curseurs RVB, gros et colorés. Chaque rail montre déjà le résultat du
/// déplacement : un enfant qui ne sait pas lire comprend ce que fait le curseur
/// rien qu'en le regardant. La valeur hexadécimale est affichée en petit, pour
/// le parent.
class RgbColorDialog extends StatefulWidget {
  const RgbColorDialog({super.key, this.initial = const Color(0xFFE23B3B)});

  final Color initial;

  static Future<Color?> show(BuildContext context, {Color? initial}) {
    return showDialog<Color>(
      context: context,
      builder: (BuildContext context) =>
          RgbColorDialog(initial: initial ?? const Color(0xFFE23B3B)),
    );
  }

  @override
  State<RgbColorDialog> createState() => _RgbColorDialogState();
}

class _RgbColorDialogState extends State<RgbColorDialog> {
  late double _r = (widget.initial.r * 255).roundToDouble();
  late double _g = (widget.initial.g * 255).roundToDouble();
  late double _b = (widget.initial.b * 255).roundToDouble();

  Color get _color =>
      Color.fromARGB(255, _r.round(), _g.round(), _b.round());

  String get _hex =>
      '#${_r.round().toRadixString(16).padLeft(2, '0')}'
              '${_g.round().toRadixString(16).padLeft(2, '0')}'
              '${_b.round().toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Je crée ma couleur',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: 32,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: _color,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ink, width: 5),
                      boxShadow: kSoftShadow,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _hex,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A857F),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _ChannelSlider(
                  label: 'Rouge',
                  emoji: '🔴',
                  value: _r,
                  gradient: <Color>[
                    Color.fromARGB(255, 0, _g.round(), _b.round()),
                    Color.fromARGB(255, 255, _g.round(), _b.round()),
                  ],
                  onChanged: (double v) => setState(() => _r = v),
                ),
                _ChannelSlider(
                  label: 'Vert',
                  emoji: '🟢',
                  value: _g,
                  gradient: <Color>[
                    Color.fromARGB(255, _r.round(), 0, _b.round()),
                    Color.fromARGB(255, _r.round(), 255, _b.round()),
                  ],
                  onChanged: (double v) => setState(() => _g = v),
                ),
                _ChannelSlider(
                  label: 'Bleu',
                  emoji: '🔵',
                  value: _b,
                  gradient: <Color>[
                    Color.fromARGB(255, _r.round(), _g.round(), 0),
                    Color.fromARGB(255, _r.round(), _g.round(), 255),
                  ],
                  onChanged: (double v) => setState(() => _b = v),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(_color),
                    icon: const Icon(Icons.check_rounded, size: 30),
                    label: const Text(
                      'Ajouter à ma palette',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Curseur d'un canal RVB.
///
/// Dessiné à la main plutôt que via `Slider` : il faut un rail épais montrant
/// le dégradé du canal et une pastille large, préhensible par un doigt d'enfant.
/// Le rail EST l'explication — on voit la couleur que donnera chaque position.
class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    required this.label,
    required this.emoji,
    required this.value,
    required this.gradient,
    required this.onChanged,
  });

  final String label;
  final String emoji;
  final double value;
  final List<Color> gradient;
  final ValueChanged<double> onChanged;

  static const double _knob = 20;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 104,
            child: Row(
              children: <Widget>[
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final double span = c.maxWidth - _knob * 2;
                void update(double dx) =>
                    onChanged((((dx - _knob) / span).clamp(0.0, 1.0)) * 255);

                return Semantics(
                  slider: true,
                  label: label,
                  value: '${value.round()}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (TapDownDetails d) => update(d.localPosition.dx),
                    onHorizontalDragStart: (DragStartDetails d) =>
                        update(d.localPosition.dx),
                    onHorizontalDragUpdate: (DragUpdateDetails d) =>
                        update(d.localPosition.dx),
                    child: SizedBox(
                      height: 52,
                      child: CustomPaint(
                        painter: _ChannelPainter(
                          t: value / 255,
                          gradient: gradient,
                          knob: _knob,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${value.round()}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelPainter extends CustomPainter {
  const _ChannelPainter({
    required this.t,
    required this.gradient,
    required this.knob,
  });

  final double t;
  final List<Color> gradient;
  final double knob;

  @override
  void paint(Canvas canvas, Size size) {
    const double trackHeight = 26;
    final Rect track = Rect.fromLTWH(
      0,
      (size.height - trackHeight) / 2,
      size.width,
      trackHeight,
    );
    final RRect rrect =
        RRect.fromRectAndRadius(track, const Radius.circular(trackHeight / 2));

    canvas
      ..drawRRect(
        rrect,
        Paint()..shader = LinearGradient(colors: gradient).createShader(track),
      )
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = AppColors.ink.withValues(alpha: 0.22),
      );

    final double cx = knob + t * (size.width - knob * 2);
    final Offset center = Offset(cx, size.height / 2);
    final Color current = Color.lerp(gradient.first, gradient.last, t)!;

    canvas
      ..drawCircle(
        center,
        knob + 1,
        Paint()
          ..color = AppColors.shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawCircle(center, knob, Paint()..color = Colors.white)
      ..drawCircle(
        center,
        knob,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppColors.ink,
      )
      ..drawCircle(center, knob - 7, Paint()..color = current);
  }

  @override
  bool shouldRepaint(_ChannelPainter old) =>
      old.t != t || old.gradient != gradient;
}
