import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversion_options.dart';
import '../models/converter_state.dart';
import '../services/options_repository.dart';
import '../services/size_estimator.dart';
import '../services/webp_service.dart';
import 'converter_provider.dart';

final sizeEstimatorProvider = Provider(
  (ref) => SizeEstimator(ref.read(webpServiceProvider)),
);
final optionsDraftProvider =
    NotifierProvider.autoDispose<OptionsDraftController, OptionsDraft>(
      OptionsDraftController.new,
    );

class OptionsDraft {
  const OptionsDraft({
    this.options = const ConversionOptions(),
    this.estimate = const SizeEstimate(),
    this.loading = true,
  });
  final ConversionOptions options;
  final SizeEstimate estimate;
  final bool loading;
}

class OptionsDraftController extends Notifier<OptionsDraft> {
  Timer? _timer;
  WebpOperation? _operation;
  Future<void> _pending = Future.value();
  int _generation = 0;

  @override
  OptionsDraft build() {
    ref.onDispose(() {
      _timer?.cancel();
      _generation++;
      unawaited(_operation?.cancel());
    });
    unawaited(
      Future<void>(() async {
        ConversionOptions options;
        try {
          options = await ref.read(optionsRepositoryProvider).load();
        } catch (_) {
          options = ref.read(converterProvider).options;
        }
        if (!ref.mounted) return;
        update(ConversionOptions.fromMap(options.toMap()));
      }),
    );
    return const OptionsDraft();
  }

  void update(ConversionOptions options) {
    final video = ref.read(converterProvider).video!;
    final estimator = ref.read(sizeEstimatorProvider);
    final cached = estimator.cached(video, options);
    final token = ++_generation;
    _timer?.cancel();
    unawaited(_operation?.cancel());
    state = OptionsDraft(
      options: options,
      loading: false,
      estimate: SizeEstimate(
        status: cached == null
            ? EstimateStatus.calculating
            : EstimateStatus.ready,
        bytes: cached ?? estimator.approximate(video, options),
      ),
    );
    if (cached != null) return;
    _timer = Timer(const Duration(milliseconds: 500), () {
      final previous = _pending;
      _pending = () async {
        await previous;
        if (!ref.mounted || token != _generation) return;
        final operation = WebpOperation();
        _operation = operation;
        try {
          final bytes = await estimator.estimate(video, options, operation);
          if (ref.mounted && token == _generation) {
            state = OptionsDraft(
              options: options,
              loading: false,
              estimate: SizeEstimate(
                status: EstimateStatus.ready,
                bytes: bytes,
              ),
            );
          }
        } on ConversionCancelled {
          // A newer draft or conversion owns the UI now.
        } catch (_) {
          if (ref.mounted && token == _generation) {
            state = OptionsDraft(
              options: options,
              loading: false,
              estimate: const SizeEstimate(
                status: EstimateStatus.failed,
                error:
                    'Unable to estimate the size. You can still convert the video.',
              ),
            );
          }
        } finally {
          if (identical(_operation, operation)) _operation = null;
        }
      }();
    });
  }

  Future<void> stop() async {
    _generation++;
    _timer?.cancel();
    await _operation?.cancel();
    await _pending;
  }
}
