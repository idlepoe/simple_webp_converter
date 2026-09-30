import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/home_screen.dart';

void main() => runApp(const ProviderScope(child: WebpConverterApp()));

class WebpConverterApp extends StatelessWidget {
  const WebpConverterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VidToWebp',
    locale: const Locale('en'),
    theme: ThemeData(useMaterial3: true),
    home: const HomeScreen(),
  );
}
