const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize SendGrid (you'll need to set SENDGRID_API_KEY in functions config)
// const sgMail = require('@sendgrid/mail');
// sgMail.setApiKey(functions.config().sendgrid?.apikey || '');

const APP_NAME = 'Equb';
const FROM_EMAIL = 'noreply@equb.app'; // Replace with your domain

class EmailService {
  constructor() {
    // Initialize your email provider here
    // For now, we'll log emails instead of sending them
    this.sendEmail = this._mockSendEmail.bind(this);
  }

  // Mock email sending - replace with real implementation
  async _mockSendEmail(to, subject, html, text) {
    console.log('📧 EMAIL MOCK - Would send:', {
      to,
      subject,
      html: html.substring(0, 100) + '...',
      text: text.substring(0, 100) + '...',
      timestamp: new Date().toISOString()
    });

    // Simulate API delay
    await new Promise(resolve => setTimeout(resolve, 100));

    return { success: true, messageId: `mock_${Date.now()}` };
  }

  // Send welcome email
  async sendWelcomeEmail(userEmail, userName) {
    const subject = `Welcome to ${APP_NAME}, ${userName}!`;
    const html = this._getWelcomeEmailTemplate(userName);
    const text = `Welcome to ${APP_NAME}, ${userName}! Your account has been created successfully.`;

    return this.sendEmail(userEmail, subject, html, text);
  }

  // Send contribution reminder
  async sendContributionReminder(userEmail, userName, groupName, amount, dueDate) {
    const subject = `Contribution Reminder: ${groupName}`;
    const html = this._getContributionReminderTemplate(userName, groupName, amount, dueDate);
    const text = `Hi ${userName}, your contribution of ETB ${amount} for ${groupName} is due on ${dueDate}.`;

    return this.sendEmail(userEmail, subject, html, text);
  }

  // Send payout notification
  async sendPayoutNotification(userEmail, userName, groupName, amount, payoutDate) {
    const subject = `🎉 Payout Received: ${groupName}`;
    const html = this._getPayoutNotificationTemplate(userName, groupName, amount, payoutDate);
    const text = `Congratulations ${userName}! You received ETB ${amount} from ${groupName} on ${payoutDate}.`;

    return this.sendEmail(userEmail, subject, html, text);
  }

  // Send payout scheduled notification
  async sendPayoutScheduled(userEmail, userName, groupName, amount, scheduledDate) {
    const subject = `Payout Scheduled: ${groupName}`;
    const html = this._getPayoutScheduledTemplate(userName, groupName, amount, scheduledDate);
    const text = `Hi ${userName}, your payout of ETB ${amount} from ${groupName} is scheduled for ${scheduledDate}.`;

    return this.sendEmail(userEmail, subject, html, text);
  }

  // Send low balance warning
  async sendLowBalanceWarning(userEmail, userName, currentBalance, recommendedAmount) {
    const subject = `Low Balance Warning`;
    const html = this._getLowBalanceWarningTemplate(userName, currentBalance, recommendedAmount);
    const text = `Hi ${userName}, your balance is low (ETB ${currentBalance}). Consider topping up with at least ETB ${recommendedAmount}.`;

    return this.sendEmail(userEmail, subject, html, text);
  }

  // Send group invitation
  async sendGroupInvitation(userEmail, userName, groupName, inviterName) {
    const subject = `You're invited to join ${groupName}`;
    const html = this._getGroupInvitationTemplate(userName, groupName, inviterName);
    const text = `Hi ${userName}, ${inviterName} has invited you to join ${groupName}.`;

    return this.sendEmail(userEmail, subject, html, text);
  }

  // Send transaction confirmation
  async sendTransactionConfirmation(userEmail, userName, transactionType, amount, status) {
    const subject = `${transactionType} ${status === 'success' ? 'Confirmed' : 'Failed'}`;
    const html = this._getTransactionConfirmationTemplate(userName, transactionType, amount, status);
    const text = `Hi ${userName}, your ${transactionType.toLowerCase()} of ETB ${amount} has ${status === 'success' ? 'been confirmed' : 'failed'}.`;

    return this.sendEmail(userEmail, subject, html, text);
  }

  // Email Templates
  _getWelcomeEmailTemplate(userName) {
    return `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <title>Welcome to ${APP_NAME}</title>
        </head>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center;">
            <h1 style="color: white; margin: 0; font-size: 32px;">Welcome to ${APP_NAME}!</h1>
          </div>

          <div style="padding: 40px 20px;">
            <h2 style="color: #333;">Hi ${userName},</h2>

            <p style="color: #666; line-height: 1.6;">
              Welcome to ${APP_NAME}, your trusted partner for collaborative savings!
              Your account has been created successfully.
            </p>

            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <h3 style="margin-top: 0; color: #333;">What you can do:</h3>
              <ul style="color: #666;">
                <li>Create or join savings groups</li>
                <li>Make secure contributions</li>
                <li>Receive payouts automatically</li>
                <li>Track your savings progress</li>
              </ul>
            </div>

            <p style="color: #666;">
              If you have any questions, feel free to reach out to our support team.
            </p>

            <a href="#" style="background: #667eea; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin: 20px 0;">
              Get Started
            </a>
          </div>

          <div style="background: #f8f9fa; padding: 20px; text-align: center; color: #666;">
            <p>&copy; 2024 ${APP_NAME}. All rights reserved.</p>
          </div>
        </body>
      </html>
    `;
  }

  _getContributionReminderTemplate(userName, groupName, amount, dueDate) {
    return `
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
            <h3>Hi ${userName},</h3>

            <p>This is a friendly reminder that your contribution for <strong>${groupName}</strong> is due.</p>

            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <p style="margin: 0;"><strong>Amount Due:</strong> ETB ${amount}</p>
              <p style="margin: 10px 0 0 0;"><strong>Due Date:</strong> ${dueDate}</p>
            </div>

            <p>Please make your contribution on time to keep the group running smoothly.</p>

            <a href="#" style="background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
              Make Contribution
            </a>
          </div>
        </body>
      </html>
    `;
  }

  _getPayoutNotificationTemplate(userName, groupName, amount, payoutDate) {
    return `
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
            <h2>Congratulations ${userName}!</h2>

            <div style="background: #d4edda; border: 1px solid #c3e6cb; padding: 30px; border-radius: 8px; margin: 20px 0;">
              <h3 style="color: #155724; margin: 0;">ETB ${amount}</h3>
              <p style="color: #155724; margin: 10px 0 0 0;">Received from ${groupName}</p>
              <p style="color: #155724; margin: 5px 0 0 0;">${payoutDate}</p>
            </div>

            <p>The funds have been added to your wallet and are available for use.</p>

            <a href="#" style="background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin: 20px 0;">
              View Wallet
            </a>
          </div>
        </body>
      </html>
    `;
  }

  _getPayoutScheduledTemplate(userName, groupName, amount, scheduledDate) {
    return `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <title>Payout Scheduled</title>
        </head>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: #d1ecf1; border-left: 4px solid #17a2b8; padding: 20px;">
            <h2 style="color: #0c5460; margin: 0;">Payout Scheduled</h2>
          </div>

          <div style="padding: 40px 20px;">
            <h3>Hi ${userName},</h3>

            <p>Great news! Your payout from <strong>${groupName}</strong> has been scheduled.</p>

            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <p style="margin: 0;"><strong>Amount:</strong> ETB ${amount}</p>
              <p style="margin: 10px 0 0 0;"><strong>Scheduled Date:</strong> ${scheduledDate}</p>
            </div>

            <p>You will receive a notification when the payout is processed.</p>
          </div>
        </body>
      </html>
    `;
  }

  _getLowBalanceWarningTemplate(userName, currentBalance, recommendedAmount) {
    return `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <title>Low Balance Warning</title>
        </head>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 20px;">
            <h2 style="color: #856404; margin: 0;">Low Balance Warning</h2>
          </div>

          <div style="padding: 40px 20px;">
            <h3>Hi ${userName},</h3>

            <p>Your wallet balance is running low.</p>

            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <p style="margin: 0;"><strong>Current Balance:</strong> ETB ${currentBalance}</p>
              <p style="margin: 10px 0 0 0;"><strong>Recommended Top-up:</strong> ETB ${recommendedAmount}</p>
            </div>

            <p>To avoid missing contributions or payouts, please top up your wallet.</p>

            <a href="#" style="background: #ffc107; color: #212529; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
              Top Up Wallet
            </a>
          </div>
        </body>
      </html>
    `;
  }

  _getGroupInvitationTemplate(userName, groupName, inviterName) {
    return `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <title>Group Invitation</title>
        </head>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center;">
            <h1 style="color: white; margin: 0;">You're Invited!</h1>
          </div>

          <div style="padding: 40px 20px; text-align: center;">
            <h2>Hi ${userName},</h2>

            <p><strong>${inviterName}</strong> has invited you to join <strong>${groupName}</strong>.</p>

            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <p>Join this savings group to start saving together and receive regular payouts.</p>
            </div>

            <div style="margin: 30px 0;">
              <a href="#" style="background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin: 0 10px;">
                Accept Invitation
              </a>
              <a href="#" style="background: #6c757d; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin: 0 10px;">
                View Details
              </a>
            </div>
          </div>
        </body>
      </html>
    `;
  }

  _getTransactionConfirmationTemplate(userName, transactionType, amount, status) {
    const statusColor = status === 'success' ? '#28a745' : '#dc3545';
    const statusText = status === 'success' ? 'Confirmed' : 'Failed';

    return `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <title>Transaction ${statusText}</title>
        </head>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: ${status === 'success' ? '#d4edda' : '#f8d7da'}; border-left: 4px solid ${statusColor}; padding: 20px;">
            <h2 style="color: ${status === 'success' ? '#155724' : '#721c24'}; margin: 0;">Transaction ${statusText}</h2>
          </div>

          <div style="padding: 40px 20px;">
            <h3>Hi ${userName},</h3>

            <p>Your ${transactionType.toLowerCase()} has been ${status === 'success' ? 'confirmed' : 'declined'}.</p>

            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <p style="margin: 0;"><strong>Amount:</strong> ETB ${amount}</p>
              <p style="margin: 10px 0 0 0;"><strong>Type:</strong> ${transactionType}</p>
              <p style="margin: 10px 0 0 0;"><strong>Status:</strong> <span style="color: ${statusColor};">${statusText}</span></p>
            </div>

            ${status === 'success'
              ? '<p>The transaction has been processed successfully.</p>'
              : '<p>Please check your account details and try again, or contact support if you need assistance.</p>'
            }

            <a href="#" style="${status === 'success' ? 'background: #28a745;' : 'background: #dc3545;'} color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
              View Transaction
            </a>
          </div>
        </body>
      </html>
    `;
  }
}

module.exports = { EmailService };

