import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ResultService {
  static const _channel = MethodChannel('simple_webp_converter/media');
  Future<void> save(String path) =>
      _channel.invokeMethod<void>('saveWebp', {'path': path});
  Future<void> share(String path, Rect origin) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'image/webp')],
        sharePositionOrigin: origin,
      ),
    );
  }
}
