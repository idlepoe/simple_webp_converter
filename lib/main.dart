import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/home_screen.dart';
import 'src/widgets/playful_theme.dart';

void main() => runApp(const ProviderScope(child: WebpConverterApp()));

class WebpConverterApp extends StatelessWidget {
  const WebpConverterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VidToWebp',
    locale: const Locale('en'),
    theme: buildPlayfulTheme(),
    home: const HomeScreen(),
  );
}
