import 'dart:math' as math;

import 'package:equb/models/equb_model.dart';
import 'package:equb/services/equb_rotation_engine.dart';

/// Simple console demo that simulates a 10 member random Equb.
///
/// Run with:
/// ```
/// dart run tool/demo_random_equb.dart
/// ```
void main() {
  const memberCount = 10;
  const contribution = 100.0;
  final members = List.generate(memberCount, (index) => 'member-${index + 1}');

  final config = EqubScheduleConfig(
    startDate: DateTime.utc(2024, 1, 1),
    cycleLengthDays: 30,
    cycle: EqubCycle.monthly,
    strategy: PayoutStrategy.random,
    autoAssign: true,
  );

  final engine = EqubRotationEngine();
  final baseGroup = EqubGroup(
    id: 'demo-equb',
    name: 'Demo Random Equb',
    contributionAmount: contribution,
    payoutStrategy: PayoutStrategy.random,
    members: members,
    scheduleConfig: config,
  );

  var group = baseGroup.copyWith(
    rotationState: engine.bootstrapState(
      config: config,
      members: members,
      now: config.startDate,
    ),
  );

  final winners = <EqubPayoutRecord>[];

  // Simulate one season (each member wins exactly once).
  final randomSeed = DateTime.now().millisecondsSinceEpoch;
  final random = math.Random(randomSeed);
  final shuffledMembers = List<String>.from(members)..shuffle(random);
  for (var round = 0; round < memberCount; round++) {
    final performer = shuffledMembers[round];
    final outcome = engine.forcePayout(
      group: group,
      overrideMemberId: performer,
      ignoreContributionThreshold: true,
      now: config.startDate.add(Duration(days: round * config.cycleLengthDays)),
      note: 'Demo forced payout',
    );
    group = group.copyWith(rotationState: outcome.state);
    if (outcome.payoutTriggered && outcome.payout != null) {
      winners.add(outcome.payout!);
      final winner = outcome.payout!;
      final order = winners.length;
      final amount = winner.amount.toStringAsFixed(0);
      // ignore: avoid_print
      print('Round $order winner: ${winner.memberId} receives ETB $amount');
    }
  }

  // Summary output so the order is easy to inspect.
  // ignore: avoid_print
  print('\nSummary of winners (one full rotation):');
  for (final record in winners) {
    // ignore: avoid_print
    print('Round ${record.round}: ${record.memberId}');
  }
}
