import 'package:flutter/material.dart';

/// Stub implementation used on platforms where Chapa's official SDK can't run
/// (notably Flutter Web due to dart:io usage in the SDK).
Future<void> startChapaCheckoutWithSdk({
  required BuildContext context,
  required String publicKey,
  required String currency,
  required String amount,
  required String email,
  required String phone,
  required String firstName,
  required String lastName,
  required String txRef,
  required String title,
  required String description,
}) {
  throw UnsupportedError(
    'Chapa SDK checkout is not supported on this platform.',
  );
}
