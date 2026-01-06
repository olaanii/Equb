const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.database();
const firestore = admin.firestore();

// Schedule a push notification for later delivery
exports.schedulePushNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    const {
      userId,
      title,
      body,
      scheduledTime,
      notificationType,
      data: notificationData = {},
    } = data;

    if (!userId || !title || !body || !scheduledTime) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }

    const scheduledDate = new Date(scheduledTime);

    // Validate scheduled time is in the future
    if (scheduledDate <= new Date()) {
      throw new functions.https.HttpsError('invalid-argument', 'Scheduled time must be in the future');
    }

    // Get user's FCM token
    const userRef = db.ref(`users/${userId}`);
    const userSnapshot = await userRef.once('value');
    const userData = userSnapshot.val();

    if (!userData || !userData.fcmToken) {
      console.warn(`No FCM token found for user ${userId}`);
      return { success: false, reason: 'no_fcm_token' };
    }

    const notificationId = `${notificationType}_${userId}_${Date.now()}`;

    // Store scheduled notification
    await firestore.collection('scheduled_notifications').doc(notificationId).set({
      id: notificationId,
      userId,
      fcmToken: userData.fcmToken,
      title,
      body,
      notificationType,
      scheduledTime: scheduledDate,
      data: notificationData,
      status: 'scheduled',
      createdAt: new Date(),
      createdBy: context.auth.uid,
    });

    console.log(`Scheduled notification ${notificationId} for user ${userId} at ${scheduledTime}`);

    return {
      success: true,
      notificationId,
    };

  } catch (error) {
    console.error('Error scheduling push notification:', error);
    throw new functions.https.HttpsError('internal', 'Failed to schedule notification');
  }
});

// Send an immediate push notification
exports.sendImmediateNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    const {
      userId,
      title,
      body,
      notificationType,
      data: notificationData = {},
    } = data;

    if (!userId || !title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }

    // Get user's FCM token
    const userRef = db.ref(`users/${userId}`);
    const userSnapshot = await userRef.once('value');
    const userData = userSnapshot.val();

    if (!userData || !userData.fcmToken) {
      console.warn(`No FCM token found for user ${userId}`);
      return { success: false, reason: 'no_fcm_token' };
    }

    // Send the notification
    const message = {
      token: userData.fcmToken,
      notification: {
        title,
        body,
      },
      data: {
        ...notificationData,
        type: notificationType || 'immediate',
        userId,
        timestamp: Date.now().toString(),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);

    // Log the notification
    await firestore.collection('sent_notifications').add({
      userId,
      title,
      body,
      notificationType,
      fcmMessageId: response,
      sentAt: new Date(),
      sentBy: context.auth.uid,
      data: notificationData,
    });

    console.log(`Sent immediate notification to user ${userId}: ${response}`);

    return {
      success: true,
      messageId: response,
    };

  } catch (error) {
    console.error('Error sending immediate notification:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});

// Cancel scheduled notifications
exports.cancelScheduledNotifications = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    const { userId, notificationType } = data;

    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'userId is required');
    }

    let query = firestore.collection('scheduled_notifications')
      .where('userId', '==', userId)
      .where('status', '==', 'scheduled');

    if (notificationType) {
      query = query.where('notificationType', '==', notificationType);
    }

    const snapshot = await query.get();
    const batch = firestore.batch();

    for (const doc of snapshot.docs) {
      batch.update(doc.ref, {
        status: 'cancelled',
        cancelledAt: new Date(),
        cancelledBy: context.auth.uid,
      });
    }

    await batch.commit();

    console.log(`Cancelled ${snapshot.size} scheduled notifications for user ${userId}`);

    return {
      success: true,
      cancelledCount: snapshot.size,
    };

  } catch (error) {
    console.error('Error cancelling scheduled notifications:', error);
    throw new functions.https.HttpsError('internal', 'Failed to cancel notifications');
  }
});

// Scheduled function to send pending notifications (runs every 5 minutes)
exports.sendScheduledNotifications = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    console.log('Checking for scheduled notifications to send...');

    try {
      const now = new Date();
      const fiveMinutesFromNow = new Date(now.getTime() + 5 * 60 * 1000);

      // Get notifications scheduled within the next 5 minutes
      const notificationsSnapshot = await firestore
        .collection('scheduled_notifications')
        .where('status', '==', 'scheduled')
        .where('scheduledTime', '<=', fiveMinutesFromNow)
        .get();

      console.log(`Found ${notificationsSnapshot.size} notifications to send`);

      let sentCount = 0;
      let failedCount = 0;

      for (const doc of notificationsSnapshot.docs) {
        try {
          const notificationData = doc.data();

          // Send the notification
          const message = {
            token: notificationData.fcmToken,
            notification: {
              title: notificationData.title,
              body: notificationData.body,
            },
            data: {
              ...notificationData.data,
              type: notificationData.notificationType,
              userId: notificationData.userId,
              notificationId: notificationData.id,
              timestamp: Date.now().toString(),
            },
            android: {
              priority: 'high',
              notification: {
                channelId: getChannelId(notificationData.notificationType),
                priority: 'high',
                defaultSound: true,
                defaultVibrateTimings: true,
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          };

          const response = await admin.messaging().send(message);

          // Mark as sent
          await doc.ref.update({
            status: 'sent',
            sentAt: new Date(),
            fcmMessageId: response,
          });

          // Log successful send
          await firestore.collection('sent_notifications').add({
            userId: notificationData.userId,
            title: notificationData.title,
            body: notificationData.body,
            notificationType: notificationData.notificationType,
            fcmMessageId: response,
            sentAt: new Date(),
            sentBy: 'scheduler',
            data: notificationData.data,
          });

          sentCount++;
          console.log(`Sent scheduled notification ${doc.id} to user ${notificationData.userId}`);

        } catch (error) {
          console.error(`Failed to send notification ${doc.id}:`, error);

          // Mark as failed
          await doc.ref.update({
            status: 'failed',
            failedAt: new Date(),
            error: error.message,
          });

          failedCount++;
        }
      }

      console.log(`Notification scheduler completed: ${sentCount} sent, ${failedCount} failed`);

      return null;

    } catch (error) {
      console.error('Error in notification scheduler:', error);
      return null;
    }
  });

// Scheduled function to send contribution reminders (runs daily at 9 AM)
exports.scheduleContributionReminders = functions.pubsub
  .schedule('0 9 * * *')  // 9 AM daily
  .timeZone('Africa/Addis_Ababa')
  .onRun(async (context) => {
    console.log('Scheduling contribution reminders...');

    try {
      const db = admin.database();

      // Get all active groups
      const groupsSnapshot = await db.ref('groups').once('value');
      const groups = groupsSnapshot.val() || {};

      let reminderCount = 0;

      for (const [groupId, groupData] of Object.entries(groups)) {
        if (!groupData.nextPayoutDate) continue;

        const nextPayout = new Date(groupData.nextPayoutDate);
        const now = new Date();

        // Only process groups with payouts in the next 7 days
        const sevenDaysFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
        if (nextPayout > sevenDaysFromNow) continue;

        // Calculate reminder time (24 hours before contribution due)
        const reminderTime = new Date(nextPayout.getTime() - 24 * 60 * 60 * 1000);

        // Only schedule if reminder is in the future
        if (reminderTime <= now) continue;

        const members = groupData.members || [];
        const contributionAmount = groupData.contributionAmount || 0;
        const groupName = groupData.name || 'Savings Group';

        for (const memberId of members) {
          try {
            // Get user data and check notification preferences
            const userSnapshot = await db.ref(`users/${memberId}`).once('value');
            const userData = userSnapshot.val();

            if (!userData || !userData.fcmToken) continue;

            // Check notification preferences (default to enabled if not set)
            const prefsSnapshot = await db.ref(`user_notification_preferences/${memberId}`).once('value');
            const prefs = prefsSnapshot.val() || {};
            const remindersEnabled = prefs.contributionRemindersEnabled !== false;

            if (!remindersEnabled) continue;

            // Schedule the reminder
            const notificationId = `contribution_reminder_${groupId}_${memberId}_${reminderTime.getTime()}`;

            await firestore.collection('scheduled_notifications').doc(notificationId).set({
              id: notificationId,
              userId: memberId,
              fcmToken: userData.fcmToken,
              title: 'Contribution Reminder',
              body: `Your ETB ${contributionAmount} contribution for ${groupName} is due tomorrow`,
              notificationType: 'contribution_reminder',
              scheduledTime: reminderTime,
              data: {
                groupId,
                groupName,
                amount: contributionAmount,
                type: 'contribution_reminder',
              },
              status: 'scheduled',
              createdAt: new Date(),
              createdBy: 'scheduler',
            });

            reminderCount++;

          } catch (error) {
            console.error(`Failed to schedule reminder for member ${memberId}:`, error);
          }
        }
      }

      console.log(`Scheduled ${reminderCount} contribution reminders`);
      return null;

    } catch (error) {
      console.error('Error scheduling contribution reminders:', error);
      return null;
    }
  });

// Scheduled function to send payout notifications (runs daily at 8 AM)
exports.schedulePayoutNotifications = functions.pubsub
  .schedule('0 8 * * *')  // 8 AM daily
  .timeZone('Africa/Addis_Ababa')
  .onRun(async (context) => {
    console.log('Scheduling payout notifications...');

    try {
      let notificationCount = 0;

      // Get payouts scheduled for tomorrow
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      const startOfTomorrow = new Date(tomorrow.getFullYear(), tomorrow.getMonth(), tomorrow.getDate());
      const endOfTomorrow = new Date(tomorrow.getFullYear(), tomorrow.getMonth(), tomorrow.getDate() + 1);

      const payoutsSnapshot = await firestore
        .collection('payout_schedules')
        .where('status', '==', 'scheduled')
        .where('scheduledDate', '>=', startOfTomorrow)
        .where('scheduledDate', '<', endOfTomorrow)
        .get();

      for (const payoutDoc of payoutsSnapshot.docs) {
        const payoutData = payoutDoc.data();
        const recipientId = payoutData.recipientId;
        const amount = payoutData.amount || 0;

        if (!recipientId) continue;

        try {
          // Get user data
          const userSnapshot = await db.ref(`users/${recipientId}`).once('value');
          const userData = userSnapshot.val();

          if (!userData || !userData.fcmToken) continue;

          // Check notification preferences
          const prefsSnapshot = await db.ref(`user_notification_preferences/${recipientId}`).once('value');
          const prefs = prefsSnapshot.val() || {};
          const notificationsEnabled = prefs.payoutRemindersEnabled !== false;

          if (!notificationsEnabled) continue;

          // Schedule the notification for 9 AM tomorrow
          const notificationTime = new Date(startOfTomorrow);
          notificationTime.setHours(9, 0, 0, 0);

          const notificationId = `payout_notification_${payoutDoc.id}_${notificationTime.getTime()}`;

          await firestore.collection('scheduled_notifications').doc(notificationId).set({
            id: notificationId,
            userId: recipientId,
            fcmToken: userData.fcmToken,
            title: 'Payout Tomorrow',
            body: `Your ETB ${amount} payout is scheduled for tomorrow at 10:00 AM`,
            notificationType: 'payout_notification',
            scheduledTime: notificationTime,
            data: {
              payoutId: payoutDoc.id,
              amount,
              scheduledDate: payoutData.scheduledDate?.toDate?.()?.toISOString() || payoutData.scheduledDate,
              type: 'payout_notification',
            },
            status: 'scheduled',
            createdAt: new Date(),
            createdBy: 'scheduler',
          });

          notificationCount++;

        } catch (error) {
          console.error(`Failed to schedule payout notification for ${recipientId}:`, error);
        }
      }

      console.log(`Scheduled ${notificationCount} payout notifications`);
      return null;

    } catch (error) {
      console.error('Error scheduling payout notifications:', error);
      return null;
    }
  });

// Helper function to get appropriate channel ID based on notification type
function getChannelId(notificationType) {
  switch (notificationType) {
    case 'contribution_reminder':
      return 'contribution_channel';
    case 'payout_notification':
      return 'payout_channel';
    case 'system':
      return 'system_channel';
    default:
      return 'high_importance_channel';
  }
}

