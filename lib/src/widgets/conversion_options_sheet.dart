import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversion_options.dart';
import '../models/converter_state.dart';
import '../providers/converter_provider.dart';
import '../providers/options_provider.dart';

class ConversionOptionsSheet extends ConsumerWidget {
  const ConversionOptionsSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(optionsDraftProvider);
    final options = draft.options;
    final controller = ref.read(optionsDraftProvider.notifier);
    final video = ref.watch(converterProvider).video!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'WebP conversion options',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (draft.loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              DropdownButtonFormField<OutputResolution>(
                initialValue: options.resolution,
                decoration: const InputDecoration(
                  labelText: 'Resolution (shorter side)',
                ),
                items: OutputResolution.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    controller.update(options.copyWith(resolution: value));
                  }
                },
              ),
              const Text(
                'Videos will not be upscaled beyond their original resolution.',
              ),
              Text('FPS: ${options.fps.toStringAsFixed(1)}'),
              Slider(
                value: options.fps,
                min: 10,
                max: 60,
                divisions: 50,
                onChanged: (value) =>
                    controller.update(options.copyWith(fps: value)),
              ),
              Text('Quality: ${options.quality.round()}'),
              Slider(
                value: options.quality,
                min: 50,
                max: 100,
                divisions: 50,
                onChanged: (value) =>
                    controller.update(options.copyWith(quality: value)),
              ),
              Text('Speed: ${options.speed.toStringAsFixed(2)}x'),
              Slider(
                value: options.speed,
                min: 1,
                max: 3,
                divisions: 8,
                onChanged: (value) =>
                    controller.update(options.copyWith(speed: value)),
              ),
              Text(
                'Estimated duration: ${(video.duration.inMilliseconds / 1000 / options.speed).toStringAsFixed(1)}s',
              ),
              const SizedBox(height: 12),
              if (draft.estimate.bytes case final bytes?)
                Text(
                  'Estimated size: approximately ${(bytes / 1000000).toStringAsFixed(2)} MB',
                ),
              if (draft.estimate.status == EstimateStatus.calculating) ...[
                const LinearProgressIndicator(),
                const Text('Analyzing samples…'),
              ],
              if (draft.estimate.error case final error?) Text(error),
              const Text(
                'Estimated from video samples. The actual file size may differ.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, options),
                child: const Text('Start conversion'),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
