import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../state/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/parental_gate.dart';

/// L'espace parents. Un seul réglage pour l'instant : la langue.
///
/// Il est derrière le contrôle parental parce que c'est la règle posée pour
/// tous les réglages — et parce qu'une application qui bascule en anglais sans
/// que le parent l'ait demandé est un appel au support.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.settings});

  final SettingsStore settings;

  /// Passe le contrôle parental, puis ouvre les réglages.
  static Future<void> open(BuildContext context, SettingsStore settings) async {
    if (!await ParentalGate.open(context)) return;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => SettingsSheet(settings: settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: kSoftShadow,
        ),
        child: ListenableBuilder(
          listenable: settings,
          builder: (BuildContext context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      s.settings,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 30,
                    tooltip: s.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  const Icon(Icons.translate_rounded, size: 22, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    s.language,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _LanguageOption(
                title: s.languageAuto,
                detail: s.languageAutoDetail,
                selected: settings.isAutomatic,
                onTap: () => settings.setLocaleChoice(null),
              ),
              for (final AppLocale l in AppLocale.values)
                _LanguageOption(
                  // Le nom de la langue est écrit DANS cette langue : c'est
                  // ainsi qu'on la reconnaît quand on ne lit pas la langue
                  // actuellement affichée.
                  title: l.nativeName,
                  selected: settings.localeChoice == l,
                  onTap: () => settings.setLocaleChoice(l),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.title,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String title;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.surface,
                width: 3,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      if (detail != null)
                        Text(
                          detail!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A857F),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 28,
                  color: selected ? AppColors.primary : const Color(0xFFC4C0BC),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
