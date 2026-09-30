import 'dart:io';

import 'package:flutter/foundation.dart';

/// Returns `true` when the current platform exposes a cancel implementation.
bool canCancelOnCurrentPlatform() =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
