import 'dart:io';

import 'package:chapasdk/chapasdk.dart';
import 'package:flutter/material.dart';

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
}) async {
  // The official SDK is primarily designed for Android/iOS. Avoid invoking it
  // on desktop platforms even though they are "io".
  if (!(Platform.isAndroid || Platform.isIOS)) {
    throw UnsupportedError('Chapa SDK checkout is only supported on Android/iOS.');
  }

  Chapa.paymentParameters(
    context: context,
    publicKey: publicKey,
    currency: currency,
    amount: amount,
    email: email,
    phone: phone,
    firstName: firstName,
    lastName: lastName,
    txRef: txRef,
    title: title,
    desc: description,
    nativeCheckout: true,
    // If you use a custom router (GoRoute/AutoRoute), keep this empty and rely
    // on the callback.
    namedRouteFallBack: '',
    showPaymentMethodsOnGridView: true,
    onPaymentFinished: (message, reference, paidAmount) {
      // Return to the previous screen (the SDK pushes its own route).
      Navigator.of(context).maybePop();
    },
  );
}
