import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversion_options.dart';
import '../models/converter_state.dart';
import '../providers/converter_provider.dart';
import '../providers/options_provider.dart';
import 'playful_theme.dart';

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
              'Make it yours',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Fine-tune your WebP before you start.'),
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Videos will not be upscaled beyond their original resolution.',
                ),
              ),
              _OptionCard(
                label: 'Frame rate',
                value: '${options.fps.toStringAsFixed(0)} FPS',
                child: Slider(
                  value: options.fps,
                  min: 10,
                  max: 60,
                  divisions: 50,
                  onChanged: (value) =>
                      controller.update(options.copyWith(fps: value)),
                ),
              ),
              const SizedBox(height: 12),
              _OptionCard(
                label: 'Quality',
                value: '${options.quality.round()}',
                child: Slider(
                  value: options.quality,
                  min: 50,
                  max: 100,
                  divisions: 50,
                  onChanged: (value) =>
                      controller.update(options.copyWith(quality: value)),
                ),
              ),
              const SizedBox(height: 12),
              _OptionCard(
                label: 'Speed',
                value: '${options.speed.toStringAsFixed(2)}x',
                child: Slider(
                  value: options.speed,
                  min: 1,
                  max: 3,
                  divisions: 8,
                  onChanged: (value) =>
                      controller.update(options.copyWith(speed: value)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Estimated duration: ${(video.duration.inMilliseconds / 1000 / options.speed).toStringAsFixed(1)}s',
              ),
              const SizedBox(height: 12),
              if (draft.estimate.bytes case final bytes?)
                Card(
                  color: const Color(0xFFEAF7FE),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estimated size'),
                        Text(
                          '≈ ${(bytes / 1000000).toStringAsFixed(2)} MB',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (draft.estimate.status == EstimateStatus.calculating) ...[
                const LinearProgressIndicator(),
                const Text('Analyzing samples…'),
              ],
              if (draft.estimate.error case final error?) Text(error),
              const Text(
                'Estimated from video samples. The actual file size may differ.',
              ),
              const SizedBox(height: 16),
              PlayfulButton(
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.value,
    required this.child,
  });
  final String label;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDFACD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    ),
  );
}
