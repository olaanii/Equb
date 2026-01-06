import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:equb/models/email_preferences.dart';
import 'package:equb/services/system_log_service.dart';

class EmailService {
  EmailService({
    required this.functions,
    required this.logService,
  });

  final FirebaseFunctions functions;
  final SystemLogService logService;

  /// Get user's email preferences
  Future<EmailPreferences> getUserPreferences(String userId) async {
    try {
      final callable = functions.httpsCallable('getUserEmailPreferences');
      final result = await callable.call({'userId': userId});

      if (result.data['success'] == true) {
        return EmailPreferences.fromJson(result.data['preferences']);
      } else {
        // Return default preferences
        return const EmailPreferences();
      }
    } catch (e) {
      logService.log(
        LogLevel.warning,
        'email_service.getUserPreferences',
        'Failed to get user preferences, using defaults',
        context: {'userId': userId, 'error': e.toString()},
      );
      return const EmailPreferences();
    }
  }

  /// Update user's email preferences
  Future<bool> updateUserPreferences(String userId, EmailPreferences preferences) async {
    try {
      final callable = functions.httpsCallable('updateUserEmailPreferences');
      final result = await callable.call({
        'userId': userId,
        'preferences': preferences.toJson(),
      });

      final success = result.data['success'] == true;
      if (success) {
        logService.log(
          LogLevel.info,
          'email_service.updateUserPreferences',
          'Email preferences updated successfully',
          context: {'userId': userId},
        );
      }

      return success;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'email_service.updateUserPreferences',
        'Failed to update email preferences',
        context: {'userId': userId, 'error': e.toString()},
      );
      return false;
    }
  }

  /// Send a test email to verify email settings
  Future<bool> sendTestEmail(String userEmail, String userName) async {
    try {
      final callable = functions.httpsCallable('adminSendEmail');
      final result = await callable.call({
        'to': userEmail,
        'subject': 'Equb Email Test',
        'html': '''
          <h2>Hello ${userName}!</h2>
          <p>This is a test email to verify your email settings are working correctly.</p>
          <p>If you received this email, your email notifications are properly configured.</p>
          <br>
          <p>Best regards,<br>The Equb Team</p>
        ''',
        'text': 'Hello $userName! This is a test email to verify your email settings.',
      });

      final success = result.data['ok'] == true;
      if (success) {
        logService.log(
          LogLevel.info,
          'email_service.sendTestEmail',
          'Test email sent successfully',
          context: {'email': userEmail},
        );
      }

      return success;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'email_service.sendTestEmail',
        'Failed to send test email',
        context: {'email': userEmail, 'error': e.toString()},
      );
      return false;
    }
  }

  /// Trigger welcome email (usually called automatically on user creation)
  Future<bool> sendWelcomeEmail(String userId, String userEmail, String userName) async {
    try {
      final callable = functions.httpsCallable('sendWelcomeEmail');
      final result = await callable.call({
        'userId': userId,
        'email': userEmail,
        'name': userName,
      });

      final success = result.data['success'] == true;
      if (success) {
        logService.log(
          LogLevel.info,
          'email_service.sendWelcomeEmail',
          'Welcome email queued',
          context: {'userId': userId, 'email': userEmail},
        );
      }

      return success;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'email_service.sendWelcomeEmail',
        'Failed to queue welcome email',
        context: {'userId': userId, 'error': e.toString()},
      );
      return false;
    }
  }

  /// Send contribution reminder (admin function)
  Future<bool> sendContributionReminder({
    required String userEmail,
    required String userName,
    required String groupName,
    required double amount,
    required DateTime dueDate,
  }) async {
    try {
      final callable = functions.httpsCallable('adminSendEmail');
      final result = await callable.call({
        'to': userEmail,
        'subject': 'Contribution Reminder: $groupName',
        'html': _getContributionReminderHtml(userName, groupName, amount, dueDate),
        'text': 'Hi $userName, your contribution of ETB $amount for $groupName is due on ${dueDate.toString()}.',
      });

      final success = result.data['ok'] == true;
      if (success) {
        logService.log(
          LogLevel.info,
          'email_service.sendContributionReminder',
          'Contribution reminder sent',
          context: {'email': userEmail, 'group': groupName},
        );
      }

      return success;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'email_service.sendContributionReminder',
        'Failed to send contribution reminder',
        context: {'email': userEmail, 'error': e.toString()},
      );
      return false;
    }
  }

  /// Send payout notification (admin function)
  Future<bool> sendPayoutNotification({
    required String userEmail,
    required String userName,
    required String groupName,
    required double amount,
    required DateTime payoutDate,
  }) async {
    try {
      final callable = functions.httpsCallable('adminSendEmail');
      final result = await callable.call({
        'to': userEmail,
        'subject': 'Payout Received: $groupName',
        'html': _getPayoutNotificationHtml(userName, groupName, amount, payoutDate),
        'text': 'Congratulations $userName! You received ETB $amount from $groupName on ${payoutDate.toString()}.',
      });

      final success = result.data['ok'] == true;
      if (success) {
        logService.log(
          LogLevel.info,
          'email_service.sendPayoutNotification',
          'Payout notification sent',
          context: {'email': userEmail, 'group': groupName, 'amount': amount},
        );
      }

      return success;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'email_service.sendPayoutNotification',
        'Failed to send payout notification',
        context: {'email': userEmail, 'error': e.toString()},
      );
      return false;
    }
  }

  /// Get email notification history for a user
  Future<List<EmailNotification>> getEmailHistory(String userId, {int limit = 50}) async {
    try {
      final callable = functions.httpsCallable('getUserEmailHistory');
      final result = await callable.call({
        'userId': userId,
        'limit': limit,
      });

      if (result.data['success'] == true) {
        final emails = result.data['emails'] as List<dynamic>;
        return emails.map((e) => EmailNotification.fromJson(e as Map<String, dynamic>)).toList();
      }

      return [];
    } catch (e) {
      logService.log(
        LogLevel.error,
        'email_service.getEmailHistory',
        'Failed to get email history',
        context: {'userId': userId, 'error': e.toString()},
      );
      return [];
    }
  }

  /// Unsubscribe from a specific email type
  Future<bool> unsubscribeFromEmailType(String userId, EmailType emailType) async {
    try {
      final preferences = await getUserPreferences(userId);
      final updatedPreferences = _updatePreferenceForType(preferences, emailType, EmailFrequency.never);

      return updateUserPreferences(userId, updatedPreferences);
    } catch (e) {
      logService.log(
        LogLevel.error,
        'email_service.unsubscribeFromEmailType',
        'Failed to unsubscribe from email type',
        context: {
          'userId': userId,
          'emailType': emailType.toString(),
          'error': e.toString(),
        },
      );
      return false;
    }
  }

  EmailPreferences _updatePreferenceForType(
    EmailPreferences preferences,
    EmailType emailType,
    EmailFrequency frequency,
  ) {
    switch (emailType) {
      case EmailType.contributionReminder:
        return preferences.copyWith(contributionReminders: frequency);
      case EmailType.payoutNotification:
        return preferences.copyWith(payoutNotifications: frequency);
      case EmailType.groupInvitation:
        return preferences.copyWith(groupInvitations: frequency);
      case EmailType.transactionConfirmation:
        return preferences.copyWith(transactionConfirmations: frequency);
      case EmailType.weeklySummary:
        return preferences.copyWith(weeklySummaries: frequency);
      case EmailType.lowBalanceWarning:
        return preferences.copyWith(lowBalanceWarnings: frequency);
      case EmailType.systemUpdate:
        return preferences.copyWith(systemUpdates: frequency);
      case EmailType.marketing:
        return preferences.copyWith(marketingEmails: false);
    }
  }

  String _getContributionReminderHtml(String userName, String groupName, double amount, DateTime dueDate) {
    return '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <title>Contribution Reminder</title>
        </head>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 20px;">
            <h2 style="color: #856404; margin: 0;">Contribution Reminder</h2>
          </div>

          <div style="padding: 40px 20px;">
            <h3>Hi $userName,</h3>

            <p>This is a friendly reminder that your contribution for <strong>$groupName</strong> is due.</p>

            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <p style="margin: 0;"><strong>Amount Due:</strong> ETB $amount</p>
              <p style="margin: 10px 0 0 0;"><strong>Due Date:</strong> ${dueDate.toString()}</p>
            </div>

            <p>Please make your contribution on time to keep the group running smoothly.</p>

            <a href="#" style="background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin: 20px 0;">
              Make Contribution
            </a>
          </div>
        </body>
      </html>
    ''';
  }

  String _getPayoutNotificationHtml(String userName, String groupName, double amount, DateTime payoutDate) {
    return '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <title>Payout Received!</title>
        </head>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #28a745 0%, #20c997 100%); padding: 40px 20px; text-align: center;">
            <h1 style="color: white; margin: 0; font-size: 32px;">🎉 Payout Received!</h1>
          </div>

          <div style="padding: 40px 20px; text-align: center;">
            <h2>Congratulations $userName!</h2>

            <div style="background: #d4edda; border: 1px solid #c3e6cb; padding: 30px; border-radius: 8px; margin: 20px 0;">
              <h3 style="color: #155724; margin: 0;">ETB $amount</h3>
              <p style="color: #155724; margin: 10px 0 0 0;">Received from $groupName</p>
              <p style="color: #155724; margin: 5px 0 0 0;">${payoutDate.toString()}</p>
            </div>

            <p>The funds have been added to your wallet and are available for use.</p>

            <a href="#" style="background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin: 20px 0;">
              View Wallet
            </a>
          </div>
        </body>
      </html>
    ''';
  }
}

