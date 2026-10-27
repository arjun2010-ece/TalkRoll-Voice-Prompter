import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'desktop_theme.dart' show DesktopPalette, proAmber;

/// The iPhone, iPad and Android theme. It uses the same dark and light palettes as the macOS design, so the
/// brand, colours and type carry across, with the corner radii and controls of each platform: rounded
/// rectangles on Apple devices, pill shapes on Android. The prompter itself stays black in both appearances.
ThemeData mobileTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? DesktopPalette.dark : DesktopPalette.light;
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  final dark = p.isDark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: Colors.white,
    primaryContainer: p.selectedRow,
    onPrimaryContainer: p.text,
    secondary: proAmber,
    onSecondary: const Color(0xFF1A1A1A),
    // Tonal buttons and chips are neutral; amber is reserved for Pro and warnings.
    secondaryContainer: p.tile,
    onSecondaryContainer: p.text,
    tertiary: p.success,
    onTertiary: Colors.white,
    tertiaryContainer: dark ? const Color(0xFF3A3326) : const Color(0xFFFBEBC9),
    onTertiaryContainer: dark ? const Color(0xFFF5C26B) : const Color(0xFF8A5A00),
    error: p.danger,
    onError: dark ? const Color(0xFF3A0B07) : Colors.white,
    errorContainer: p.dangerContainer,
    onErrorContainer: dark ? const Color(0xFFFFC9C4) : const Color(0xFF8B1A12),
    surface: p.page,
    onSurface: p.text,
    onSurfaceVariant: p.textMuted,
    outline: p.outline,
    outlineVariant: p.border,
    surfaceContainerLowest: dark ? const Color(0xFF161618) : Colors.white,
    surfaceContainerLow: p.inspector,
    surfaceContainer: p.sidebar,
    surfaceContainerHigh: p.card,
    surfaceContainerHighest: p.tile,
    inverseSurface: p.text,
    onInverseSurface: p.page,
    inversePrimary: p.action,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final buttonShape = ios ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)) : const StadiumBorder();
  bool off(Set<WidgetState> s) => s.contains(WidgetState.disabled);
  const minimum = WidgetStatePropertyAll(Size(48, 52));
  final panelShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(ios ? 14 : 28),
    side: BorderSide(color: dark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6)),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.page,
    canvasColor: p.page,
    dividerTheme: DividerThemeData(color: p.border, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.page,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 2)),
    dialogTheme: DialogThemeData(backgroundColor: p.card, surfaceTintColor: Colors.transparent, shape: panelShape),
    popupMenuTheme: PopupMenuThemeData(color: p.card, surfaceTintColor: Colors.transparent, shape: panelShape),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? p.tile : const Color(0xFF323236),
      contentTextStyle: TextStyle(color: dark ? p.text : Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ios ? 14 : 4)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimum,
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24)),
        shape: WidgetStatePropertyAll(buttonShape),
        backgroundColor: WidgetStateProperty.resolveWith((s) => off(s) ? p.tile : p.action),
        foregroundColor: WidgetStateProperty.resolveWith((s) => off(s) ? p.textDisabled : Colors.white),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimum,
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 22)),
        shape: WidgetStatePropertyAll(buttonShape),
        backgroundColor: WidgetStateProperty.resolveWith((s) => off(s) ? p.card : p.tile),
        foregroundColor: WidgetStateProperty.resolveWith((s) => off(s) ? p.textDisabled : p.text),
        side: WidgetStatePropertyAll(BorderSide(color: p.buttonBorder)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        shape: WidgetStatePropertyAll(buttonShape),
        foregroundColor: WidgetStateProperty.resolveWith((s) => off(s) ? p.textDisabled : p.link),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        foregroundColor: WidgetStatePropertyAll(p.icon),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.action,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ios ? 16 : 16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.inspector,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(ios ? 20 : 28))),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? (ios ? p.segmentSelected : p.selectedRow) : (ios ? p.well : Colors.transparent)),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.segmentSelectedText : p.icon),
        side: WidgetStatePropertyAll(BorderSide(color: ios ? p.border : (dark ? const Color(0xFF79747E) : const Color(0xFF79747E)))),
        minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? (ios ? p.success : p.action) : p.switchOff),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      thumbColor: dark ? Colors.white : p.accent,
      inactiveTrackColor: dark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent, linearTrackColor: p.tile),
    checkboxTheme: CheckboxThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : null)),
    inputDecorationTheme: InputDecorationThemeData(hintStyle: TextStyle(color: dark ? const Color(0xFF8E8E93) : const Color(0xFF86868B))),
  );
}
