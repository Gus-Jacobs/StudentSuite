import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:student_suite/providers/auth_provider.dart';

/// Defines a full application theme, including colors and fonts.
class AppTheme {
  final String name;
  final Gradient? gradient;
  final String? imageAssetPath;
  final Color primaryAccent;
  final Color navBarColor;
  final Brightness navBarBrightness; // For icons and text on nav bars
  final Color foregroundColor;
  final bool isPro;
  final Gradient? glassGradient; // New property for glass widgets

  const AppTheme({
    required this.name,
    this.gradient,
    this.imageAssetPath,
    required this.primaryAccent,
    required this.navBarColor,
    this.navBarBrightness = Brightness.light, // Default to light icons
    required this.foregroundColor,
    this.isPro = false,
    this.glassGradient,
  }) : assert(gradient != null || imageAssetPath != null,
            'Theme must have a gradient or an image.');
}

/// A list of predefined themes for the user to choose from.
final List<AppTheme> appThemes = [
  // --- Color Themes ---
  const AppTheme(
    name: "Deep Purple",
    gradient: LinearGradient(
      colors: [Color(0xFF6A1B9A), Color(0xFF303F9F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryAccent: Colors.white,
    navBarColor: Color(0xCC2c0a4c), // Darker, semi-transparent purple
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: false, // This is the default free theme
    glassGradient: null, // Dark themes don't need a special glass gradient
  ),
  const AppTheme(
    name: "Lush Jungle",
    gradient: LinearGradient(
      colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryAccent: Colors.white,
    navBarColor: Color(0xCC0d6e66), // Darker, semi-transparent teal
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  const AppTheme(
    name: "Fiery Sunset",
    gradient: LinearGradient(
      colors: [Color(0xFFd31027), Color(0xFFea384d)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryAccent: Colors.white,
    navBarColor: Color(0xCC8f0b1a), // Darker, semi-transparent red
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  // --- Image Themes ---
  const AppTheme(
    name: "Beach Escape",
    imageAssetPath: 'assets/img/beach.jpg',
    primaryAccent: Color(0xFF00A7C4), // Cyan from the water
    navBarColor: Color(0xDD005f73), // Dark, semi-transparent teal
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  const AppTheme(
    name: "Cosmic Dream",
    imageAssetPath: 'assets/img/space.jpg',
    primaryAccent: Color(0xFF9d4edd), // Vibrant purple from nebula
    navBarColor: Color(0xDD10002b), // Dark, semi-transparent deep purple
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  const AppTheme(
    name: "Tech Vision",
    imageAssetPath: 'assets/img/tech.jpg',
    primaryAccent: Color(0xFF00f5d4), // Bright cyan from circuits
    navBarColor: Color(0xDD0a0a0a), // Dark, semi-transparent black
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  const AppTheme(
    name: "Onyx",
    gradient: LinearGradient(
      colors: [Color(0xFF434343), Color(0xFF000000)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryAccent: Colors.white,
    navBarColor: Color(0xDD1a1a1a),
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  const AppTheme(
    name: "Midnight",
    gradient: LinearGradient(
      colors: [Color(0xFF000046), Color(0xFF1CB5E0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryAccent: Colors.white,
    isPro: true,
    navBarColor: Color(0xDD00002a),
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    glassGradient: null,
  ),
  AppTheme(
    name: "Alabaster",
    gradient: const LinearGradient(
      colors: [
        Color(0xFFF5F5F5), // Off-white
        Color.fromARGB(255, 171, 170, 170), // Slightly darker grey
        Color.fromARGB(255, 143, 143, 143) // darker grey
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryAccent:
        const Color(0xFF37474F), // Darker blue-grey for better contrast
    navBarColor: const Color(0xDDE0E0E0), // Semi-transparent light grey
    navBarBrightness: Brightness.dark, // Use dark icons on this light theme
    foregroundColor: const Color(0xFF212121), // Dark grey for text
    isPro: true,
    glassGradient: LinearGradient(
      colors: [Colors.black.withOpacity(0.12), Colors.grey.withOpacity(0.05)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
];

/// Helper function to determine a high-contrast color (black or white) for
/// text on a given background color.
Color _getHighContrastColor(Color backgroundColor) {
  // Use the luminance to decide if the background is light or dark.
  return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

/// Manages the app's current theme and notifies listeners of changes.
/// Persists the selected theme using Firestore for the logged-in user.
class ThemeProvider with ChangeNotifier {
  AuthProvider? _authProvider;
  AppTheme _currentAppTheme = appThemes[0];
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSizeScale = 1.0;
  String _fontFamily = 'Roboto';

  AppTheme get currentTheme => _currentAppTheme;
  ThemeMode get themeMode => _themeMode;
  double get fontSizeScale => _fontSizeScale;
  AppTheme get defaultTheme => appThemes.firstWhere((t) => !t.isPro);
  String get fontFamily => _fontFamily;

  /// This is called by the ChangeNotifierProxyProvider in main.dart.
  void updateForUser(AuthProvider auth) {
    _authProvider = auth;

    // If auth is still loading, we don't have the final user data yet.
    // The UI will show a loading state based on auth.isLoading.
    if (auth.isLoading) {
      return;
    }

    AppTheme newTheme;
    ThemeMode newThemeMode;
    double newFontSizeScale;
    String newFontFamily;

    if (auth.user == null) {
      // User is logged out, revert to a default theme
      newTheme = defaultTheme;
      newThemeMode = ThemeMode.system;
      newFontSizeScale = 1.0;
      newFontFamily = 'Roboto';
    } else {
      // User is logged in, use their saved preferences or fallbacks
      newTheme = appThemes.firstWhere(
        (t) => t.name == auth.themeName,
        orElse: () => defaultTheme,
      );
      // If the user's saved theme is a pro theme but they are not subscribed,
      // revert them to the default theme.
      if (newTheme.isPro && !auth.isPro) {
        newTheme = defaultTheme;
      }

      newThemeMode = _themeModeFromString(auth.themeMode);
      newFontSizeScale = auth.fontSizeScale ?? 1.0;
      newFontFamily = auth.fontFamily ?? 'Roboto';
    }

    // Check if anything has actually changed to avoid unnecessary rebuilds
    if (newTheme.name != _currentAppTheme.name ||
        newThemeMode != _themeMode ||
        newFontSizeScale != _fontSizeScale ||
        newFontFamily != _fontFamily) {
      _currentAppTheme = newTheme;
      _themeMode = newThemeMode;
      _fontSizeScale = newFontSizeScale;
      _fontFamily = newFontFamily;
      notifyListeners();
    }
  }

  // --- Setters for user preferences ---

  Future<void> setAppTheme(AppTheme theme) async {
    if (_currentAppTheme.name == theme.name) return;
    _currentAppTheme = theme;
    notifyListeners();
    await _authProvider?.updateUserPreferences({'themeName': theme.name});
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _authProvider
        ?.updateUserPreferences({'themeMode': _themeModeToString(mode)});
  }

  Future<void> setFontSizeScale(double scale) async {
    if (_fontSizeScale == scale) return;
    _fontSizeScale = scale;
    notifyListeners();
    await _authProvider?.updateUserPreferences({'fontSizeScale': scale});
  }

  Future<void> setFontFamily(String family) async {
    if (_fontFamily == family) return;
    _fontFamily = family;
    notifyListeners();
    await _authProvider?.updateUserPreferences({'fontFamily': family});
  }

  // --- Helpers ---

  ThemeMode _themeModeFromString(String? modeString) {
    switch (modeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  // --- ThemeData Builders ---

  ThemeData get lightThemeData => _buildThemeData(ThemeData.light());
  ThemeData get darkThemeData => _buildThemeData(ThemeData.dark());

  ThemeData _buildThemeData(ThemeData base) {
    final theme = currentTheme;
    final isDark = base.brightness == Brightness.dark;

    // For elements that should have a "glass" effect (e.g., text fields, chips).
    final Color glassColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

    // Create more robust background colors for cards and dialogs.
    // This blends the base theme's color with our custom theme's nav bar color
    // for a more cohesive and predictable appearance.
    final Color cardBackgroundColor =
        Color.lerp(base.cardColor, theme.navBarColor, isDark ? 0.1 : 0.05)!
            .withOpacity(0.85);

    final Color dialogBackgroundColor =
        theme.navBarColor.withAlpha(245); // Almost opaque

    final scaledTextStyle = base.textTheme.bodyMedium?.copyWith(
      fontFamily: _fontFamily,
      fontSize: (base.textTheme.bodyMedium?.fontSize ?? 14.0) * _fontSizeScale,
      color: theme.foregroundColor,
    );

    final textTheme = base.textTheme
        .copyWith(
          // Apply font family, scaling, and FOREGROUND COLOR to all text styles
          displayLarge: base.textTheme.displayLarge?.copyWith(
              fontFamily: _fontFamily,
              fontSize: (base.textTheme.displayLarge?.fontSize ?? 57.0) *
                  _fontSizeScale,
              color: theme.foregroundColor),
          displayMedium: base.textTheme.displayMedium?.copyWith(
              fontFamily: _fontFamily,
              fontSize: (base.textTheme.displayMedium?.fontSize ?? 45.0) *
                  _fontSizeScale,
              color: theme.foregroundColor),
          displaySmall: base.textTheme.displaySmall?.copyWith(
              fontFamily: _fontFamily,
              fontSize: (base.textTheme.displaySmall?.fontSize ?? 36.0) *
                  _fontSizeScale,
              color: theme.foregroundColor),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
              fontFamily: _fontFamily,
              fontSize: (base.textTheme.headlineLarge?.fontSize ?? 32.0) *
                  _fontSizeScale,
              color: theme.foregroundColor),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontFamily: _fontFamily,
              fontSize: (base.textTheme.headlineMedium?.fontSize ?? 28.0) *
                  _fontSizeScale,
              color: theme.foregroundColor),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
              fontFamily: _fontFamily,
              fontSize: (base.textTheme.headlineSmall?.fontSize ?? 24.0) *
                  _fontSizeScale,
              color: theme.foregroundColor),
          titleLarge: base.textTheme.titleLarge?.copyWith(
              fontFamily: _fontFamily,
              fontSize: (base.textTheme.titleLarge?.fontSize ?? 22.0) *
                  _fontSizeScale,
              color: theme.foregroundColor),
          titleMedium: base.textTheme.titleMedium?.copyWith(
              fontFamily: _fontFamily,
              fontSize: (base.textTheme.titleMedium?.fontSize ?? 16.0) *
                  _fontSizeScale,
              color: theme.foregroundColor),
          titleSmall: base.textTheme.titleSmall?.copyWith(
              fontFamily: _fontFamily,
              fontSize: (base.textTheme.titleSmall?.fontSize ?? 14.0) *
                  _fontSizeScale,
              color: theme.foregroundColor),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
              fontFamily: _fontFamily,
              fontSize:
                  (base.textTheme.bodyLarge?.fontSize ?? 16.0) * _fontSizeScale,
              color: theme.foregroundColor),
          bodyMedium: scaledTextStyle,
          bodySmall: base.textTheme.bodySmall?.copyWith(
              fontFamily: _fontFamily,
              fontSize:
                  (base.textTheme.bodySmall?.fontSize ?? 12.0) * _fontSizeScale,
              color: theme.foregroundColor.withOpacity(0.8)),
          labelLarge: base.textTheme.labelLarge?.copyWith(
              fontFamily: _fontFamily,
              fontSize: (base.textTheme.labelLarge?.fontSize ?? 14.0) *
                  _fontSizeScale,
              color: theme.primaryAccent),
        )
        .apply(
          // Ensure all text styles inherit the foreground color
          bodyColor: theme.foregroundColor,
          displayColor: theme.foregroundColor,
        );

    return base.copyWith(
      primaryColor: theme.primaryAccent,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: theme.navBarColor,
        foregroundColor: theme.foregroundColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: theme.navBarBrightness,
          statusBarIconBrightness: theme.navBarBrightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        iconTheme: IconThemeData(color: theme.foregroundColor),
        actionsIconTheme: IconThemeData(color: theme.foregroundColor),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: theme.navBarColor,
        selectedItemColor: theme.primaryAccent,
        unselectedItemColor: theme.foregroundColor.withOpacity(0.7),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: cardBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryAccent,
          // Ensure the button text color has high contrast with the button background
          foregroundColor: _getHighContrastColor(theme.primaryAccent),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: theme.primaryAccent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return theme.primaryAccent;
          }
          return theme.foregroundColor.withOpacity(0.5);
        }),
        checkColor: WidgetStateProperty.all(theme.navBarColor),
        side: BorderSide(color: theme.foregroundColor.withOpacity(0.7)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: theme.foregroundColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassColor,
        labelStyle: textTheme.bodyLarge,
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: theme.foregroundColor.withOpacity(0.5),
        ),
        prefixIconColor: theme.foregroundColor.withOpacity(0.7),
        suffixIconColor: theme.foregroundColor.withOpacity(0.7),
        // Add more top padding to prevent the floating label from being clipped
        // when the text field is focused.
        contentPadding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.foregroundColor.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.primaryAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: base.colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: base.colorScheme.error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: glassColor,
        labelStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide(
            color: theme.foregroundColor.withOpacity(0.2),
          ),
        ),
        deleteIconColor: theme.foregroundColor.withOpacity(0.7),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return theme.primaryAccent;
              }
              return glassColor; // unselected
            },
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return theme.navBarColor;
              }
              return theme.foregroundColor; // unselected
            },
          ),
          side: WidgetStateProperty.all(
            BorderSide(color: theme.foregroundColor.withOpacity(0.2)),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: theme.primaryAccent,
        inactiveTrackColor: theme.primaryAccent.withOpacity(0.3),
        thumbColor: theme.primaryAccent,
        overlayColor: theme.primaryAccent.withOpacity(0.2),
        valueIndicatorColor: theme.navBarColor,
        valueIndicatorTextStyle: textTheme.bodySmall?.copyWith(
          color: theme.foregroundColor,
        ),
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: theme.primaryAccent,
        secondary: theme.primaryAccent,
        onPrimary: _getHighContrastColor(theme.primaryAccent),
        onSurface: theme.foregroundColor, // Main text color
        brightness: base.brightness,
      ),
    );
  }
}

/// Helper function to determine a high-contrast color (black or white) for
