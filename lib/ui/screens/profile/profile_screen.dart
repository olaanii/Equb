import 'package:equb/models/user_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equb/providers/app_providers.dart';
import 'package:equb/ui/widgets/common/cached_avatar.dart';
import 'package:image_picker/image_picker.dart';

import 'package:equb/services/toast_service.dart';
import 'package:equb/ui/screens/notifications/notifications_screen.dart';
import 'account_security_screen.dart';
import 'email_preferences_screen.dart';
import 'support_compliance_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    if (user != null) {
      return _buildProfileContent(context, theme, user, ref);
    }

    return userAsync.when(
      data: (u) {
        if (u == null) return _buildLoginPrompt();
        return _buildProfileContent(context, theme, u, ref);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (err, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to load profile',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString().replaceAll('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref.refresh(currentUserProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildLoginPrompt() {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: const Center(
        child: Text('User profile not found. Please log in again.'),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    ThemeData theme,
    UserModel user,
    WidgetRef ref,
  ) {
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onBackground,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            if (user.email == 'offline@equb.app') _buildOfflineBanner(theme),
            const SizedBox(height: 24),
            _buildMinimalHeader(
              context,
              theme,
              user,
              ref,
            ), // Updated signature to pass context for edit
            const SizedBox(height: 32),
            _buildStatsCard(theme, user),
            const SizedBox(height: 32),
            _buildNavigationMenu(context, theme),
            const SizedBox(height: 48),
            _buildLogoutButton(context),
            const SizedBox(height: 24),
            Text(
              'v2.5.0 (Robust Build)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Text(
            'OFFLINE MODE • READ ONLY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme, UserModel user) {
    // Simple date formatting
    final joined =
        "${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}";

    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.55),
        ),
        boxShadow: [BoxShadow(
          color: scheme.shadow.withOpacity(0.10),
          blurRadius: 16,
          offset: const Offset(0, 8),
        )],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(theme, 'Joined', joined),
          _buildVerticalDivider(theme),
          _buildStatItem(theme, 'Points', user.points.toString()),
          _buildVerticalDivider(theme),
          _buildStatItem(
            theme,
            'Balance',
            '${user.walletBalance.toStringAsFixed(0)} ETB',
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      height: 32,
      width: 1,
      color: scheme.outlineVariant.withOpacity(0.65),
    );
  }

  Widget _buildStatItem(ThemeData theme, String label, String value) {
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalHeader(
    BuildContext context,
    ThemeData theme,
    UserModel user,
    WidgetRef ref,
  ) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: CachedAvatar(
                imageUrl: user.profileImageUrl,
                name: user.name,
                radius: 50,
                fontSize: 32,
                backgroundColor: AppColors.primary,
                textColor: Colors.black,
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: InkWell(
                onTap: () => _handleImageUpdate(context, ref, user),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              user.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color:
                    theme.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
              ),
            ),
            if (user.isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified, color: AppColors.success, size: 20),
            ],
            if (user.email != null && user.email != 'offline@equb.app') ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.edit,
                  size: 18,
                  color: AppColors.primary,
                ),
                onPressed: () => _showEditProfileDialog(context, user),
                tooltip: 'Edit Profile',
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          user.email ?? user.phone ?? 'Premium Member',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext context, UserModel user) {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone);
    bool isSaving = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor:
                    isDark ? const Color(0xFF1E1E1E) : Colors.white,
                title: Text(
                  'Edit Profile',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    if (isSaving) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
                actions:
                    isSaving
                        ? []
                        : [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              return TextButton(
                                onPressed: () async {
                                  final newName = nameController.text.trim();
                                  final newPhone = phoneController.text.trim();

                                  if (newName.isEmpty) {
                                    ToastService.error(
                                      context,
                                      'Name cannot be empty',
                                    );
                                    return;
                                  }

                                  setState(() => isSaving = true);

                                  final updatedUser = user.copyWith(
                                    name: newName,
                                    phone: newPhone.isEmpty ? null : newPhone,
                                  );

                                  try {
                                    await ref
                                        .read(userRepositoryProvider)
                                        .updateUser(updatedUser);

                                    // Force refresh of the user provider to reflect changes
                                    ref.invalidate(currentUserProvider);

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ToastService.success(
                                        context,
                                        'Profile updated successfully',
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      setState(() => isSaving = false);
                                      ToastService.error(
                                        context,
                                        'Update failed: $e',
                                      );
                                    }
                                  }
                                },
                                child: const Text(
                                  'Save',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                              );
                            },
                          ),
                        ],
              );
            },
          ),
    );
  }

  Widget _buildNavigationMenu(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        Consumer(
          builder: (context, ref, _) {
            final mode = ref.watch(themeModeProvider);
            final isDark = mode == ThemeMode.dark;
            return _buildSwitchOption(
              context,
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              value: isDark,
              onChanged: (val) {
                ref
                    .read(themeModeProvider.notifier)
                    .setMode(val ? ThemeMode.dark : ThemeMode.light);
                ToastService.info(
                  context,
                  val ? 'Dark mode enabled' : 'Light mode enabled',
                );
              },
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          context,
          theme,
          icon: Icons.shield_outlined,
          title: 'Account & Security',
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AccountSecurityScreen(),
                ),
              ),
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          context,
          theme,
          icon: Icons.notifications_none_outlined,
          title: 'Notifications',
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          context,
          theme,
          icon: Icons.email_outlined,
          title: 'Email Preferences',
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EmailPreferencesScreen()),
              ),
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          context,
          theme,
          icon: Icons.help_outline,
          title: 'Support & Help',
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SupportComplianceScreen(),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildMenuOption(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black12,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: isDark ? Colors.white : Colors.black, size: 22),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.error,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      icon: const Icon(Icons.logout, size: 20),
      label: const Text(
        'Sign Out',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      onPressed: () {
        ToastService.warning(context, 'Signed out successfully');
        // Actual logout logic would go here
      },
    );
  }

  Widget _buildSwitchOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black12,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? Colors.white : Colors.black, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Future<void> _handleImageUpdate(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) async {
    dynamic storage;
    dynamic userRepo;
    try {
      storage = ref.read(imageStorageServiceProvider);
      userRepo = ref.read(userRepositoryProvider);
    } on UnimplementedError {
      ToastService.info(
        context,
        'Profile updates are disabled in auth-only mode.',
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.photo_library,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  title: Text(
                    'Photo Library',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: Icon(
                    Icons.camera_alt,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  title: Text(
                    'Camera',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
    );

    if (source == null) return;

    try {
      final file = await storage.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file == null) return;

      if (!context.mounted) return;
      ToastService.info(context, 'Uploading image...');

      final url = await storage.uploadProfileImage(user.id, file);
      await userRepo.updateUser(user.copyWith(profileImageUrl: url));

      // Force refresh
      ref.invalidate(currentUserProvider);

      if (!context.mounted) return;
      ToastService.success(context, 'Profile picture updated successfully');
    } catch (e) {
      if (!context.mounted) return;
      ToastService.error(context, 'Failed to update image: $e');
    }
  }
}
