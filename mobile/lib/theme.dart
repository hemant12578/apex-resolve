import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

/// Apex Resolve design language.
///
/// Warm ink surfaces, coral-to-rose momentum, violet verification and a calm
/// paper daylight theme. These tokens are shared by every native screen.
class ApexColors {
  const ApexColors._();

  static const coral = Color(0xFFFF8A5C);
  static const rose = Color(0xFFFF4D8D);
  static const violet = Color(0xFFC084FC);
  static const cyan = Color(0xFF38BDF8);
  static const green = Color(0xFF38D39F);
  static const amber = Color(0xFFF0A35E);
  static const danger = Color(0xFFFF6B7A);
  static const ink = Color(0xFF080B0E);
  static const panel = Color(0xFF0F1419);
  static const panel2 = Color(0xFF181F27);
  static const line = Color(0xFF27323C);
  static const text = Color(0xFFF5F1E9);
  static const muted = Color(0xFF96A2AB);
  static const paper = Color(0xFFF7F1EA);
  static const paperPanel = Color(0xFFFFFDF9);
  static const paperPanel2 = Color(0xFFF3ECE3);
  static const paperLine = Color(0xFFE4D8CA);
  static const paperText = Color(0xFF1B1714);
  static const paperMuted = Color(0xFF6D625A);
  static const accentInk = Color(0xFF2A1018);
}

class ApexGradients {
  const ApexGradients._();

  static const primary = LinearGradient(
    colors: [ApexColors.coral, Color(0xFFFF5F74), ApexColors.rose],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const bubble = LinearGradient(
    colors: [Color(0xFFFF9A6E), Color(0xFFFF6A7E), ApexColors.rose],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const story = SweepGradient(
    colors: [
      ApexColors.coral,
      ApexColors.rose,
      ApexColors.violet,
      ApexColors.cyan,
      ApexColors.coral,
    ],
    stops: [0, .25, .5, .75, 1],
    startAngle: 3.6,
    endAngle: 9.9,
  );

  static LinearGradient surfaceGlow(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return LinearGradient(
      colors:
          dark
              ? [
                ApexColors.coral.withValues(alpha: .13),
                ApexColors.rose.withValues(alpha: .05),
                ApexColors.panel,
              ]
              : [
                ApexColors.coral.withValues(alpha: .18),
                ApexColors.rose.withValues(alpha: .07),
                ApexColors.paperPanel,
              ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static LinearGradient chatWallpaper(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return LinearGradient(
      colors:
          dark
              ? [const Color(0xFF090E12), const Color(0xFF0C1216), const Color(0xFF101820)]
              : [const Color(0xFFF7F1EA), const Color(0xFFFBF4EC), const Color(0xFFF5EEE6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

/// Session-scoped appearance controller. The choice applies immediately and is
/// intentionally tucked into Settings instead of floating over creation flows.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  String get label => switch (_mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Daylight',
    ThemeMode.dark => 'Midnight',
  };
}

class ApexTheme {
  const ApexTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? ApexColors.ink : ApexColors.paper;
    final panel = dark ? ApexColors.panel : ApexColors.paperPanel;
    final panel2 = dark ? ApexColors.panel2 : ApexColors.paperPanel2;
    final line = dark ? ApexColors.line : ApexColors.paperLine;
    final text = dark ? ApexColors.text : ApexColors.paperText;
    final muted = dark ? ApexColors.muted : ApexColors.paperMuted;
    final primary = dark ? ApexColors.coral : const Color(0xFFD9552F);
    final onPrimary = dark ? ApexColors.accentInk : Colors.white;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer:
          dark ? const Color(0xFF3A1E16) : const Color(0xFFFFE3D6),
      onPrimaryContainer:
          dark ? const Color(0xFFFFD9CB) : const Color(0xFF6B2410),
      secondary: dark ? ApexColors.rose : const Color(0xFFB02D63),
      onSecondary: Colors.white,
      secondaryContainer:
          dark ? const Color(0xFF3A1526) : const Color(0xFFFFDCE9),
      onSecondaryContainer:
          dark ? const Color(0xFFFFC9DD) : const Color(0xFF5E1230),
      tertiary: dark ? ApexColors.violet : const Color(0xFF7C3AED),
      onTertiary: Colors.white,
      tertiaryContainer:
          dark ? const Color(0xFF2C1A42) : const Color(0xFFF0E3FF),
      onTertiaryContainer:
          dark ? const Color(0xFFE6D4FF) : const Color(0xFF3B176B),
      error: ApexColors.danger,
      onError: Colors.white,
      surface: panel,
      onSurface: text,
      surfaceContainerHighest: panel2,
      onSurfaceVariant: muted,
      outline: line,
      outlineVariant: line,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: dark ? ApexColors.paperPanel : ApexColors.panel,
      onInverseSurface: dark ? ApexColors.paperText : ApexColors.text,
      inversePrimary: dark ? const Color(0xFFD9552F) : ApexColors.coral,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final textTheme = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
        height: 1.02,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        height: 1.05,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.7,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.4,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .1,
      ),
    );

    final radius = BorderRadius.circular(14);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: panel2,
        hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w500),
        labelStyle: TextStyle(color: muted),
        floatingLabelStyle: TextStyle(color: primary),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: ApexColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: ApexColors.danger, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? ApexColors.coral : primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panel2,
        selectedColor: primary.withValues(alpha: .18),
        disabledColor: panel2,
        side: BorderSide(color: line),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: TextStyle(
          color: muted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        secondaryLabelStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        showCheckmark: false,
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: text),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: text,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel2,
        contentTextStyle: TextStyle(color: text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: line),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: .6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        showDragHandle: true,
        dragHandleColor: line,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: panel2,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: panel2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: line),
        ),
        textStyle: TextStyle(color: text, fontSize: 12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
