class Group {
  final String id;
  final String name;
  final int contribution;
  final String frequency;
  final List<String> members;
  final DateTime nextPayout;

  Group({
    required this.id,
    required this.name,
    required this.contribution,
    required this.frequency,
    required this.members,
    required this.nextPayout,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      contribution: json['contribution'] as int,
      frequency: json['frequency'] as String,
      members: List<String>.from(json['members'] as List),
      nextPayout: DateTime.parse(json['nextPayout'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contribution': contribution,
      'frequency': frequency,
      'members': members,
      'nextPayout': nextPayout.toIso8601String(),
    };
  }
}
