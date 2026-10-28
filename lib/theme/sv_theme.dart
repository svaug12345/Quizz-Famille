// =============================================================================
// sv_theme.dart — La charte graphique SV traduite en thème Flutter
// -----------------------------------------------------------------------------
// Les valeurs viennent directement du design system « SV » (tokens.json) :
// mêmes noms, mêmes couleurs, en clair et en sombre. Si la charte évolue,
// c'est le seul fichier à modifier.
//
// Polices : Manrope pour le texte, JetBrains Mono pour les chiffres (scores).
// Le paquet google_fonts les télécharge au premier lancement puis les garde.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Les couleurs SV, pour un thème donné (clair ou sombre).
/// On les range dans une « ThemeExtension » : Flutter permet ainsi d'ajouter
/// nos propres couleurs au thème, accessibles partout via context.sv.
class SvColors extends ThemeExtension<SvColors> {
  final Color surface, surfaceRaised, line, ink, inkMuted;
  final Color teal, onTeal, tealDeep, tealSoft, accent, blue, danger;

  const SvColors({
    required this.surface,
    required this.surfaceRaised,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.teal,
    required this.onTeal,
    required this.tealDeep,
    required this.tealSoft,
    required this.accent,
    required this.blue,
    required this.danger,
  });

  /// Thème clair (valeurs « light » de tokens.json)
  static const light = SvColors(
    surface: Color(0xFFF6F9F9),
    surfaceRaised: Color(0xFFFFFFFF),
    line: Color(0xFFD6E2E3),
    ink: Color(0xFF102A2E),
    inkMuted: Color(0xFF4D6468),
    teal: Color(0xFF0F7C7B),
    onTeal: Color(0xFFFFFFFF),
    tealDeep: Color(0xFF0B4F55),
    tealSoft: Color(0xFFD4ECEA),
    accent: Color(0xFF20B2A6),
    blue: Color(0xFF1F5F8B),
    danger: Color(0xFFB23A34),
  );

  /// Thème sombre (valeurs « dark » de tokens.json)
  static const dark = SvColors(
    surface: Color(0xFF0E1A1C),
    surfaceRaised: Color(0xFF152427),
    line: Color(0xFF26393C),
    ink: Color(0xFFE6F1F1),
    inkMuted: Color(0xFF9DB3B5),
    teal: Color(0xFF3CC2B8),
    onTeal: Color(0xFF062022),
    tealDeep: Color(0xFF1D6B6E),
    tealSoft: Color(0xFF1C4245),
    accent: Color(0xFF5FE0D2),
    blue: Color(0xFF6FB0DD),
    danger: Color(0xFFF0857F),
  );

  /// Couleurs des avatars de profils (propres à Quiz'Vacances).
  /// Toutes assez foncées pour porter un emoji et un texte blanc.
  static const profilePalette = [
    Color(0xFF0F7C7B), // sarcelle
    Color(0xFF1F5F8B), // bleu
    Color(0xFFB0581A), // orange brûlé
    Color(0xFF6E4A9E), // violet
    Color(0xFFA8325E), // framboise
    Color(0xFF4A7325), // vert olive
  ];

  static Color profileColor(int index) =>
      profilePalette[index % profilePalette.length];

  // copyWith et lerp sont exigés par Flutter pour les ThemeExtension
  // (lerp sert aux animations de changement de thème).
  @override
  SvColors copyWith() => this;

  @override
  SvColors lerp(SvColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// Raccourci : context.sv.teal au lieu de Theme.of(context).extension<SvColors>()!.teal
extension SvContext on BuildContext {
  SvColors get sv => Theme.of(this).extension<SvColors>()!;
}

/// Style « score » (JetBrains Mono, chiffres de largeur fixe).
TextStyle svScore(BuildContext context, {double size = 24}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: context.sv.ink,
    );

/// Construit le ThemeData complet pour un thème SV.
ThemeData buildSvTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? SvColors.light : SvColors.dark;

  // Le ColorScheme est le jeu de couleurs que les widgets Material utilisent
  // par défaut (boutons, champs, interrupteurs…). On le remplit avec SV.
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.teal,
    onPrimary: c.onTeal,
    primaryContainer: c.tealSoft,
    onPrimaryContainer: c.ink,
    secondary: c.blue,
    onSecondary: c.onTeal,
    error: c.danger,
    onError: c.onTeal,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    surfaceContainerHighest: c.surfaceRaised,
    outline: c.line,
    outlineVariant: c.line,
  );

  // Manrope pour tout le texte, couleur ink.
  final base = GoogleFonts.manropeTextTheme(
    ThemeData(brightness: brightness).textTheme,
  ).apply(bodyColor: c.ink, displayColor: c.ink);

  // Les styles de la charte (display, h1, h2, body, small, label).
  final text = base.copyWith(
    displaySmall: base.displaySmall?.copyWith(
        fontSize: 40, height: 44 / 40, fontWeight: FontWeight.w800, letterSpacing: -0.8),
    headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 32, height: 38 / 32, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleLarge: base.titleLarge?.copyWith(
        fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
    bodySmall: base.bodySmall?.copyWith(
        fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, color: c.inkMuted),
    labelLarge: base.labelLarge?.copyWith(
        fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.0),
  );

  const radiusMd = BorderRadius.all(Radius.circular(12)); // radius-md
  const radiusSm = BorderRadius.all(Radius.circular(6)); // radius-sm

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.surface,
    textTheme: text,
    extensions: [c],
    appBarTheme: AppBarThemeData(
      backgroundColor: c.surface,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: c.surfaceRaised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: radiusMd, side: BorderSide(color: c.line)),
    ),
    // Bouton principal : fond teal, texte en capitales espacées (style label).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.teal,
        foregroundColor: c.onTeal,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const RoundedRectangleBorder(borderRadius: radiusMd),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.teal,
        minimumSize: const Size(64, 52),
        side: BorderSide(color: c.line, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const RoundedRectangleBorder(borderRadius: radiusMd),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.teal, textStyle: text.labelLarge),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: c.surfaceRaised,
      border: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide(color: c.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide(color: c.line)),
      focusedBorder:
          OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide(color: c.teal, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceRaised,
      selectedColor: c.tealSoft,
      side: BorderSide(color: c.line),
      shape: const RoundedRectangleBorder(borderRadius: radiusSm),
      labelStyle: text.bodyMedium,
      checkmarkColor: c.ink,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.tealDeep,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      actionTextColor: c.accent,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: radiusMd),
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
  );
}
