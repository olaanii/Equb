import 'package:equb/models/notification_preferences.dart';
import 'package:equb/utils/firestore_helpers.dart';

enum UserRole { superAdmin, equbAdmin, user }

class UserModel {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final UserRole role;
  final DateTime createdAt;
  final bool biometricsEnabled;
  final bool pushEnabled;
  final bool emailDigestEnabled;
  final double walletBalance;
  final NotificationPreferences notificationPreferences;
  final bool isVerified;
  final String? profileImageUrl;
  final int points;

  UserModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.role = UserRole.user,
    DateTime? createdAt,
    this.biometricsEnabled = false,
    this.pushEnabled = true,
    this.emailDigestEnabled = false,
    this.walletBalance = 0.0,
    NotificationPreferences? notificationPreferences,
    this.isVerified = false,
    this.profileImageUrl,
    this.points = 0,
  }) : createdAt = createdAt ?? DateTime.now(),
       notificationPreferences =
           notificationPreferences ?? const NotificationPreferences();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => UserRole.user,
      ),
      createdAt: FirestoreHelpers.parseDateTime(json['createdAt']),
      biometricsEnabled: json['biometricsEnabled'] as bool? ?? false,
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      emailDigestEnabled: json['emailDigestEnabled'] as bool? ?? false,
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.0,
      notificationPreferences: NotificationPreferences.fromJson(
        json['notificationPreferences'] as Map<String, dynamic>?,
      ),
      isVerified: json['isVerified'] as bool? ?? false,
      profileImageUrl: json['profileImageUrl'] as String?,
      points: json['points'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'biometricsEnabled': biometricsEnabled,
      'pushEnabled': pushEnabled,
      'emailDigestEnabled': emailDigestEnabled,
      'walletBalance': walletBalance,
      'notificationPreferences': notificationPreferences.toJson(),
      'isVerified': isVerified,
      'profileImageUrl': profileImageUrl,
      'points': points,
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? email,
    UserRole? role,
    DateTime? createdAt,
    bool? biometricsEnabled,
    bool? pushEnabled,
    bool? emailDigestEnabled,
    double? walletBalance,
    NotificationPreferences? notificationPreferences,
    bool? isVerified,
    String? profileImageUrl,
    int? points,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailDigestEnabled: emailDigestEnabled ?? this.emailDigestEnabled,
      walletBalance: walletBalance ?? this.walletBalance,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      isVerified: isVerified ?? this.isVerified,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      points: points ?? this.points,
    );
  }
}
