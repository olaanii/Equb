enum GroupMemberRole { owner, admin, moderator, member }

extension GroupMemberRoleX on GroupMemberRole {
  String get displayName {
    switch (this) {
      case GroupMemberRole.owner:
        return 'Owner';
      case GroupMemberRole.admin:
        return 'Admin';
      case GroupMemberRole.moderator:
        return 'Moderator';
      case GroupMemberRole.member:
        return 'Member';
    }
  }

  String get description {
    switch (this) {
      case GroupMemberRole.owner:
        return 'Full control over group settings and members';
      case GroupMemberRole.admin:
        return 'Manage members and group settings';
      case GroupMemberRole.moderator:
        return 'Moderate group activities and content';
      case GroupMemberRole.member:
        return 'Participate in group activities';
    }
  }

  bool get canInviteMembers =>
      this == GroupMemberRole.owner || this == GroupMemberRole.admin;
  bool get canRemoveMembers =>
      this == GroupMemberRole.owner || this == GroupMemberRole.admin;
  bool get canChangeSettings =>
      this == GroupMemberRole.owner || this == GroupMemberRole.admin;
  bool get canManageRoles => this == GroupMemberRole.owner;
  bool get canDeleteGroup => this == GroupMemberRole.owner;
  bool get canModerateContent =>
      this == GroupMemberRole.owner ||
      this == GroupMemberRole.admin ||
      this == GroupMemberRole.moderator;
}

enum GroupInvitationStatus { pending, accepted, rejected, expired }

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.invitedBy,
    this.invitationAcceptedAt,
  });

  final String userId;
  final GroupMemberRole role;
  final DateTime joinedAt;
  final String? invitedBy;
  final DateTime? invitationAcceptedAt;

  GroupMember copyWith({
    GroupMemberRole? role,
    DateTime? joinedAt,
    String? invitedBy,
    DateTime? invitationAcceptedAt,
  }) {
    return GroupMember(
      userId: userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      invitedBy: invitedBy ?? this.invitedBy,
      invitationAcceptedAt: invitationAcceptedAt ?? this.invitationAcceptedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'role': role.name,
      'joinedAt': joinedAt.toIso8601String(),
      'invitedBy': invitedBy,
      'invitationAcceptedAt': invitationAcceptedAt?.toIso8601String(),
    };
  }

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId'] as String,
      role: GroupMemberRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => GroupMemberRole.member,
      ),
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      invitedBy: json['invitedBy'] as String?,
      invitationAcceptedAt:
          json['invitationAcceptedAt'] != null
              ? DateTime.parse(json['invitationAcceptedAt'] as String)
              : null,
    );
  }
}

class GroupInvitation {
  const GroupInvitation({
    required this.id,
    required this.groupId,
    required this.invitedUserId,
    required this.invitedBy,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.message,
    this.acceptedAt,
    this.rejectedAt,
  });

  final String id;
  final String groupId;
  final String invitedUserId;
  final String invitedBy;
  final GroupInvitationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? message;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => status == GroupInvitationStatus.pending && !isExpired;

  GroupInvitation copyWith({
    GroupInvitationStatus? status,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
  }) {
    return GroupInvitation(
      id: id,
      groupId: groupId,
      invitedUserId: invitedUserId,
      invitedBy: invitedBy,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: expiresAt,
      message: message,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'invitedUserId': invitedUserId,
      'invitedBy': invitedBy,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'message': message,
      'acceptedAt': acceptedAt?.toIso8601String(),
      'rejectedAt': rejectedAt?.toIso8601String(),
    };
  }

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    return GroupInvitation(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      invitedUserId: json['invitedUserId'] as String,
      invitedBy: json['invitedBy'] as String,
      status: GroupInvitationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GroupInvitationStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      message: json['message'] as String?,
      acceptedAt:
          json['acceptedAt'] != null
              ? DateTime.parse(json['acceptedAt'] as String)
              : null,
      rejectedAt:
          json['rejectedAt'] != null
              ? DateTime.parse(json['rejectedAt'] as String)
              : null,
    );
  }
}

class GroupSettings {
  const GroupSettings({
    this.isPublic = false,
    this.requiresApproval = true,
    this.maxMembers = 50,
    this.allowGuestContributions = false,
    this.autoApproveInvitations = false,
    this.notificationSettings = const {},
  });

  final bool isPublic;
  final bool requiresApproval;
  final int maxMembers;
  final bool allowGuestContributions;
  final bool autoApproveInvitations;
  final Map<String, dynamic> notificationSettings;

  GroupSettings copyWith({
    bool? isPublic,
    bool? requiresApproval,
    int? maxMembers,
    bool? allowGuestContributions,
    bool? autoApproveInvitations,
    Map<String, dynamic>? notificationSettings,
  }) {
    return GroupSettings(
      isPublic: isPublic ?? this.isPublic,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      maxMembers: maxMembers ?? this.maxMembers,
      allowGuestContributions:
          allowGuestContributions ?? this.allowGuestContributions,
      autoApproveInvitations:
          autoApproveInvitations ?? this.autoApproveInvitations,
      notificationSettings: notificationSettings ?? this.notificationSettings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isPublic': isPublic,
      'requiresApproval': requiresApproval,
      'maxMembers': maxMembers,
      'allowGuestContributions': allowGuestContributions,
      'autoApproveInvitations': autoApproveInvitations,
      'notificationSettings': notificationSettings,
    };
  }

  factory GroupSettings.fromJson(Map<String, dynamic> json) {
    return GroupSettings(
      isPublic: json['isPublic'] as bool? ?? false,
      requiresApproval: json['requiresApproval'] as bool? ?? true,
      maxMembers: json['maxMembers'] as int? ?? 50,
      allowGuestContributions:
          json['allowGuestContributions'] as bool? ?? false,
      autoApproveInvitations: json['autoApproveInvitations'] as bool? ?? false,
      notificationSettings:
          json['notificationSettings'] as Map<String, dynamic>? ?? {},
    );
  }
}
