import 'dart:math' as math;

import 'package:equb/services/reliability/retry_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetryPolicy', () {
    test('retries until success with exponential backoff', () async {
      final waits = <Duration>[];
      final policy = RetryPolicy(
        maxAttempts: 3,
        baseDelay: const Duration(milliseconds: 50),
        jitter: Duration.zero,
        wait: (duration) {
          waits.add(duration);
          return Future<void>.value();
        },
      );

      var attempt = 0;
      final result = await policy.execute<int>(() async {
        attempt++;
        if (attempt < 3) {
          throw StateError('fail $attempt');
        }
        return 42;
      });

      expect(result, 42);
      expect(waits, const [
        Duration(milliseconds: 50),
        Duration(milliseconds: 100),
      ]);
    });

    test('bails when shouldRetry returns false', () async {
      final policy = RetryPolicy(
        maxAttempts: 5,
        wait: (_) => Future<void>.value(),
        shouldRetry: (error) => error is StateError,
      );

      var attempt = 0;
      await expectLater(
        policy.execute<void>(() async {
          attempt++;
          throw FormatException('not retryable');
        }),
        throwsA(isA<FormatException>()),
      );
      expect(attempt, 1);
    });

    test('applies jitter but caps at max delay', () async {
      final waits = <Duration>[];
      final policy = RetryPolicy(
        maxAttempts: 2,
        baseDelay: const Duration(milliseconds: 100),
        maxDelay: const Duration(milliseconds: 120),
        jitter: const Duration(milliseconds: 40),
        random: _StubRandom(0.75),
        wait: (duration) {
          waits.add(duration);
          return Future<void>.value();
        },
      );

      await expectLater(
        policy.execute<void>(() async {
          throw Exception('always fails');
        }),
        throwsException,
      );

      expect(waits.single, const Duration(milliseconds: 120));
    });
  });
}

class _StubRandom implements math.Random {
  _StubRandom(this._value);

  final double _value;

  @override
  bool nextBool() => _value >= 0.5;

  @override
  double nextDouble() => _value;

  @override
  int nextInt(int max) => (_value * max).floor();
}
