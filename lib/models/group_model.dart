import 'package:equb/models/group_member.dart';

class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    required this.description,
    this.contributionAmount,
    this.frequencyDays = 30,
    this.members = const [],
    this.bannerUrl,
    this.createdAt,
    this.updatedAt,
    this.settings,
  });

  final String id;
  final String name;
  final String description;
  final double? contributionAmount;
  final int frequencyDays;
  final List<String> members;
  final String? bannerUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final GroupSettings? settings;

  bool get isActive => members.length >= 3; // Minimum members for active group
  int get memberCount => members.length;

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    double? contributionAmount,
    int? frequencyDays,
    List<String>? members,
    String? bannerUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    GroupSettings? settings,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      contributionAmount: contributionAmount ?? this.contributionAmount,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      members: members ?? this.members,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'contributionAmount': contributionAmount,
      'frequencyDays': frequencyDays,
      'members': members,
      'bannerUrl': bannerUrl,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'settings': settings?.toJson(),
    };
  }

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      contributionAmount: json['contributionAmount'] != null
          ? (json['contributionAmount'] as num).toDouble()
          : null,
      frequencyDays: json['frequencyDays'] as int? ?? 30,
      members: List<String>.from(json['members'] as List? ?? []),
      bannerUrl: json['bannerUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      settings: json['settings'] != null
          ? GroupSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : null,
    );
  }
}

