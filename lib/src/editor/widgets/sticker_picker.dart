import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

// Adapted from demo_build_stickers.dart: keep the WidgetLayer/precache workflow,
// use local content instead of remote demonstration images and custom styling.
class StickerPicker extends StatelessWidget {
  const StickerPicker({
    super.key,
    required this.setLayer,
    required this.scrollController,
  });
  final void Function(WidgetLayer) setLayer;
  final ScrollController scrollController;

  Future<void> _pickImage(BuildContext context) async {
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (selected == null || !context.mounted) return;
      final image = FileImage(File(selected.path));
      var failed = false;
      await precacheImage(image, context, onError: (_, _) => failed = true);
      if (failed) throw const FormatException('Image decoding failed');
      if (!context.mounted) return;
      setLayer(
        WidgetLayer(
          widget: Image(
            image: image,
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load the image.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextButton.icon(
        onPressed: () => _pickImage(context),
        icon: const Icon(Icons.image_outlined),
        label: const Text('Add sticker from photo'),
      ),
      Expanded(
        child: GridView.builder(
          controller: scrollController,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 96,
          ),
          itemCount: _stickers.length,
          itemBuilder: (context, index) {
            final sticker = Text(
              _stickers[index],
              style: const TextStyle(fontSize: 48),
            );
            return InkWell(
              onTap: () => setLayer(WidgetLayer(widget: sticker)),
              child: Center(child: sticker),
            );
          },
        ),
      ),
    ],
  );

  static const _stickers = ['⭐', '❤️', '👍', '🎉', '🔥', '🌸', '🐱', '😊'];
}
