import 'package:equb/models/transaction_model.dart';
import 'package:equb/utils/firestore_helpers.dart';

enum PayoutStrategy { random, fixedOrder, adminAssigned }

enum EqubCycle { daily, weekly, biWeekly, monthly, custom }

extension EqubCycleX on EqubCycle {
  int? get defaultDays {
    switch (this) {
      case EqubCycle.daily:
        return 1;
      case EqubCycle.weekly:
        return 7;
      case EqubCycle.biWeekly:
        return 14;
      case EqubCycle.monthly:
        return 30;
      case EqubCycle.custom:
        return null;
    }
  }

  Duration get interval => Duration(days: defaultDays ?? 30);

  String get label {
    switch (this) {
      case EqubCycle.daily:
        return 'Daily';
      case EqubCycle.weekly:
        return 'Weekly';
      case EqubCycle.biWeekly:
        return 'Bi-weekly';
      case EqubCycle.monthly:
        return 'Monthly';
      case EqubCycle.custom:
        return 'Custom';
    }
  }
}

EqubCycle inferEqubCycle(int days) {
  switch (days) {
    case 1:
      return EqubCycle.daily;
    case 7:
      return EqubCycle.weekly;
    case 14:
      return EqubCycle.biWeekly;
    case 28:
    case 29:
    case 30:
    case 31:
      return EqubCycle.monthly;
    default:
      return EqubCycle.custom;
  }
}

int _resolveCycleLength(EqubCycle cycle, int? explicitLength) {
  final intrinsic = cycle.defaultDays;
  if (intrinsic != null) {
    return intrinsic;
  }
  final fallback = explicitLength ?? 30;
  return fallback <= 0 ? 30 : fallback;
}

class EqubScheduleConfig {
  EqubScheduleConfig({
    DateTime? startDate,
    int? cycleLengthDays,
    EqubCycle? cycle,
    this.strategy = PayoutStrategy.fixedOrder,
    this.autoAssign = true,
    List<String>? preferredOrder,
    Map<int, String>? adminAssignments,
  }) : cycle = cycle ?? inferEqubCycle(cycleLengthDays ?? 30),
       cycleLengthDays = _resolveCycleLength(
         cycle ?? inferEqubCycle(cycleLengthDays ?? 30),
         cycleLengthDays,
       ),
       startDate = (startDate ?? DateTime.now()).toUtc(),
       preferredOrder = List<String>.unmodifiable(
         preferredOrder ?? const <String>[],
       ),
       adminAssignments = Map<int, String>.unmodifiable(
         adminAssignments ?? const <int, String>{},
       );

  final DateTime startDate;
  final int cycleLengthDays;
  final EqubCycle cycle;
  final PayoutStrategy strategy;
  final bool autoAssign;
  final List<String> preferredOrder;
  final Map<int, String> adminAssignments;

  factory EqubScheduleConfig.fromJson(Map<String, dynamic> json) {
    return EqubScheduleConfig(
      startDate: FirestoreHelpers.parseDateTime(json['startDate']),
      cycleLengthDays: json['cycleLengthDays'] as int?,
      cycle:
          json['cycle'] != null
              ? EqubCycle.values.firstWhere(
                (e) => e.toString().split('.').last == json['cycle'],
                orElse: () => EqubCycle.monthly,
              )
              : null,
      strategy: PayoutStrategy.values.firstWhere(
        (e) => e.toString().split('.').last == json['strategy'],
        orElse: () => PayoutStrategy.fixedOrder,
      ),
      autoAssign: json['autoAssign'] as bool? ?? true,
      preferredOrder:
          (json['preferredOrder'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      adminAssignments: (json['adminAssignments'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(int.parse(k), v as String)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'cycleLengthDays': cycleLengthDays,
      'cycle': cycle.toString().split('.').last,
      'strategy': strategy.toString().split('.').last,
      'autoAssign': autoAssign,
      'preferredOrder': preferredOrder,
      'adminAssignments': adminAssignments.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
    };
  }

  EqubScheduleConfig copyWith({
    DateTime? startDate,
    int? cycleLengthDays,
    EqubCycle? cycle,
    PayoutStrategy? strategy,
    bool? autoAssign,
    List<String>? preferredOrder,
    Map<int, String>? adminAssignments,
  }) {
    return EqubScheduleConfig(
      startDate: startDate ?? this.startDate,
      cycleLengthDays: cycleLengthDays ?? this.cycleLengthDays,
      cycle: cycle ?? this.cycle,
      strategy: strategy ?? this.strategy,
      autoAssign: autoAssign ?? this.autoAssign,
      preferredOrder: preferredOrder ?? this.preferredOrder,
      adminAssignments: adminAssignments ?? this.adminAssignments,
    );
  }
}

class EqubPayoutRecord {
  EqubPayoutRecord({
    required this.round,
    required this.memberId,
    required this.amount,
    required DateTime scheduledFor,
    DateTime? processedAt,
    this.autoAssigned = true,
    this.note,
  }) : scheduledFor = scheduledFor.toUtc(),
       processedAt = (processedAt ?? DateTime.now()).toUtc();

  final int round;
  final String memberId;
  final double amount;
  final DateTime scheduledFor;
  final DateTime processedAt;
  final bool autoAssigned;
  final String? note;

  factory EqubPayoutRecord.fromJson(Map<String, dynamic> json) {
    return EqubPayoutRecord(
      round: json['round'] as int,
      memberId: json['memberId'] as String,
      amount: (json['amount'] as num).toDouble(),
      scheduledFor: FirestoreHelpers.parseDateTimeOrNow(json['scheduledFor']),
      processedAt: FirestoreHelpers.parseDateTime(json['processedAt']),
      autoAssigned: json['autoAssigned'] as bool? ?? true,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'round': round,
      'memberId': memberId,
      'amount': amount,
      'scheduledFor': scheduledFor.toIso8601String(),
      'processedAt': processedAt.toIso8601String(),
      'autoAssigned': autoAssigned,
      'note': note,
    };
  }

  EqubPayoutRecord copyWith({
    int? round,
    String? memberId,
    double? amount,
    DateTime? scheduledFor,
    DateTime? processedAt,
    bool? autoAssigned,
    String? note,
  }) {
    return EqubPayoutRecord(
      round: round ?? this.round,
      memberId: memberId ?? this.memberId,
      amount: amount ?? this.amount,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      processedAt: processedAt ?? this.processedAt,
      autoAssigned: autoAssigned ?? this.autoAssigned,
      note: note ?? this.note,
    );
  }
}

enum EqubRoundStatus { completed, pending, overdue }

class EqubRoundSummary {
  EqubRoundSummary({
    required this.round,
    required this.memberId,
    required DateTime scheduledFor,
    required this.expectedAmount,
    required this.status,
    required this.autoAssigned,
    this.actualPayout,
  }) : scheduledFor = scheduledFor.toUtc();

  final int round;
  final String memberId;
  final DateTime scheduledFor;
  final double expectedAmount;
  final EqubRoundStatus status;
  final bool autoAssigned;
  final EqubPayoutRecord? actualPayout;

  bool get isCompleted => status == EqubRoundStatus.completed;

  factory EqubRoundSummary.fromJson(Map<String, dynamic> json) {
    return EqubRoundSummary(
      round: json['round'] as int,
      memberId: json['memberId'] as String,
      scheduledFor: FirestoreHelpers.parseDateTimeOrNow(json['scheduledFor']),
      expectedAmount: (json['expectedAmount'] as num).toDouble(),
      status: EqubRoundStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => EqubRoundStatus.pending,
      ),
      autoAssigned: json['autoAssigned'] as bool? ?? true,
      actualPayout:
          json['actualPayout'] != null
              ? EqubPayoutRecord.fromJson(
                json['actualPayout'] as Map<String, dynamic>,
              )
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'round': round,
      'memberId': memberId,
      'scheduledFor': scheduledFor.toIso8601String(),
      'expectedAmount': expectedAmount,
      'status': status.toString().split('.').last,
      'autoAssigned': autoAssigned,
      'actualPayout': actualPayout?.toJson(),
    };
  }

  EqubRoundSummary copyWith({
    int? round,
    String? memberId,
    DateTime? scheduledFor,
    double? expectedAmount,
    EqubRoundStatus? status,
    bool? autoAssigned,
    EqubPayoutRecord? actualPayout,
  }) {
    return EqubRoundSummary(
      round: round ?? this.round,
      memberId: memberId ?? this.memberId,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      status: status ?? this.status,
      autoAssigned: autoAssigned ?? this.autoAssigned,
      actualPayout: actualPayout ?? this.actualPayout,
    );
  }
}

class EqubGroupMetrics {
  EqubGroupMetrics({
    required this.groupId,
    required this.totalMembers,
    required this.currentRound,
    required this.completedRounds,
    required this.contributionAmount,
    required this.potSize,
    required this.fundedPercentage,
    required this.totalOutstanding,
    required this.cycle,
    required this.cycleLengthDays,
    required DateTime nextPayoutDate,
    Map<String, double>? memberProgress,
    this.nextRecipient,
    this.nextRound,
  }) : nextPayoutDate = nextPayoutDate.toUtc(),
       memberProgress = Map<String, double>.unmodifiable(
         memberProgress ?? const <String, double>{},
       );

  final String groupId;
  final int totalMembers;
  final int currentRound;
  final int completedRounds;
  final double contributionAmount;
  final double potSize;
  final double fundedPercentage;
  final double totalOutstanding;
  final EqubCycle cycle;
  final int cycleLengthDays;
  final DateTime nextPayoutDate;
  final Map<String, double> memberProgress;
  final String? nextRecipient;
  final int? nextRound;

  double get cyclePotAmount => contributionAmount * totalMembers;

  factory EqubGroupMetrics.fromJson(Map<String, dynamic> json) {
    return EqubGroupMetrics(
      groupId: json['groupId'] as String,
      totalMembers: json['totalMembers'] as int,
      currentRound: json['currentRound'] as int,
      completedRounds: json['completedRounds'] as int,
      contributionAmount: (json['contributionAmount'] as num).toDouble(),
      potSize: (json['potSize'] as num).toDouble(),
      fundedPercentage: (json['fundedPercentage'] as num).toDouble(),
      totalOutstanding: (json['totalOutstanding'] as num).toDouble(),
      cycle: EqubCycle.values.firstWhere(
        (e) => e.toString().split('.').last == json['cycle'],
        orElse: () => EqubCycle.monthly,
      ),
      cycleLengthDays: json['cycleLengthDays'] as int,
      nextPayoutDate: FirestoreHelpers.parseDateTimeOrNow(
        json['nextPayoutDate'],
      ),
      memberProgress: (json['memberProgress'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      nextRecipient: json['nextRecipient'] as String?,
      nextRound: json['nextRound'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'totalMembers': totalMembers,
      'currentRound': currentRound,
      'completedRounds': completedRounds,
      'contributionAmount': contributionAmount,
      'potSize': potSize,
      'fundedPercentage': fundedPercentage,
      'totalOutstanding': totalOutstanding,
      'cycle': cycle.toString().split('.').last,
      'cycleLengthDays': cycleLengthDays,
      'nextPayoutDate': nextPayoutDate.toIso8601String(),
      'memberProgress': memberProgress,
      'nextRecipient': nextRecipient,
      'nextRound': nextRound,
    };
  }

  EqubGroupMetrics copyWith({
    String? groupId,
    int? totalMembers,
    int? currentRound,
    int? completedRounds,
    double? contributionAmount,
    double? potSize,
    double? fundedPercentage,
    double? totalOutstanding,
    EqubCycle? cycle,
    int? cycleLengthDays,
    DateTime? nextPayoutDate,
    Map<String, double>? memberProgress,
    String? nextRecipient,
    int? nextRound,
  }) {
    return EqubGroupMetrics(
      groupId: groupId ?? this.groupId,
      totalMembers: totalMembers ?? this.totalMembers,
      currentRound: currentRound ?? this.currentRound,
      completedRounds: completedRounds ?? this.completedRounds,
      contributionAmount: contributionAmount ?? this.contributionAmount,
      potSize: potSize ?? this.potSize,
      fundedPercentage: fundedPercentage ?? this.fundedPercentage,
      totalOutstanding: totalOutstanding ?? this.totalOutstanding,
      cycle: cycle ?? this.cycle,
      cycleLengthDays: cycleLengthDays ?? this.cycleLengthDays,
      nextPayoutDate: nextPayoutDate ?? this.nextPayoutDate,
      memberProgress: memberProgress ?? this.memberProgress,
      nextRecipient: nextRecipient ?? this.nextRecipient,
      nextRound: nextRound ?? this.nextRound,
    );
  }
}

class EqubRotationState {
  EqubRotationState({
    this.currentRound = 0,
    DateTime? nextPayoutDate,
    List<String>? payoutQueue,
    Map<String, double>? contributionProgress,
    List<EqubPayoutRecord>? history,
  }) : nextPayoutDate = (nextPayoutDate ?? DateTime.now()).toUtc(),
       payoutQueue = List<String>.unmodifiable(payoutQueue ?? const <String>[]),
       contributionProgress = Map<String, double>.unmodifiable(
         contributionProgress ?? const <String, double>{},
       ),
       history = List<EqubPayoutRecord>.unmodifiable(
         history ?? const <EqubPayoutRecord>[],
       );

  final int currentRound;
  final DateTime nextPayoutDate;
  final List<String> payoutQueue;
  final Map<String, double> contributionProgress;
  final List<EqubPayoutRecord> history;

  factory EqubRotationState.fromJson(Map<String, dynamic> json) {
    return EqubRotationState(
      currentRound: json['currentRound'] as int? ?? 0,
      nextPayoutDate: FirestoreHelpers.parseDateTime(json['nextPayoutDate']),
      payoutQueue:
          (json['payoutQueue'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      contributionProgress: (json['contributionProgress']
              as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toDouble())),
      history:
          (json['history'] as List<dynamic>?)
              ?.map((e) => EqubPayoutRecord.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentRound': currentRound,
      'nextPayoutDate': nextPayoutDate.toIso8601String(),
      'payoutQueue': payoutQueue,
      'contributionProgress': contributionProgress,
      'history': history.map((e) => e.toJson()).toList(),
    };
  }

  EqubRotationState copyWith({
    int? currentRound,
    DateTime? nextPayoutDate,
    List<String>? payoutQueue,
    Map<String, double>? contributionProgress,
    List<EqubPayoutRecord>? history,
  }) {
    return EqubRotationState(
      currentRound: currentRound ?? this.currentRound,
      nextPayoutDate: nextPayoutDate ?? this.nextPayoutDate,
      payoutQueue: payoutQueue ?? this.payoutQueue,
      contributionProgress: contributionProgress ?? this.contributionProgress,
      history: history ?? this.history,
    );
  }
}

class EqubGroup {
  EqubGroup._({
    required this.id,
    required this.name,
    required this.contributionAmount,
    required this.frequencyDays,
    required this.payoutStrategy,
    required this.members,
    required this.ledger,
    required this.scheduleConfig,
    required this.rotationState,
    this.bannerUrl,
  });

  factory EqubGroup({
    required String id,
    required String name,
    required double contributionAmount,
    int frequencyDays = 30,
    PayoutStrategy payoutStrategy = PayoutStrategy.fixedOrder,
    List<String>? members,
    List<TransactionModel>? ledger,
    EqubScheduleConfig? scheduleConfig,
    EqubRotationState? rotationState,
    String? bannerUrl,
  }) {
    final normalizedMembers = List<String>.unmodifiable(
      members ?? const <String>[],
    );
    final normalizedLedger = List<TransactionModel>.unmodifiable(
      ledger ?? const <TransactionModel>[],
    );
    final schedule =
        scheduleConfig ??
        EqubScheduleConfig(
          cycleLengthDays: frequencyDays,
          strategy: payoutStrategy,
          preferredOrder: normalizedMembers,
        );
    final rotation =
        rotationState ??
        EqubRotationState(
          nextPayoutDate: schedule.startDate,
          payoutQueue: normalizedMembers,
          contributionProgress: {
            for (final member in normalizedMembers) member: 0.0,
          },
        );
    return EqubGroup._(
      id: id,
      name: name,
      contributionAmount: contributionAmount,
      frequencyDays: schedule.cycleLengthDays,
      payoutStrategy: payoutStrategy,
      members: normalizedMembers,
      ledger: normalizedLedger,
      scheduleConfig: schedule,
      rotationState: rotation,
      bannerUrl: bannerUrl,
    );
  }

  final String id;
  final String name;
  final double contributionAmount;
  final int frequencyDays;
  final PayoutStrategy payoutStrategy;
  final List<String> members;
  final List<TransactionModel> ledger;
  final EqubScheduleConfig scheduleConfig;
  final EqubRotationState rotationState;
  final String? bannerUrl;

  double get poolAmountPerCycle => contributionAmount * members.length;

  factory EqubGroup.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final name = (json['name'] ?? '').toString();
    final contributionAmount = (json['contributionAmount'] as num?)?.toDouble() ??
        0.0;
    final payoutStrategy = PayoutStrategy.values.firstWhere(
      (e) => e.toString().split('.').last == json['payoutStrategy'],
      orElse: () => PayoutStrategy.fixedOrder,
    );

    final membersRaw = json['members'];
    final members = switch (membersRaw) {
      List<dynamic>() => List<String>.unmodifiable(
          membersRaw.map((e) => e.toString()).where((e) => e.isNotEmpty),
        ),
      Map<dynamic, dynamic>() => List<String>.unmodifiable(
          membersRaw.keys.map((k) => k.toString()).where((e) => e.isNotEmpty),
        ),
      _ => const <String>[],
    };

    final frequencyDays =
        (json['frequencyDays'] as int?) ??
        ((json['scheduleConfig'] is Map<String, dynamic>)
            ? (json['scheduleConfig'] as Map<String, dynamic>)['cycleLengthDays']
                as int?
            : null) ??
        30;

    final schedule = (json['scheduleConfig'] is Map)
        ? EqubScheduleConfig.fromJson(
            Map<String, dynamic>.from(json['scheduleConfig'] as Map),
          )
        : EqubScheduleConfig(
            cycleLengthDays: frequencyDays,
            strategy: payoutStrategy,
            preferredOrder: members,
          );

    final rotation = (json['rotationState'] is Map)
        ? EqubRotationState.fromJson(
            Map<String, dynamic>.from(json['rotationState'] as Map),
          )
        : EqubRotationState(
            nextPayoutDate: schedule.startDate,
            payoutQueue: members,
            contributionProgress: {
              for (final member in members) member: 0.0,
            },
          );

    return EqubGroup._(
      id: id,
      name: name,
      contributionAmount: contributionAmount,
      frequencyDays: schedule.cycleLengthDays,
      payoutStrategy: payoutStrategy,
      members: members,
      ledger:
          (json['ledger'] as List<dynamic>?)
              ?.map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      scheduleConfig: schedule,
      rotationState: rotation,
      bannerUrl: json['bannerUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contributionAmount': contributionAmount,
      'frequencyDays': frequencyDays,
      'payoutStrategy': payoutStrategy.toString().split('.').last,
      'members': members,
      'ledger': ledger.map((e) => e.toJson()).toList(),
      'scheduleConfig': scheduleConfig.toJson(),
      'rotationState': rotationState.toJson(),
      'bannerUrl': bannerUrl,
    };
  }

  EqubGroup copyWith({
    String? id,
    String? name,
    double? contributionAmount,
    int? frequencyDays,
    PayoutStrategy? payoutStrategy,
    List<String>? members,
    List<TransactionModel>? ledger,
    EqubScheduleConfig? scheduleConfig,
    EqubRotationState? rotationState,
    String? bannerUrl,
  }) {
    return EqubGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      contributionAmount: contributionAmount ?? this.contributionAmount,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      payoutStrategy: payoutStrategy ?? this.payoutStrategy,
      members: members ?? this.members,
      ledger: ledger ?? this.ledger,
      scheduleConfig: scheduleConfig ?? this.scheduleConfig,
      rotationState: rotationState ?? this.rotationState,
      bannerUrl: bannerUrl ?? this.bannerUrl,
    );
  }
}
