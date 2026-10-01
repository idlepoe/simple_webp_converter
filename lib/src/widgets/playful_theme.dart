import 'package:flutter/material.dart';

const _green = Color(0xFF58CC02);
const _ink = Color(0xFF31432B);

ThemeData buildPlayfulTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _green,
    primary: _green,
    onPrimary: _ink,
    secondary: const Color(0xFF1CB0F6),
    surface: Colors.white,
    onSurface: _ink,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF7FAF4),
    textTheme: base.textTheme
        .apply(bodyColor: _ink, displayColor: _ink)
        .copyWith(
          headlineSmall: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
          titleLarge: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
          bodyMedium: const TextStyle(fontSize: 15, height: 1.45, color: _ink),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF7FAF4),
      foregroundColor: _ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: _ink,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE1E8DC), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: shape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF3D8500),
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: Color(0xFFD8E3CF), width: 2),
        shape: shape,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF3D8500),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7FAF4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD8E3CF), width: 2),
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 10,
      activeTrackColor: _green,
      inactiveTrackColor: const Color(0xFFE3EBD9),
      thumbColor: Colors.white,
      overlayColor: _green.withValues(alpha: 0.15),
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 13,
        elevation: 3,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _green,
      linearTrackColor: Color(0xFFE3EBD9),
      linearMinHeight: 12,
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}

/// Keeps Material focus, keyboard and accessibility behavior inside the button.
class PlayfulButton extends StatefulWidget {
  const PlayfulButton({super.key, required this.onPressed, required this.child})
    : icon = null;
  const PlayfulButton.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required Widget label,
  }) : child = label;
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;

  @override
  State<PlayfulButton> createState() => _PlayfulButtonState();
}

class _PlayfulButtonState extends State<PlayfulButton> {
  bool _pressed = false;
  void _press(bool value) {
    if (widget.onPressed != null && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final pressed = enabled && _pressed;
    return Listener(
      onPointerDown: (_) => _press(true),
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF419600) : const Color(0xFFDCE2D6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: AnimatedSlide(
            offset: Offset(0, pressed ? 0.075 : 0),
            duration: const Duration(milliseconds: 80),
            child: widget.icon == null
                ? FilledButton(onPressed: widget.onPressed, child: widget.child)
                : FilledButton.icon(
                    onPressed: widget.onPressed,
                    icon: widget.icon!,
                    label: widget.child,
                  ),
          ),
        ),
      ),
    );
  }
}
