import 'dart:async';
import 'dart:math';

/// Simple exponential backoff policy with optional jitter and hooks for tests.
class RetryPolicy {
  RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 200),
    Duration? maxDelay,
    this.jitter = Duration.zero,
    bool Function(Object error)? shouldRetry,
    void Function(int attempt, Object error, Duration delay)? onRetry,
    Future<void> Function(Duration duration)? wait,
    Random? random,
    Duration Function(int attempt)? delayCalculator,
  }) : assert(maxAttempts > 0, 'maxAttempts must be greater than 0'),
       maxDelay = maxDelay ?? const Duration(seconds: 2),
       _shouldRetry = shouldRetry,
       _onRetry = onRetry,
       _wait = wait ?? _defaultWait,
       _random = random ?? Random(),
       _delayCalculator = delayCalculator;

  static Future<void> _defaultWait(Duration duration) =>
      Future<void>.delayed(duration);

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final Duration jitter;
  final bool Function(Object error)? _shouldRetry;
  final void Function(int attempt, Object error, Duration delay)? _onRetry;
  final Future<void> Function(Duration duration) _wait;
  final Random _random;
  final Duration Function(int attempt)? _delayCalculator;

  Future<T> execute<T>(Future<T> Function() task) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await task();
      } catch (error, stack) {
        lastError = error;
        lastStack = stack;
        final retryable = _shouldRetry == null ? true : _shouldRetry(error);
        final hasMoreAttempts = attempt < maxAttempts;
        if (!hasMoreAttempts || !retryable) {
          Error.throwWithStackTrace(error, stack);
        }
        final delay = _nextDelay(attempt);
        _onRetry?.call(attempt, error, delay);
        await _wait(delay);
      }
    }
    if (lastError != null && lastStack != null) {
      Error.throwWithStackTrace(lastError, lastStack);
    }
    throw StateError('RetryPolicy.execute exhausted attempts without error');
  }

  Duration _nextDelay(int attempt) {
    if (_delayCalculator != null) {
      return _clampDelay(_delayCalculator(attempt));
    }
    final multiplier = 1 << (attempt - 1);
    final scaled = _scaleDuration(baseDelay, multiplier);
    final withJitter =
        jitter == Duration.zero ? scaled : scaled + _computeJitter();
    return _clampDelay(withJitter);
  }

  Duration _computeJitter() {
    if (jitter == Duration.zero) {
      return Duration.zero;
    }
    final maxMicros = jitter.inMicroseconds;
    if (maxMicros <= 0) {
      return Duration.zero;
    }
    final delta = (_random.nextDouble() * maxMicros).round();
    return Duration(microseconds: delta);
  }

  Duration _clampDelay(Duration duration) {
    if (duration.isNegative) {
      return Duration.zero;
    }
    return duration > maxDelay ? maxDelay : duration;
  }

  Duration _scaleDuration(Duration duration, int factor) {
    if (factor <= 1) {
      return duration;
    }
    final microseconds = duration.inMicroseconds * factor;
    return Duration(microseconds: microseconds);
  }
}
