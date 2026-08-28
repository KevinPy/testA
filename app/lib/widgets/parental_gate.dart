import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// La porte d'entrée de l'espace parents.
///
/// Un appui **maintenu deux secondes**, avec la consigne écrite en toutes
/// lettres. Pas de calcul mental : un enfant de 7 ans résout « 7 × 3 », mais
/// aucun enfant de 4 ans ne tient un appui long en lisant une consigne.
///
/// C'est le composant que réutiliseront le partage et l'achat intégré.
class ParentalGate extends StatefulWidget {
  const ParentalGate({super.key});

  static const Duration hold = Duration(milliseconds: 2000);

  /// Ouvre la porte. Résout à `true` si l'appui a été tenu jusqu'au bout.
  static Future<bool> open(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const ParentalGate(),
    );
    return ok ?? false;
  }

  @override
  State<ParentalGate> createState() => _ParentalGateState();
}

class _ParentalGateState extends State<ParentalGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: ParentalGate.hold,
  )..addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop(true);
      }
    });

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(
        s.parentalTitle,
        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
      ),
      content: Text(
        s.parentalInstruction,
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            s.cancel,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        Semantics(
          button: true,
          label: s.parentalHold,
          child: GestureDetector(
            onTapDown: (_) => _progress.forward(),
            onTapUp: (_) => _progress.reverse(),
            onTapCancel: () => _progress.reverse(),
            child: AnimatedBuilder(
              animation: _progress,
              builder: (BuildContext context, _) => Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // La barre de progression remplit le bouton : le parent voit
                    // qu'il se passe quelque chose, et combien de temps reste.
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progress.value,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      s.parentalHold,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
