import 'package:equb/providers/admin_providers.dart';

/// True only if the current signed-in user has `superadmins/{uid} == true` in RTDB.
///
/// This repo’s source-of-truth for super admin access is the RTDB flag, not a
/// Firebase custom claim.
final superAdminAllowedProvider = isSuperAdminProvider;
