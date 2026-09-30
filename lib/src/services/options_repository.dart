import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversion_options.dart';

final optionsRepositoryProvider = Provider<OptionsRepository>(
  (ref) => OptionsRepository(SharedPreferencesAsync()),
);

/// The conversion flow decides when to persist; editing a draft never saves it.
class OptionsRepository {
  OptionsRepository(this._preferences);

  final SharedPreferencesAsync _preferences;
  static const _key = 'last_webp_conversion_options';

  Future<ConversionOptions> load() async {
    final stored = await _preferences.getString(_key);
    if (stored == null) return const ConversionOptions();
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic>) return const ConversionOptions();
      return ConversionOptions.fromMap(decoded);
    } on FormatException {
      return const ConversionOptions();
    }
  }

  Future<void> save(ConversionOptions options) =>
      _preferences.setString(_key, jsonEncode(options.toMap()));
}
