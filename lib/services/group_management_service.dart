import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equb/models/group_member.dart';
import 'package:equb/services/system_log_service.dart';

class GroupManagementService {
  GroupManagementService({required this.firestore, required this.logService});

  final FirebaseFirestore firestore;
  final SystemLogService logService;

  static const String _groupsCollection = 'groups';
  static const String _invitationsCollection = 'group_invitations';
  static const String _membersSubcollection = 'members';

  /// Invite a user to join a group
  Future<GroupInvitation> inviteUserToGroup({
    required String groupId,
    required String invitedUserId,
    required String invitedBy,
    String? message,
    Duration expiryDuration = const Duration(days: 7),
  }) async {
    try {
      // Check if user is already a member
      final isMember = await _isUserMemberOfGroup(invitedUserId, groupId);
      if (isMember) {
        throw Exception('User is already a member of this group');
      }

      // Check if there's already a pending invitation
      final existingInvitation = await _getPendingInvitation(
        groupId,
        invitedUserId,
      );
      if (existingInvitation != null) {
        throw Exception('User already has a pending invitation to this group');
      }

      final invitationId =
          '${groupId}_${invitedUserId}_${DateTime.now().millisecondsSinceEpoch}';
      final expiresAt = DateTime.now().add(expiryDuration);

      final invitation = GroupInvitation(
        id: invitationId,
        groupId: groupId,
        invitedUserId: invitedUserId,
        invitedBy: invitedBy,
        status: GroupInvitationStatus.pending,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        message: message,
      );

      await firestore.collection(_invitationsCollection).doc(invitationId).set({
        ...invitation.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      logService.log(
        LogLevel.info,
        'group_invitation_created',
        'User invited to group',
        context: {
          'groupId': groupId,
          'invitedUserId': invitedUserId,
          'invitedBy': invitedBy,
          'invitationId': invitationId,
        },
      );

      return invitation;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'group_invitation_failed',
        'Failed to create group invitation',
        context: {
          'groupId': groupId,
          'invitedUserId': invitedUserId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Accept a group invitation
  Future<void> acceptInvitation(String invitationId) async {
    try {
      final invitationDoc =
          await firestore
              .collection(_invitationsCollection)
              .doc(invitationId)
              .get();

      if (!invitationDoc.exists) {
        throw Exception('Invitation not found');
      }

      final invitation = GroupInvitation.fromJson(invitationDoc.data()!);

      if (invitation.status != GroupInvitationStatus.pending) {
        throw Exception('Invitation is no longer pending');
      }

      if (invitation.isExpired) {
        throw Exception('Invitation has expired');
      }

      // Update invitation status
      await invitationDoc.reference.update({
        'status': GroupInvitationStatus.accepted.name,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add user to group members
      final member = GroupMember(
        userId: invitation.invitedUserId,
        role: GroupMemberRole.member,
        joinedAt: DateTime.now(),
        invitedBy: invitation.invitedBy,
        invitationAcceptedAt: DateTime.now(),
      );

      await firestore
          .collection(_groupsCollection)
          .doc(invitation.groupId)
          .collection(_membersSubcollection)
          .doc(invitation.invitedUserId)
          .set(member.toJson());

      logService.log(
        LogLevel.info,
        'group_invitation_accepted',
        'User accepted group invitation',
        context: {
          'invitationId': invitationId,
          'groupId': invitation.groupId,
          'userId': invitation.invitedUserId,
        },
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'group_invitation_accept_failed',
        'Failed to accept group invitation',
        context: {'invitationId': invitationId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Reject a group invitation
  Future<void> rejectInvitation(String invitationId) async {
    try {
      final invitationDoc =
          await firestore
              .collection(_invitationsCollection)
              .doc(invitationId)
              .get();

      if (!invitationDoc.exists) {
        throw Exception('Invitation not found');
      }

      await invitationDoc.reference.update({
        'status': GroupInvitationStatus.rejected.name,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      logService.log(
        LogLevel.info,
        'group_invitation_rejected',
        'User rejected group invitation',
        context: {'invitationId': invitationId},
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'group_invitation_reject_failed',
        'Failed to reject group invitation',
        context: {'invitationId': invitationId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Change a member's role
  Future<void> changeMemberRole({
    required String groupId,
    required String memberId,
    required GroupMemberRole newRole,
    required String changedBy,
  }) async {
    try {
      // Verify permissions (would check if changer has permission)
      final memberDoc =
          await firestore
              .collection(_groupsCollection)
              .doc(groupId)
              .collection(_membersSubcollection)
              .doc(memberId)
              .get();

      if (!memberDoc.exists) {
        throw Exception('Member not found in group');
      }

      final currentMember = GroupMember.fromJson(memberDoc.data()!);

      await memberDoc.reference.update({
        'role': newRole.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'roleChangedBy': changedBy,
        'roleChangedAt': FieldValue.serverTimestamp(),
      });

      logService.log(
        LogLevel.info,
        'group_member_role_changed',
        'Member role changed',
        context: {
          'groupId': groupId,
          'memberId': memberId,
          'oldRole': currentMember.role.name,
          'newRole': newRole.name,
          'changedBy': changedBy,
        },
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'group_member_role_change_failed',
        'Failed to change member role',
        context: {
          'groupId': groupId,
          'memberId': memberId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Remove a member from a group
  Future<void> removeMember({
    required String groupId,
    required String memberId,
    required String removedBy,
    String? reason,
  }) async {
    try {
      // Check if member exists
      final memberDoc =
          await firestore
              .collection(_groupsCollection)
              .doc(groupId)
              .collection(_membersSubcollection)
              .doc(memberId)
              .get();

      if (!memberDoc.exists) {
        throw Exception('Member not found in group');
      }

      // Remove member
      await memberDoc.reference.delete();

      // Cancel any pending invitations from this user
      final pendingInvitations =
          await firestore
              .collection(_invitationsCollection)
              .where('groupId', isEqualTo: groupId)
              .where('invitedUserId', isEqualTo: memberId)
              .where('status', isEqualTo: GroupInvitationStatus.pending.name)
              .get();

      final batch = firestore.batch();
      for (final doc in pendingInvitations.docs) {
        batch.update(doc.reference, {
          'status': GroupInvitationStatus.expired.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      logService.log(
        LogLevel.info,
        'group_member_removed',
        'Member removed from group',
        context: {
          'groupId': groupId,
          'memberId': memberId,
          'removedBy': removedBy,
          'reason': reason,
        },
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'group_member_removal_failed',
        'Failed to remove member from group',
        context: {
          'groupId': groupId,
          'memberId': memberId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Update group settings
  Future<void> updateGroupSettings({
    required String groupId,
    required GroupSettings settings,
    required String updatedBy,
  }) async {
    try {
      await firestore.collection(_groupsCollection).doc(groupId).update({
        'settings': settings.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
        'settingsUpdatedBy': updatedBy,
      });

      logService.log(
        LogLevel.info,
        'group_settings_updated',
        'Group settings updated',
        context: {'groupId': groupId, 'updatedBy': updatedBy},
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'group_settings_update_failed',
        'Failed to update group settings',
        context: {'groupId': groupId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Get group members with roles
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    try {
      final membersSnapshot =
          await firestore
              .collection(_groupsCollection)
              .doc(groupId)
              .collection(_membersSubcollection)
              .get();

      return membersSnapshot.docs
          .map((doc) => GroupMember.fromJson(doc.data()))
          .toList();
    } catch (e) {
      logService.log(
        LogLevel.error,
        'group_members_fetch_failed',
        'Failed to fetch group members',
        context: {'groupId': groupId, 'error': e.toString()},
      );
      return [];
    }
  }

  /// Get pending invitations for a group
  Future<List<GroupInvitation>> getPendingInvitations(String groupId) async {
    try {
      final invitationsSnapshot =
          await firestore
              .collection(_invitationsCollection)
              .where('groupId', isEqualTo: groupId)
              .where('status', isEqualTo: GroupInvitationStatus.pending.name)
              .get();

      return invitationsSnapshot.docs
          .map((doc) => GroupInvitation.fromJson(doc.data()))
          .where((invitation) => !invitation.isExpired)
          .toList();
    } catch (e) {
      logService.log(
        LogLevel.error,
        'group_invitations_fetch_failed',
        'Failed to fetch group invitations',
        context: {'groupId': groupId, 'error': e.toString()},
      );
      return [];
    }
  }

  /// Get user's pending invitations
  Future<List<GroupInvitation>> getUserPendingInvitations(String userId) async {
    try {
      final invitationsSnapshot =
          await firestore
              .collection(_invitationsCollection)
              .where('invitedUserId', isEqualTo: userId)
              .where('status', isEqualTo: GroupInvitationStatus.pending.name)
              .get();

      return invitationsSnapshot.docs
          .map((doc) => GroupInvitation.fromJson(doc.data()))
          .where((invitation) => !invitation.isExpired)
          .toList();
    } catch (e) {
      logService.log(
        LogLevel.error,
        'user_invitations_fetch_failed',
        'Failed to fetch user invitations',
        context: {'userId': userId, 'error': e.toString()},
      );
      return [];
    }
  }

  /// Check if user has permission for an action
  Future<bool> hasPermission({
    required String groupId,
    required String userId,
    required String permission,
  }) async {
    try {
      final memberDoc =
          await firestore
              .collection(_groupsCollection)
              .doc(groupId)
              .collection(_membersSubcollection)
              .doc(userId)
              .get();

      if (!memberDoc.exists) return false;

      final member = GroupMember.fromJson(memberDoc.data()!);

      switch (permission) {
        case 'invite_members':
          return member.role.canInviteMembers;
        case 'remove_members':
          return member.role.canRemoveMembers;
        case 'change_settings':
          return member.role.canChangeSettings;
        case 'manage_roles':
          return member.role.canManageRoles;
        case 'delete_group':
          return member.role.canDeleteGroup;
        case 'moderate_content':
          return member.role.canModerateContent;
        default:
          return false;
      }
    } catch (e) {
      logService.log(
        LogLevel.error,
        'permission_check_failed',
        'Failed to check user permission',
        context: {
          'groupId': groupId,
          'userId': userId,
          'permission': permission,
          'error': e.toString(),
        },
      );
      return false;
    }
  }

  /// Helper method to check if user is a member of group
  Future<bool> _isUserMemberOfGroup(String userId, String groupId) async {
    try {
      final memberDoc =
          await firestore
              .collection(_groupsCollection)
              .doc(groupId)
              .collection(_membersSubcollection)
              .doc(userId)
              .get();

      return memberDoc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Helper method to get pending invitation
  Future<GroupInvitation?> _getPendingInvitation(
    String groupId,
    String userId,
  ) async {
    try {
      final invitationSnapshot =
          await firestore
              .collection(_invitationsCollection)
              .where('groupId', isEqualTo: groupId)
              .where('invitedUserId', isEqualTo: userId)
              .where('status', isEqualTo: GroupInvitationStatus.pending.name)
              .limit(1)
              .get();

      if (invitationSnapshot.docs.isEmpty) return null;

      return GroupInvitation.fromJson(invitationSnapshot.docs.first.data());
    } catch (e) {
      return null;
    }
  }
}
